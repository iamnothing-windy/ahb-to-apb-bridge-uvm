`timescale 1ns/1ps
`default_nettype none

package bridge_pkg;
  localparam int ADDR_WIDTH     = 32;
  localparam int DATA_WIDTH     = 32;
  localparam int NUM_APB_SLAVES = 3;
  localparam bit DEFAULT_USE_PCLKEN    = 1'b0;

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  typedef enum logic [2:0] {
    ST_IDLE       = 3'b000,
    ST_WAIT_WDATA = 3'b001,
    ST_APB_SETUP  = 3'b010,
    ST_APB_ACCESS = 3'b011,
    ST_RESP_OK    = 3'b100,
    ST_ERROR_1    = 3'b101,
    ST_ERROR_2    = 3'b110
  } bridge_state_t;

  localparam logic [1:0] HRESP_OKAY  = 2'b00;
  localparam logic [1:0] HRESP_ERROR = 2'b01;

  typedef struct packed {
    logic [ADDR_WIDTH-3:0]     aligned_addr_word;
    logic [DATA_WIDTH-1:0]     wdata;
    logic                      write;
    logic [NUM_APB_SLAVES-1:0] psel;
    logic [STRB_WIDTH-1:0]     strb;
    logic [2:0]                prot;
  } bridge_req_t;

  function automatic logic [STRB_WIDTH-1:0] make_pstrb(
    input logic       write,
    input logic [2:0] size,
    input logic [1:0] addr_low
  );
    logic [STRB_WIDTH-1:0] strb;
    begin
      strb = '0;

      // Release 1 supports a 32-bit little-endian data bus: address +0 maps
      // to byte lane 0, address +1 to lane 1, address +2 to lane 2, and
      // address +3 to lane 3.
      if (write) begin
        case (size)
          3'b000: begin
            case (addr_low)
              2'b00: strb = 4'b0001;
              2'b01: strb = 4'b0010;
              2'b10: strb = 4'b0100;
              default: strb = 4'b1000;
            endcase
          end

          3'b001: begin
            strb = addr_low[1] ? 4'b1100 : 4'b0011;
          end

          3'b010: begin
            strb = 4'b1111;
          end

          default: begin
            strb = '0;
          end
        endcase
      end

      make_pstrb = strb;
    end
  endfunction

  function automatic logic [2:0] map_pprot(input logic [3:0] hprot);
    begin
      map_pprot = {~hprot[0], 1'b0, hprot[1]};
    end
  endfunction
endpackage

module ahb_request_validator(
  input  wire logic                                 Hsel,
  input  wire logic                                 Hreadyin,
  input  wire logic                                 Hwrite,
  input  wire logic [2:0]                           Hsize,
  input  wire logic [3:0]                           Hprot,
  input  wire logic [bridge_pkg::ADDR_WIDTH-1:0]    Haddr,
  input  wire logic [1:0]                           Htrans,
  output logic                                      active_transfer,
  output logic                                      mapped,
  output logic                                      size_supported,
  output logic                                      aligned,
  output logic                                      request_ok,
  output logic [bridge_pkg::NUM_APB_SLAVES-1:0]     decoded_psel,
  output logic [bridge_pkg::STRB_WIDTH-1:0]         decoded_pstrb,
  output logic [2:0]                                decoded_pprot
);
  logic       addr_high_region;
  logic [1:0] apb_region;

  assign active_transfer = Hsel && Hreadyin && Htrans[1];
  assign addr_high_region = (Haddr[bridge_pkg::ADDR_WIDTH-1:bridge_pkg::ADDR_WIDTH-4] == 4'h8);
  assign apb_region = Haddr[27:26];
  assign mapped = addr_high_region && (apb_region != 2'b11);
  assign size_supported = (Hsize == 3'b000) ||
                          (Hsize == 3'b001) ||
                          (Hsize == 3'b010);
  assign aligned = (Hsize == 3'b000) ||
                   (Hsize == 3'b001 && Haddr[0] == 1'b0) ||
                   (Hsize == 3'b010 && Haddr[1:0] == 2'b00);
  assign request_ok = mapped && size_supported && aligned;
  assign decoded_pstrb = bridge_pkg::make_pstrb(Hwrite, Hsize, Haddr[1:0]);
  assign decoded_pprot = bridge_pkg::map_pprot(Hprot);

  always_comb begin
    decoded_psel = '0;
    if (mapped) begin
      case (apb_region)
        2'b00: decoded_psel = 3'b001;
        2'b01: decoded_psel = 3'b010;
        2'b10: decoded_psel = 3'b100;
        default: decoded_psel = 3'b000;
      endcase
    end
  end
endmodule

module bridge_7state_core #(
  parameter bit USE_PCLKEN = bridge_pkg::DEFAULT_USE_PCLKEN
)(
  input  wire logic                          Hclk,
  input  wire logic                          Hresetn,
  input  wire logic                          Pclken,
  input  wire logic                          Hwrite,
  input  wire logic [bridge_pkg::DATA_WIDTH-1:0] Hwdata,
  input  wire logic [bridge_pkg::ADDR_WIDTH-1:0] Haddr,
  input  wire logic [bridge_pkg::DATA_WIDTH-1:0] Prdata,
  input  wire logic                          Pready,
  input  wire logic                          Pslverr,
  input  wire logic                          ahb_active_transfer,
  input  wire logic                          request_ok,
  input  wire logic [bridge_pkg::NUM_APB_SLAVES-1:0] decoded_psel,
  input  wire logic [bridge_pkg::STRB_WIDTH-1:0] decoded_pstrb,
  input  wire logic [2:0]                    decoded_pprot,
  output logic                               Hreadyout,
  output logic [1:0]                         Hresp,
  output logic [bridge_pkg::DATA_WIDTH-1:0]  Hrdata,
  output logic                               Penable,
  output logic                               Pwrite,
  output logic [bridge_pkg::NUM_APB_SLAVES-1:0] Pselx,
  output logic [bridge_pkg::ADDR_WIDTH-1:0]  Paddr,
  output logic [bridge_pkg::DATA_WIDTH-1:0]  Pwdata,
  output logic [bridge_pkg::STRB_WIDTH-1:0]  Pstrb,
  output logic [2:0]                         Pprot
);
  bridge_pkg::bridge_state_t state;
  bridge_pkg::bridge_state_t next_state;
  bridge_pkg::bridge_req_t   req;

  logic                              req_valid;
  logic                              next_req_valid;
  logic [bridge_pkg::DATA_WIDTH-1:0] resp_rdata;

  logic apb_ce;
  logic ahb_accept_window;
  logic req_header_seen;
  logic req_header_push;
  logic req_header_bad;
  logic load_header;
  logic capture_wdata;
  logic capture_rdata;
  logic apb_setup;
  logic apb_access;
  logic apb_active;
  logic ahb_error_phase;

  // USE_PCLKEN=0: APB clock is Hclk and every Hclk edge advances APB.
  // USE_PCLKEN=1: Pclken must be the common synchronous enable used by this bridge
  // and the APB clock/sampling wrapper for every connected APB completer. The core
  // never gates/clocks APB itself; SoC integration owns clock gating or PCLK derivation.
  assign apb_ce = !USE_PCLKEN || Pclken;
  assign ahb_accept_window = (state == bridge_pkg::ST_IDLE) ||
                             (state == bridge_pkg::ST_RESP_OK) ||
                             (state == bridge_pkg::ST_ERROR_2);
  assign req_header_seen = ahb_accept_window && ahb_active_transfer;
  assign req_header_push = req_header_seen && request_ok;
  assign req_header_bad = req_header_seen && !request_ok;
  assign load_header = req_header_push;

  assign apb_setup = (state == bridge_pkg::ST_APB_SETUP);
  assign apb_access = (state == bridge_pkg::ST_APB_ACCESS);
  assign apb_active = req_valid && (apb_setup || apb_access);

  assign Pselx = apb_active ? req.psel : '0;
  assign Penable = req_valid && apb_access;
  assign Pwrite = req.write;
  // PADDR is word-aligned. APB completers must decode by word address and use
  // PSTRB for byte/halfword writes in this release profile.
  assign Paddr = {req.aligned_addr_word, 2'b00};
  assign Pwdata = req.wdata;
  assign Pstrb = req.strb;
  assign Pprot = req.prot;

  assign ahb_error_phase = (state == bridge_pkg::ST_ERROR_1) ||
                           (state == bridge_pkg::ST_ERROR_2);
  assign Hreadyout = (state == bridge_pkg::ST_IDLE) ||
                     (state == bridge_pkg::ST_RESP_OK) ||
                     (state == bridge_pkg::ST_ERROR_2);
  assign Hresp = ahb_error_phase ? bridge_pkg::HRESP_ERROR : bridge_pkg::HRESP_OKAY;
  assign Hrdata = ahb_error_phase ? '0 : resp_rdata;

  always_comb begin
    next_state = state;
    next_req_valid = req_valid;
    capture_wdata = 1'b0;
    capture_rdata = 1'b0;

    unique case (state)
      bridge_pkg::ST_IDLE,
      bridge_pkg::ST_RESP_OK: begin
        if (req_header_bad) begin
          next_req_valid = 1'b0;
          next_state = bridge_pkg::ST_ERROR_1;
        end else if (req_header_push && Hwrite) begin
          next_req_valid = 1'b0;
          next_state = bridge_pkg::ST_WAIT_WDATA;
        end else if (req_header_push && !Hwrite) begin
          next_req_valid = 1'b1;
          next_state = bridge_pkg::ST_APB_SETUP;
        end else begin
          next_req_valid = 1'b0;
          next_state = bridge_pkg::ST_IDLE;
        end
      end

      bridge_pkg::ST_ERROR_2: begin
        next_req_valid = 1'b0;

        if (req_header_bad) begin
          next_state = bridge_pkg::ST_ERROR_1;
        end else if (req_header_push && Hwrite) begin
          next_state = bridge_pkg::ST_WAIT_WDATA;
        end else if (req_header_push) begin
          next_req_valid = 1'b1;
          next_state = bridge_pkg::ST_APB_SETUP;
        end else begin
          next_state = bridge_pkg::ST_IDLE;
        end
      end

      bridge_pkg::ST_WAIT_WDATA: begin
        capture_wdata = 1'b1;
        next_req_valid = 1'b1;
        next_state = bridge_pkg::ST_APB_SETUP;
      end

      bridge_pkg::ST_APB_SETUP: begin
        next_req_valid = 1'b1;
        if (apb_ce) begin
          next_state = bridge_pkg::ST_APB_ACCESS;
        end
      end

      bridge_pkg::ST_APB_ACCESS: begin
        next_req_valid = 1'b1;

        if (apb_ce && Pready) begin
          next_req_valid = 1'b0;

          if (Pslverr) begin
            next_state = bridge_pkg::ST_ERROR_1;
          end else begin
            capture_rdata = !req.write;
            next_state = bridge_pkg::ST_RESP_OK;
          end
        end
      end

      bridge_pkg::ST_ERROR_1: begin
        next_req_valid = 1'b0;
        next_state = bridge_pkg::ST_ERROR_2;
      end

      default: begin
        next_req_valid = 1'b0;
        next_state = bridge_pkg::ST_ERROR_1;
      end
    endcase
  end

  // Hresetn may assert asynchronously, but release must be synchronized to Hclk
  // by the SoC reset wrapper or an external reset synchronizer.
  always_ff @(posedge Hclk or negedge Hresetn) begin
    if (!Hresetn) begin
      state <= bridge_pkg::ST_IDLE;
      req_valid <= 1'b0;
    end else begin
      state <= next_state;
      req_valid <= next_req_valid;
    end
  end

  always_ff @(posedge Hclk) begin
    if (load_header) begin
      req.aligned_addr_word <= Haddr[bridge_pkg::ADDR_WIDTH-1:2];
      req.write <= Hwrite;
      req.psel <= decoded_psel;
      req.strb <= decoded_pstrb;
      req.prot <= decoded_pprot;
    end

    // Keep HWDATA/PRDATA registered for timing ownership. If enable fanout becomes
    // critical, fix it with synthesis/P&R replication or buffering, not cut-through.
    if (capture_wdata) begin
      req.wdata <= Hwdata;
    end

    if (capture_rdata) begin
      resp_rdata <= Prdata;
    end
  end

`ifdef BRIDGE_RTL_ASSERTIONS
  ap_state_legal: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state inside {bridge_pkg::ST_IDLE,
                  bridge_pkg::ST_WAIT_WDATA,
                  bridge_pkg::ST_APB_SETUP,
                  bridge_pkg::ST_APB_ACCESS,
                  bridge_pkg::ST_RESP_OK,
                  bridge_pkg::ST_ERROR_1,
                  bridge_pkg::ST_ERROR_2}
  );

  ap_psel_onehot: assert property (@(posedge Hclk) disable iff (!Hresetn)
    $onehot0(Pselx)
  );

  ap_active_has_exactly_one_select: assert property (@(posedge Hclk) disable iff (!Hresetn)
    apb_active |-> $onehot(Pselx)
  );

  ap_valid_decode_is_onehot: assert property (@(posedge Hclk) disable iff (!Hresetn)
    ahb_active_transfer && request_ok |-> $onehot(decoded_psel)
  );

  ap_penable_requires_psel: assert property (@(posedge Hclk) disable iff (!Hresetn)
    Penable |-> (Pselx != '0)
  );

  ap_setup_to_access: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_SETUP && apb_ce |=> state == bridge_pkg::ST_APB_ACCESS
  );

  ap_setup_payload_stable_to_access: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_SETUP && apb_ce |=>
      state == bridge_pkg::ST_APB_ACCESS && Penable &&
      $stable({Pselx, Paddr, Pwrite, Pwdata, Pstrb, Pprot})
  );

  ap_setup_holds_when_pclken_low: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_SETUP && !apb_ce |=>
      state == bridge_pkg::ST_APB_SETUP &&
      $stable({Pselx, Penable, Paddr, Pwrite, Pwdata, Pstrb, Pprot})
  );

  ap_apb_wait_stability: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_ACCESS && (!apb_ce || !Pready) |=>
      state == bridge_pkg::ST_APB_ACCESS &&
      $stable({Pselx, Paddr, Pwrite, Pwdata, Pstrb, Pprot})
  );

  ap_no_apb_for_local_error: assert property (@(posedge Hclk) disable iff (!Hresetn)
    req_header_bad |=>
      (state == bridge_pkg::ST_ERROR_1 && !req_valid && Pselx == '0 && !Penable)
  );

  ap_error_1_to_error_2_no_apb: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_1 |=>
      (state == bridge_pkg::ST_ERROR_2 && !req_valid && Pselx == '0 && !Penable)
  );

  ap_error_1_output: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_1 |-> (!Hreadyout && Hresp == bridge_pkg::HRESP_ERROR)
  );

  ap_error_2_output: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_2 |-> (Hreadyout && Hresp == bridge_pkg::HRESP_ERROR)
  );

  ap_error2_read_accepted: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_2 && ahb_active_transfer && request_ok && !Hwrite |=>
      (state == bridge_pkg::ST_APB_SETUP && req_valid)
  );

  ap_error2_write_accepted: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_2 && ahb_active_transfer && request_ok && Hwrite |=>
      (state == bridge_pkg::ST_WAIT_WDATA && !req_valid)
  );

  ap_error2_bad_request: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_2 && ahb_active_transfer && !request_ok |=>
      state == bridge_pkg::ST_ERROR_1
  );

  ap_response_error_apb_inactive: assert property (@(posedge Hclk) disable iff (!Hresetn)
    (state == bridge_pkg::ST_RESP_OK ||
     state == bridge_pkg::ST_ERROR_1 ||
     state == bridge_pkg::ST_ERROR_2) |-> (Pselx == '0 && !Penable)
  );

  ap_read_pstrb_zero: assert property (@(posedge Hclk) disable iff (!Hresetn)
    apb_active && !Pwrite |-> (Pstrb == '0)
  );

  ap_paddr_word_aligned: assert property (@(posedge Hclk) disable iff (!Hresetn)
    apb_active |-> (Paddr[1:0] == 2'b00)
  );

  ap_apb_state_has_valid_request: assert property (@(posedge Hclk) disable iff (!Hresetn)
    (state == bridge_pkg::ST_APB_SETUP || state == bridge_pkg::ST_APB_ACCESS) |-> req_valid
  );

  ap_no_request_overwrite: assert property (@(posedge Hclk) disable iff (!Hresetn)
    load_header |-> !req_valid
  );

  ap_valid_only_in_apb_states: assert property (@(posedge Hclk) disable iff (!Hresetn)
    req_valid |-> (state inside {bridge_pkg::ST_APB_SETUP, bridge_pkg::ST_APB_ACCESS})
  );

  ap_write_header_waits_for_data: assert property (@(posedge Hclk) disable iff (!Hresetn)
    req_header_push && Hwrite |=> (state == bridge_pkg::ST_WAIT_WDATA && !req_valid)
  );

  ap_wait_wdata_no_apb: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_WAIT_WDATA |-> (!req_valid && Pselx == '0 && !Penable)
  );

  ap_wait_wdata_capture_completes_request: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_WAIT_WDATA |=> (state == bridge_pkg::ST_APB_SETUP && req_valid)
  );

  ap_write_data_captured_once: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_WAIT_WDATA |=> req.wdata == $past(Hwdata)
  );

  ap_pslverr_maps_to_error: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_ACCESS && apb_ce && Pready && Pslverr |=>
      state == bridge_pkg::ST_ERROR_1
  );

  ap_final_access_stalls_ahb: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_ACCESS && apb_ce && Pready |->
      (!Hreadyout && Hresp == bridge_pkg::HRESP_OKAY)
  );

  ap_success_to_resp_ok: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_ACCESS && apb_ce && Pready && !Pslverr |=>
      (state == bridge_pkg::ST_RESP_OK && Hreadyout && Hresp == bridge_pkg::HRESP_OKAY)
  );

  ap_two_cycle_error: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_ERROR_1 |=> state == bridge_pkg::ST_ERROR_2
  );

  ap_registered_read_data: assert property (@(posedge Hclk) disable iff (!Hresetn)
    state == bridge_pkg::ST_APB_ACCESS && apb_ce && Pready && !Pslverr && !req.write |=>
      Hrdata == $past(Prdata)
  );
`endif
endmodule

module Bridge_Top #(
  parameter bit USE_PCLKEN = bridge_pkg::DEFAULT_USE_PCLKEN
)(
  input  wire logic                         Hclk,
  input  wire logic                         Hresetn,
  input  wire logic                         Pclken,
  input  wire logic                         Hsel,
  input  wire logic                         Hwrite,
  input  wire logic                         Hreadyin,
  output logic                              Hreadyout,
  input  wire logic [2:0]                   Hsize,
  // Release 1 accepts each beat independently. HBURST/HMASTLOCK are retained as
  // interface metadata only; full burst/lock semantics are not claimed here.
  /* verilator lint_off UNUSEDSIGNAL */
  input  wire logic [2:0]                   Hburst,
  /* verilator lint_on UNUSEDSIGNAL */
  input  wire logic [3:0]                   Hprot,
  /* verilator lint_off UNUSEDSIGNAL */
  input  wire logic                         Hmastlock,
  /* verilator lint_on UNUSEDSIGNAL */
  input  wire logic [bridge_pkg::DATA_WIDTH-1:0] Hwdata,
  input  wire logic [bridge_pkg::ADDR_WIDTH-1:0] Haddr,
  input  wire logic [1:0]                   Htrans,
  input  wire logic [bridge_pkg::DATA_WIDTH-1:0] Prdata,
  input  wire logic                         Pready,
  input  wire logic                         Pslverr,
  output logic                              Penable,
  output logic                              Pwrite,
  output logic [bridge_pkg::NUM_APB_SLAVES-1:0] Pselx,
  output logic [bridge_pkg::ADDR_WIDTH-1:0] Paddr,
  output logic [bridge_pkg::DATA_WIDTH-1:0] Pwdata,
  output logic [bridge_pkg::STRB_WIDTH-1:0] Pstrb,
  output logic [2:0]                        Pprot,
  output logic [1:0]                        Hresp,
  output logic [bridge_pkg::DATA_WIDTH-1:0] Hrdata
);
  logic                              ahb_active_transfer;
  logic                              request_ok;
  logic [bridge_pkg::NUM_APB_SLAVES-1:0] decoded_psel;
  logic [bridge_pkg::STRB_WIDTH-1:0] decoded_pstrb;
  logic [2:0]                        decoded_pprot;

  /* verilator lint_off PINCONNECTEMPTY */
  ahb_request_validator validator (
    .Hsel(Hsel),
    .Hreadyin(Hreadyin),
    .Hwrite(Hwrite),
    .Hsize(Hsize),
    .Hprot(Hprot),
    .Haddr(Haddr),
    .Htrans(Htrans),
    .active_transfer(ahb_active_transfer),
    .mapped(),
    .size_supported(),
    .aligned(),
    .request_ok(request_ok),
    .decoded_psel(decoded_psel),
    .decoded_pstrb(decoded_pstrb),
    .decoded_pprot(decoded_pprot)
  );
  /* verilator lint_on PINCONNECTEMPTY */

  bridge_7state_core #(
    .USE_PCLKEN(USE_PCLKEN)
  ) core (
    .Hclk(Hclk),
    .Hresetn(Hresetn),
    .Pclken(Pclken),
    .Hwrite(Hwrite),
    .Hwdata(Hwdata),
    .Haddr(Haddr),
    .Prdata(Prdata),
    .Pready(Pready),
    .Pslverr(Pslverr),
    .ahb_active_transfer(ahb_active_transfer),
    .request_ok(request_ok),
    .decoded_psel(decoded_psel),
    .decoded_pstrb(decoded_pstrb),
    .decoded_pprot(decoded_pprot),
    .Hreadyout(Hreadyout),
    .Hresp(Hresp),
    .Hrdata(Hrdata),
    .Penable(Penable),
    .Pwrite(Pwrite),
    .Pselx(Pselx),
    .Paddr(Paddr),
    .Pwdata(Pwdata),
    .Pstrb(Pstrb),
    .Pprot(Pprot)
  );
endmodule

`default_nettype wire
