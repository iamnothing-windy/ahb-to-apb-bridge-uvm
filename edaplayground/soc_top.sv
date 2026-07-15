`timescale 1ns/1ps
`default_nettype none

// =============================================================================
// FPGA demonstration SoC top for the AHB-to-APB bridge.
//
// Physical FPGA pins:
//   clk      : board clock, for example 50 MHz
//   reset_n  : active-low push-button reset
//   led[7:0] : test/debug status
//
// Internal architecture:
//   ahb_demo_master -> Bridge_Top -> three APB register slaves
//
// This file assumes the existing bridge RTL provides module Bridge_Top with:
//   parameter USE_PCLKEN
//   32-bit AHB/APB data and address buses
//   three-bit PSELx
//
// Quartus project:
//   1. Add the existing bridge RTL file.
//   2. Add this soc_top.sv file.
//   3. Set soc_top as Top-level entity.
//   4. Assign only clk, reset_n, and led[] to package pins.
// =============================================================================

module soc_top (
  input  logic       clk,
  input  logic       reset_n,
  output logic [7:0] led
);

  // ---------------------------------------------------------------------------
  // Reset synchronization
  //
  // reset_n can assert asynchronously from a push button. The internal reset
  // deasserts synchronously to clk, matching the bridge reset contract.
  // ---------------------------------------------------------------------------
  logic [1:0] reset_sync_ff;
  logic       hresetn;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      reset_sync_ff <= 2'b00;
    end else begin
      reset_sync_ff <= {reset_sync_ff[0], 1'b1};
    end
  end

  assign hresetn = reset_sync_ff[1];

  // ---------------------------------------------------------------------------
  // Internal AHB bus
  // ---------------------------------------------------------------------------
  logic        hsel;
  logic        hwrite;
  logic        hreadyin;
  logic        hreadyout;
  logic [2:0]  hsize;
  logic [2:0]  hburst;
  logic [3:0]  hprot;
  logic        hmastlock;
  logic [31:0] hwdata;
  logic [31:0] haddr;
  logic [1:0]  htrans;
  logic [1:0]  hresp;
  logic [31:0] hrdata;

  // Single-slave AHB connection. HREADY input to the bridge is the shared bus
  // ready signal, which in this small system is the bridge HREADYOUT itself.
  assign hreadyin = hreadyout;

  // ---------------------------------------------------------------------------
  // Internal APB bus
  // ---------------------------------------------------------------------------
  logic        penable;
  logic        pwrite;
  logic [2:0]  pselx;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [3:0]  pstrb;
  logic [2:0]  pprot;

  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  logic [31:0] prdata_s0;
  logic [31:0] prdata_s1;
  logic [31:0] prdata_s2;
  logic        pready_s0;
  logic        pready_s1;
  logic        pready_s2;
  logic        pslverr_s0;
  logic        pslverr_s1;
  logic        pslverr_s2;

  logic [31:0] slave0_value;
  logic [31:0] slave1_value;
  logic [31:0] slave2_value;

  // ---------------------------------------------------------------------------
  // Demo status
  // ---------------------------------------------------------------------------
  logic       test_done;
  logic       test_pass;
  logic       test_fail;
  logic [3:0] master_state_debug;

  // LED mapping:
  //   LED[7]   = test completed
  //   LED[6]   = test passed
  //   LED[5]   = test failed
  //   LED[4:2] = active PSELx
  //   LED[1]   = PENABLE
  //   LED[0]   = HREADYOUT
  always_comb begin
    led[7]   = test_done;
    led[6]   = test_pass;
    led[5]   = test_fail;
    led[4:2] = pselx;
    led[1]   = penable;
    led[0]   = hreadyout;
  end

  // ---------------------------------------------------------------------------
  // Internal AHB test master
  //
  // The sequence is:
  //   write/read slave 0
  //   write/read slave 1
  //   write/read slave 2
  //
  // The master checks all read-back data. A mismatch or AHB error turns on FAIL.
  // ---------------------------------------------------------------------------
  ahb_demo_master u_ahb_demo_master (
    .Hclk        (clk),
    .Hresetn     (hresetn),

    .Hreadyout   (hreadyout),
    .Hresp       (hresp),
    .Hrdata      (hrdata),

    .Hsel        (hsel),
    .Hwrite      (hwrite),
    .Hsize       (hsize),
    .Hburst      (hburst),
    .Hprot       (hprot),
    .Hmastlock   (hmastlock),
    .Hwdata      (hwdata),
    .Haddr       (haddr),
    .Htrans      (htrans),

    .test_done   (test_done),
    .test_pass   (test_pass),
    .test_fail   (test_fail),
    .state_debug (master_state_debug)
  );

  // ---------------------------------------------------------------------------
  // Existing bridge IP
  // ---------------------------------------------------------------------------
  Bridge_Top #(
    .USE_PCLKEN (1'b0)
  ) u_bridge (
    .Hclk       (clk),
    .Hresetn    (hresetn),
    .Pclken     (1'b1),

    .Hsel       (hsel),
    .Hwrite     (hwrite),
    .Hreadyin   (hreadyin),
    .Hreadyout  (hreadyout),
    .Hsize      (hsize),
    .Hburst     (hburst),
    .Hprot      (hprot),
    .Hmastlock  (hmastlock),
    .Hwdata     (hwdata),
    .Haddr      (haddr),
    .Htrans     (htrans),
    .Hresp      (hresp),
    .Hrdata     (hrdata),

    .Prdata     (prdata),
    .Pready     (pready),
    .Pslverr    (pslverr),
    .Penable    (penable),
    .Pwrite     (pwrite),
    .Pselx      (pselx),
    .Paddr      (paddr),
    .Pwdata     (pwdata),
    .Pstrb      (pstrb),
    .Pprot      (pprot)
  );

  // ---------------------------------------------------------------------------
  // Three APB register slaves
  //
  // Address regions are decoded by Bridge_Top:
  //   PSELx[0] : 0x8000_0000 - 0x83FF_FFFF
  //   PSELx[1] : 0x8400_0000 - 0x87FF_FFFF
  //   PSELx[2] : 0x8800_0000 - 0x8BFF_FFFF
  // ---------------------------------------------------------------------------
  apb_register_slave #(
    .RESET_VALUE (32'h0000_0000)
  ) u_apb_slave0 (
    .Pclk       (clk),
    .Presetn    (hresetn),
    .Psel       (pselx[0]),
    .Penable    (penable),
    .Pwrite     (pwrite),
    .Paddr      (paddr),
    .Pwdata     (pwdata),
    .Pstrb      (pstrb),
    .Pprot      (pprot),
    .Prdata     (prdata_s0),
    .Pready     (pready_s0),
    .Pslverr    (pslverr_s0),
    .reg_value  (slave0_value)
  );

  apb_register_slave #(
    .RESET_VALUE (32'h0000_0000)
  ) u_apb_slave1 (
    .Pclk       (clk),
    .Presetn    (hresetn),
    .Psel       (pselx[1]),
    .Penable    (penable),
    .Pwrite     (pwrite),
    .Paddr      (paddr),
    .Pwdata     (pwdata),
    .Pstrb      (pstrb),
    .Pprot      (pprot),
    .Prdata     (prdata_s1),
    .Pready     (pready_s1),
    .Pslverr    (pslverr_s1),
    .reg_value  (slave1_value)
  );

  apb_register_slave #(
    .RESET_VALUE (32'h0000_0000)
  ) u_apb_slave2 (
    .Pclk       (clk),
    .Presetn    (hresetn),
    .Psel       (pselx[2]),
    .Penable    (penable),
    .Pwrite     (pwrite),
    .Paddr      (paddr),
    .Pwdata     (pwdata),
    .Pstrb      (pstrb),
    .Pprot      (pprot),
    .Prdata     (prdata_s2),
    .Pready     (pready_s2),
    .Pslverr    (pslverr_s2),
    .reg_value  (slave2_value)
  );

  // APB return-path mux.
  //
  // PREADY defaults high when no peripheral is selected. The bridge only
  // samples APB response signals during an active ACCESS phase.
  always_comb begin
    prdata  = 32'h0000_0000;
    pready  = 1'b1;
    pslverr = 1'b0;

    case (pselx)
      3'b001: begin
        prdata  = prdata_s0;
        pready  = pready_s0;
        pslverr = pslverr_s0;
      end

      3'b010: begin
        prdata  = prdata_s1;
        pready  = pready_s1;
        pslverr = pslverr_s1;
      end

      3'b100: begin
        prdata  = prdata_s2;
        pready  = pready_s2;
        pslverr = pslverr_s2;
      end

      default: begin
        prdata  = 32'h0000_0000;
        pready  = 1'b1;
        pslverr = 1'b0;
      end
    endcase
  end

endmodule


// =============================================================================
// Simple synthesizable AHB test master
// =============================================================================
module ahb_demo_master (
  input  logic        Hclk,
  input  logic        Hresetn,

  input  logic        Hreadyout,
  input  logic [1:0]  Hresp,
  input  logic [31:0] Hrdata,

  output logic        Hsel,
  output logic        Hwrite,
  output logic [2:0]  Hsize,
  output logic [2:0]  Hburst,
  output logic [3:0]  Hprot,
  output logic        Hmastlock,
  output logic [31:0] Hwdata,
  output logic [31:0] Haddr,
  output logic [1:0]  Htrans,

  output logic        test_done,
  output logic        test_pass,
  output logic        test_fail,
  output logic [3:0]  state_debug
);

  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;

  localparam logic [1:0] HRESP_OKAY    = 2'b00;

  localparam logic [31:0] SLAVE0_ADDR = 32'h8000_0000;
  localparam logic [31:0] SLAVE1_ADDR = 32'h8400_0000;
  localparam logic [31:0] SLAVE2_ADDR = 32'h8800_0000;

  localparam logic [31:0] SLAVE0_DATA = 32'hA5A5_5A5A;
  localparam logic [31:0] SLAVE1_DATA = 32'h1234_5678;
  localparam logic [31:0] SLAVE2_DATA = 32'hCAFE_BABE;

  localparam int unsigned TIMEOUT_CYCLES = 8'd255;

  typedef enum logic [3:0] {
    M_WRITE0_ADDR = 4'd0,
    M_WRITE0_DATA = 4'd1,
    M_WRITE0_WAIT = 4'd2,
    M_READ0_ADDR  = 4'd3,
    M_READ0_WAIT  = 4'd4,

    M_WRITE1_ADDR = 4'd5,
    M_WRITE1_DATA = 4'd6,
    M_WRITE1_WAIT = 4'd7,
    M_READ1_ADDR  = 4'd8,
    M_READ1_WAIT  = 4'd9,

    M_WRITE2_ADDR = 4'd10,
    M_WRITE2_DATA = 4'd11,
    M_WRITE2_WAIT = 4'd12,
    M_READ2_ADDR  = 4'd13,
    M_READ2_WAIT  = 4'd14,

    M_DONE        = 4'd15
  } master_state_t;

  master_state_t state;
  logic [7:0]    timeout_counter;

  assign state_debug = state;

  function automatic logic is_wait_state(input master_state_t current_state);
    begin
      case (current_state)
        M_WRITE0_WAIT,
        M_READ0_WAIT,
        M_WRITE1_WAIT,
        M_READ1_WAIT,
        M_WRITE2_WAIT,
        M_READ2_WAIT: is_wait_state = 1'b1;

        default: is_wait_state = 1'b0;
      endcase
    end
  endfunction

  // AHB output generation.
  //
  // Address/control are valid in *_ADDR states. HWDATA is valid in the
  // immediately following *_DATA state, matching the AHB write data phase.
  always_comb begin
    Hsel      = 1'b0;
    Hwrite    = 1'b0;
    Hsize     = 3'b010;  // 32-bit word
    Hburst    = 3'b000;  // SINGLE
    Hprot     = 4'b0011;
    Hmastlock = 1'b0;
    Hwdata    = 32'h0000_0000;
    Haddr     = 32'h0000_0000;
    Htrans    = HTRANS_IDLE;

    case (state)
      M_WRITE0_ADDR: begin
        Hsel   = 1'b1;
        Hwrite = 1'b1;
        Haddr  = SLAVE0_ADDR;
        Htrans = HTRANS_NONSEQ;
      end

      M_WRITE0_DATA: begin
        Hwdata = SLAVE0_DATA;
      end

      M_READ0_ADDR: begin
        Hsel   = 1'b1;
        Hwrite = 1'b0;
        Haddr  = SLAVE0_ADDR;
        Htrans = HTRANS_NONSEQ;
      end

      M_WRITE1_ADDR: begin
        Hsel   = 1'b1;
        Hwrite = 1'b1;
        Haddr  = SLAVE1_ADDR;
        Htrans = HTRANS_NONSEQ;
      end

      M_WRITE1_DATA: begin
        Hwdata = SLAVE1_DATA;
      end

      M_READ1_ADDR: begin
        Hsel   = 1'b1;
        Hwrite = 1'b0;
        Haddr  = SLAVE1_ADDR;
        Htrans = HTRANS_NONSEQ;
      end

      M_WRITE2_ADDR: begin
        Hsel   = 1'b1;
        Hwrite = 1'b1;
        Haddr  = SLAVE2_ADDR;
        Htrans = HTRANS_NONSEQ;
      end

      M_WRITE2_DATA: begin
        Hwdata = SLAVE2_DATA;
      end

      M_READ2_ADDR: begin
        Hsel   = 1'b1;
        Hwrite = 1'b0;
        Haddr  = SLAVE2_ADDR;
        Htrans = HTRANS_NONSEQ;
      end

      default: begin
        Hsel   = 1'b0;
        Hwrite = 1'b0;
        Haddr  = 32'h0000_0000;
        Htrans = HTRANS_IDLE;
      end
    endcase
  end

  // Master control and read-back checking.
  always_ff @(posedge Hclk or negedge Hresetn) begin
    if (!Hresetn) begin
      state           <= M_WRITE0_ADDR;
      timeout_counter <= 8'd0;
      test_done       <= 1'b0;
      test_pass       <= 1'b0;
      test_fail       <= 1'b0;
    end else begin
      if (is_wait_state(state) && !Hreadyout) begin
        if (timeout_counter != TIMEOUT_CYCLES[7:0]) begin
          timeout_counter <= timeout_counter + 8'd1;
        end
      end else begin
        timeout_counter <= 8'd0;
      end

      if (is_wait_state(state) &&
          !Hreadyout &&
          timeout_counter == TIMEOUT_CYCLES[7:0]) begin
        state     <= M_DONE;
        test_done <= 1'b1;
        test_pass <= 1'b0;
        test_fail <= 1'b1;
      end else begin
        case (state)
          M_WRITE0_ADDR: begin
            if (Hreadyout) begin
              state <= M_WRITE0_DATA;
            end
          end

          M_WRITE0_DATA: begin
            state <= M_WRITE0_WAIT;
          end

          M_WRITE0_WAIT: begin
            if (Hreadyout) begin
              if (Hresp != HRESP_OKAY) begin
                state     <= M_DONE;
                test_done <= 1'b1;
                test_pass <= 1'b0;
                test_fail <= 1'b1;
              end else begin
                state <= M_READ0_ADDR;
              end
            end
          end

          M_READ0_ADDR: begin
            if (Hreadyout) begin
              state <= M_READ0_WAIT;
            end
          end

          M_READ0_WAIT: begin
            if (Hreadyout) begin
              if ((Hresp != HRESP_OKAY) || (Hrdata != SLAVE0_DATA)) begin
                state     <= M_DONE;
                test_done <= 1'b1;
                test_pass <= 1'b0;
                test_fail <= 1'b1;
              end else begin
                state <= M_WRITE1_ADDR;
              end
            end
          end

          M_WRITE1_ADDR: begin
            if (Hreadyout) begin
              state <= M_WRITE1_DATA;
            end
          end

          M_WRITE1_DATA: begin
            state <= M_WRITE1_WAIT;
          end

          M_WRITE1_WAIT: begin
            if (Hreadyout) begin
              if (Hresp != HRESP_OKAY) begin
                state     <= M_DONE;
                test_done <= 1'b1;
                test_pass <= 1'b0;
                test_fail <= 1'b1;
              end else begin
                state <= M_READ1_ADDR;
              end
            end
          end

          M_READ1_ADDR: begin
            if (Hreadyout) begin
              state <= M_READ1_WAIT;
            end
          end

          M_READ1_WAIT: begin
            if (Hreadyout) begin
              if ((Hresp != HRESP_OKAY) || (Hrdata != SLAVE1_DATA)) begin
                state     <= M_DONE;
                test_done <= 1'b1;
                test_pass <= 1'b0;
                test_fail <= 1'b1;
              end else begin
                state <= M_WRITE2_ADDR;
              end
            end
          end

          M_WRITE2_ADDR: begin
            if (Hreadyout) begin
              state <= M_WRITE2_DATA;
            end
          end

          M_WRITE2_DATA: begin
            state <= M_WRITE2_WAIT;
          end

          M_WRITE2_WAIT: begin
            if (Hreadyout) begin
              if (Hresp != HRESP_OKAY) begin
                state     <= M_DONE;
                test_done <= 1'b1;
                test_pass <= 1'b0;
                test_fail <= 1'b1;
              end else begin
                state <= M_READ2_ADDR;
              end
            end
          end

          M_READ2_ADDR: begin
            if (Hreadyout) begin
              state <= M_READ2_WAIT;
            end
          end

          M_READ2_WAIT: begin
            if (Hreadyout) begin
              state     <= M_DONE;
              test_done <= 1'b1;

              if ((Hresp == HRESP_OKAY) && (Hrdata == SLAVE2_DATA)) begin
                test_pass <= 1'b1;
                test_fail <= 1'b0;
              end else begin
                test_pass <= 1'b0;
                test_fail <= 1'b1;
              end
            end
          end

          M_DONE: begin
            state     <= M_DONE;
            test_done <= 1'b1;
          end

          default: begin
            state     <= M_DONE;
            test_done <= 1'b1;
            test_pass <= 1'b0;
            test_fail <= 1'b1;
          end
        endcase
      end
    end
  end

endmodule


// =============================================================================
// Simple APB4 register slave
//
// One 32-bit register is implemented. The slave is always ready and never
// reports an error. PSTRB supports byte/halfword/word writes.
// =============================================================================
module apb_register_slave #(
  parameter logic [31:0] RESET_VALUE = 32'h0000_0000
)(
  input  logic        Pclk,
  input  logic        Presetn,
  input  logic        Psel,
  input  logic        Penable,
  input  logic        Pwrite,
  input  logic [31:0] Paddr,
  input  logic [31:0] Pwdata,
  input  logic [3:0]  Pstrb,
  input  logic [2:0]  Pprot,

  output logic [31:0] Prdata,
  output logic        Pready,
  output logic        Pslverr,
  output logic [31:0] reg_value
);

  integer byte_index;

  // This simple slave responds immediately.
  assign Pready  = 1'b1;
  assign Pslverr = 1'b0;
  assign Prdata  = reg_value;

  always_ff @(posedge Pclk or negedge Presetn) begin
    if (!Presetn) begin
      reg_value <= RESET_VALUE;
    end else if (Psel && Penable && Pready && Pwrite) begin
      for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
        if (Pstrb[byte_index]) begin
          reg_value[(byte_index * 8) +: 8] <=
            Pwdata[(byte_index * 8) +: 8];
        end
      end
    end
  end

  // Paddr and Pprot are intentionally not decoded in this minimal demo slave.
  // In a real peripheral, use Paddr for the register map and Pprot for access
  // policy where required.

endmodule

`default_nettype wire