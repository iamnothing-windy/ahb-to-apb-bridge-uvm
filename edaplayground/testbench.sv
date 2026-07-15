`timescale 1ns/1ps

interface ahb_if(input logic Hclk);
  logic        Hresetn;
  logic        Hsel;
  logic        Hwrite;
  logic        Hreadyin;
  logic        Hreadyout;
  logic [31:0] Hwdata;
  logic [31:0] Haddr;
  logic [1:0]  Htrans;
  logic [2:0]  Hsize;
  logic [2:0]  Hburst;
  logic [3:0]  Hprot;
  logic        Hmastlock;
  logic [1:0]  Hresp;
  logic [31:0] Hrdata;

  task automatic drive_idle();
    Hsel     <= 1'b0;
    Hwrite   <= 1'b0;
    Hreadyin <= 1'b1;
    Htrans   <= 2'b00;
    Hsize    <= 3'b010;
    Hburst   <= 3'b000;
    Hprot    <= 4'b0011;
    Hmastlock <= 1'b0;
    Haddr    <= 32'h0000_0000;
    Hwdata   <= 32'h0000_0000;
  endtask
endinterface

interface apb_if(input logic Pclk);
  logic        Hresetn;
  logic        Penable;
  logic        Pwrite;
  logic        Pready;
  logic        Pslverr;
  logic [2:0]  Pselx;
  logic [31:0] Paddr;
  logic [31:0] Pwdata;
  logic [31:0] Prdata;
  logic [3:0]  Pstrb;
  logic [2:0]  Pprot;
endinterface

package bridge_uvm_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_ahb)
  `uvm_analysis_imp_decl(_apb)

  typedef enum int {
    ADDR_PSEL0,
    ADDR_PSEL1,
    ADDR_PSEL2,
    ADDR_INVALID_LOW,
    ADDR_INVALID_HIGH,
    ADDR_BOUNDARY
  } addr_kind_e;

  typedef enum int {
    APB_SETUP,
    APB_ENABLE
  } apb_phase_e;

  typedef enum int {
    RSP_OKAY,
    RSP_LOCAL_ERROR,
    RSP_APB_ERROR
  } rsp_kind_e;

  typedef struct {
    bit          exp_hreadyout;
    bit [1:0]    exp_hresp;
    rsp_kind_e   kind;
    bit          check_hrdata;
    bit [31:0]   exp_hrdata;
    bit [31:0]   paddr;
    int unsigned delay;
  } ahb_rsp_check_s;

  function string red_mismatch(string msg);
    if ($test$plusargs("NO_COLOR_MISMATCH")) begin
      return {"MISMATCH: ", msg};
    end
    return $sformatf("%c[31mMISMATCH: %s%c[0m", 8'h1b, msg, 8'h1b);
  endfunction

  class ahb_item extends uvm_sequence_item;
    rand bit        hsel;
    rand bit        hwrite;
    rand bit [1:0]  htrans;
    rand bit [2:0]  hsize;
    rand bit [2:0]  hburst;
    rand bit [3:0]  hprot;
    rand bit        hmastlock;
    bit             hreadyin;
    rand bit [31:0] haddr;
    rand bit [31:0] hwdata;
    rand int unsigned pre_idle_cycles;
    rand int unsigned post_idle_cycles;
    rand int unsigned hreadyin_stall_cycles;
    rand bit        inject_reset_before;
    rand bit        inject_reset_during;
    rand int unsigned reset_cycles;
    rand addr_kind_e addr_kind;

    bit       expected_valid;
    bit       expected_error;
    bit [2:0] expected_pselx;
    longint unsigned accept_cycle;

    `uvm_object_utils_begin(ahb_item)
      `uvm_field_int(hsel, UVM_ALL_ON)
      `uvm_field_int(hwrite, UVM_ALL_ON)
      `uvm_field_int(htrans, UVM_ALL_ON)
      `uvm_field_int(hsize, UVM_ALL_ON)
      `uvm_field_int(hburst, UVM_ALL_ON)
      `uvm_field_int(hprot, UVM_ALL_ON)
      `uvm_field_int(hmastlock, UVM_ALL_ON)
      `uvm_field_int(hreadyin, UVM_ALL_ON)
      `uvm_field_int(hreadyin_stall_cycles, UVM_ALL_ON)
      `uvm_field_int(haddr, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(hwdata, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(pre_idle_cycles, UVM_ALL_ON)
      `uvm_field_int(post_idle_cycles, UVM_ALL_ON)
      `uvm_field_int(inject_reset_before, UVM_ALL_ON)
      `uvm_field_int(inject_reset_during, UVM_ALL_ON)
      `uvm_field_int(reset_cycles, UVM_ALL_ON)
      `uvm_field_enum(addr_kind_e, addr_kind, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_default_dist {
      hsel dist {0 := 10, 1 := 90};
      hwrite dist {0 := 50, 1 := 50};
      htrans dist {2'b00 := 10, 2'b01 := 10, 2'b10 := 45, 2'b11 := 35};
      hsize dist {
        3'b000 := 5,
        3'b001 := 5,
        3'b010 := 70,
        3'b011 := 5,
        3'b100 := 5,
        3'b101 := 4,
        3'b110 := 3,
        3'b111 := 3
      };
      hburst dist {
        3'b000 := 30,
        3'b001 := 20,
        3'b010 := 10,
        3'b011 := 10,
        3'b100 := 10,
        3'b101 := 8,
        3'b110 := 6,
        3'b111 := 6
      };
      hprot dist {
        4'h0 := 5,  4'h1 := 5,  4'h2 := 5,  4'h3 := 25,
        4'h4 := 5,  4'h5 := 5,  4'h6 := 5,  4'h7 := 5,
        4'h8 := 5,  4'h9 := 5,  4'ha := 5,  4'hb := 5,
        4'hc := 5,  4'hd := 5,  4'he := 5,  4'hf := 5
      };
      hmastlock dist {0 := 95, 1 := 5};
      hreadyin_stall_cycles dist {0 := 85, [1:3] := 10, [4:10] := 5};
      addr_kind dist {
        ADDR_PSEL0        := 22,
        ADDR_PSEL1        := 22,
        ADDR_PSEL2        := 22,
        ADDR_INVALID_LOW  := 12,
        ADDR_INVALID_HIGH := 12,
        ADDR_BOUNDARY     := 10
      };
      soft inject_reset_before == 1'b0;
      soft inject_reset_during == 1'b0;
    }

    constraint c_addr {
      if (addr_kind == ADDR_PSEL0) {
        haddr inside {[32'h8000_0000:32'h83ff_ffff]};
      } else if (addr_kind == ADDR_PSEL1) {
        haddr inside {[32'h8400_0000:32'h87ff_ffff]};
      } else if (addr_kind == ADDR_PSEL2) {
        haddr inside {[32'h8800_0000:32'h8bff_ffff]};
      } else if (addr_kind == ADDR_INVALID_LOW) {
        haddr < 32'h8000_0000;
      } else if (addr_kind == ADDR_INVALID_HIGH) {
        haddr >= 32'h8c00_0000;
      } else {
        haddr inside {
          32'h7fff_fffc,
          32'h8000_0000,
          32'h83ff_fffc,
          32'h8400_0000,
          32'h87ff_fffc,
          32'h8800_0000,
          32'h8bff_fffc,
          32'h8c00_0000
        };
      }
    }

    constraint c_timing {
      pre_idle_cycles inside {[0:3]};
      post_idle_cycles inside {[0:3]};
      hreadyin_stall_cycles inside {[0:10]};
      reset_cycles inside {[2:5]};
    }

    constraint c_alignment_dist {
      haddr[1:0] dist {2'b00 := 80, 2'b01 := 7, 2'b10 := 7, 2'b11 := 6};
    }

    function new(string name = "ahb_item");
      super.new(name);
    endfunction

    function bit is_supported_size();
      return hsize inside {3'b000, 3'b001, 3'b010};
    endfunction

    function bit is_aligned_transfer();
      if (hsize == 3'b000) begin
        return 1'b1;
      end else if (hsize == 3'b001) begin
        return (haddr[0] == 1'b0);
      end else if (hsize == 3'b010) begin
        return (haddr[1:0] == 2'b00);
      end
      return 1'b0;
    endfunction

    function bit is_valid_transfer();
      return hsel && htrans[1] && is_supported_size() &&
             is_aligned_transfer() &&
             (haddr >= 32'h8000_0000) && (haddr < 32'h8c00_0000);
    endfunction

    function bit is_selected_transfer();
      return hsel && htrans[1];
    endfunction

    function bit is_unsupported_selected_transfer();
      return is_selected_transfer() && !is_valid_transfer();
    endfunction

    function bit [2:0] decode_pselx();
      if (haddr >= 32'h8000_0000 && haddr < 32'h8400_0000) begin
        return 3'b001;
      end else if (haddr >= 32'h8400_0000 && haddr < 32'h8800_0000) begin
        return 3'b010;
      end else if (haddr >= 32'h8800_0000 && haddr < 32'h8c00_0000) begin
        return 3'b100;
      end
      return 3'b000;
    endfunction

    function bit [31:0] make_paddr();
      return {haddr[31:2], 2'b00};
    endfunction

    function bit [3:0] make_pstrb();
      if (!hwrite) begin
        return 4'b0000;
      end

      case (hsize)
        3'b000: begin
          case (haddr[1:0])
            2'b00: return 4'b0001;
            2'b01: return 4'b0010;
            2'b10: return 4'b0100;
            2'b11: return 4'b1000;
          endcase
        end
        3'b001: begin
          case (haddr[1])
            1'b0: return 4'b0011;
            1'b1: return 4'b1100;
          endcase
        end
        3'b010: return 4'b1111;
        default: return 4'b0000;
      endcase
      return 4'b0000;
    endfunction

    function bit [2:0] make_pprot();
      case (hprot[1:0])
        2'b00: return 3'b100;
        2'b01: return 3'b000;
        2'b10: return 3'b101;
        2'b11: return 3'b001;
      endcase
      return 3'b000;
    endfunction

    function void post_randomize();
      hreadyin = (hreadyin_stall_cycles == 0);
      expected_valid = is_valid_transfer();
      expected_error = is_unsupported_selected_transfer();
      expected_pselx = decode_pselx();
    endfunction
  endclass

  class apb_item extends uvm_sequence_item;
    apb_phase_e phase;
    bit        pwrite;
    bit        penable;
    bit        pready;
    bit        pslverr;
    bit [2:0]  pselx;
    bit [31:0] paddr;
    bit [31:0] pwdata;
    bit [31:0] prdata;
    bit [3:0]  pstrb;
    bit [2:0]  pprot;

    `uvm_object_utils_begin(apb_item)
      `uvm_field_enum(apb_phase_e, phase, UVM_ALL_ON)
      `uvm_field_int(pwrite, UVM_ALL_ON)
      `uvm_field_int(penable, UVM_ALL_ON)
      `uvm_field_int(pready, UVM_ALL_ON)
      `uvm_field_int(pslverr, UVM_ALL_ON)
      `uvm_field_int(pselx, UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(paddr, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(pwdata, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(prdata, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(pstrb, UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(pprot, UVM_ALL_ON | UVM_BIN)
    `uvm_object_utils_end

    function new(string name = "apb_item");
      super.new(name);
    endfunction
  endclass

  class ahb_sequencer extends uvm_sequencer #(ahb_item);
    `uvm_component_utils(ahb_sequencer)

    function new(string name = "ahb_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass

  class ahb_driver extends uvm_driver #(ahb_item);
    `uvm_component_utils(ahb_driver)

    virtual ahb_if vif;
    bit pipeline_driver_mode;
    int unsigned pipeline_burst_len;

    function new(string name = "ahb_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      int cfg_pipeline_burst_len;

      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ahb_if was not set for ahb_driver")
      end

      if (!uvm_config_db#(bit)::get(this, "", "pipeline_driver_mode", pipeline_driver_mode)) begin
        pipeline_driver_mode = $test$plusargs("PIPELINE_DRIVER_MODE");
      end

      pipeline_burst_len = 8;
      if (uvm_config_db#(int)::get(this, "", "pipeline_burst_len", cfg_pipeline_burst_len)) begin
        pipeline_burst_len = cfg_pipeline_burst_len;
      end
      void'($value$plusargs("PIPELINE_BURST_LEN=%0d", pipeline_burst_len));
      if (pipeline_burst_len == 0) begin
        pipeline_burst_len = 1;
      end
    endfunction

    task run_phase(uvm_phase phase);
      ahb_item tr;

      init_bus();
      apply_reset(5);

      if (pipeline_driver_mode) begin
        run_pipeline_mode();
        return;
      end

      forever begin
        seq_item_port.get_next_item(tr);
        drive_transfer(tr);
        seq_item_port.item_done();
      end
    endtask

    task init_bus();
      vif.Hresetn  <= 1'b0;
      vif.Hsel     <= 1'b0;
      vif.Hwrite   <= 1'b0;
      vif.Hreadyin <= 1'b1;
      vif.Htrans   <= 2'b00;
      vif.Hsize    <= 3'b010;
      vif.Hburst   <= 3'b000;
      vif.Hprot    <= 4'b0011;
      vif.Hmastlock <= 1'b0;
      vif.Haddr    <= 32'h0000_0000;
      vif.Hwdata   <= 32'h0000_0000;
    endtask

    task apply_reset(int unsigned cycles);
      @(negedge vif.Hclk);
      vif.Hresetn  <= 1'b0;
      vif.Hsel     <= 1'b0;
      vif.Hwrite   <= 1'b0;
      vif.Hreadyin <= 1'b1;
      vif.Htrans   <= 2'b00;
      vif.Hsize    <= 3'b010;
      vif.Hburst   <= 3'b000;
      vif.Hprot    <= 4'b0011;
      vif.Hmastlock <= 1'b0;
      vif.Haddr    <= 32'h0000_0000;
      vif.Hwdata   <= 32'h0000_0000;
      repeat (cycles) @(posedge vif.Hclk);
      @(negedge vif.Hclk);
      vif.Hresetn <= 1'b1;
      @(posedge vif.Hclk);
    endtask

    task drive_idle_cycle();
      @(negedge vif.Hclk);
      vif.drive_idle();
      @(posedge vif.Hclk);
    endtask

    task wait_readyout();
      int unsigned guard;

      guard = 0;
      while (vif.Hreadyout !== 1'b1 && guard < 20) begin
        drive_idle_cycle();
        guard++;
      end

      if (guard == 20) begin
        `uvm_error("AHB_DRV", "Timeout waiting for Hreadyout")
      end
    endtask

    task drive_addr_controls(ahb_item tr, bit hreadyin_value);
      vif.Hsel      <= tr.hsel;
      vif.Hwrite    <= tr.hwrite;
      vif.Hreadyin  <= hreadyin_value;
      vif.Htrans    <= tr.htrans;
      vif.Hsize     <= tr.hsize;
      vif.Hburst    <= tr.hburst;
      vif.Hprot     <= tr.hprot;
      vif.Hmastlock <= tr.hmastlock;
      vif.Haddr     <= tr.haddr;
      vif.Hwdata    <= 32'h0000_0000;
    endtask

    task hold_addr_until_ready(ahb_item tr);
      int unsigned low_cycles_seen;

      if (tr.hreadyin_stall_cycles == 0) begin
        return;
      end

      low_cycles_seen = 1;
      while (low_cycles_seen < tr.hreadyin_stall_cycles) begin
        @(negedge vif.Hclk);
        drive_addr_controls(tr, 1'b0);
        @(posedge vif.Hclk);
        low_cycles_seen++;
      end

      @(negedge vif.Hclk);
      drive_addr_controls(tr, 1'b1);
      @(posedge vif.Hclk);
    endtask

    task drive_transfer(ahb_item tr);
      if (tr.inject_reset_before) begin
        apply_reset(tr.reset_cycles);
      end

      wait_readyout();

      repeat (tr.pre_idle_cycles) begin
        drive_idle_cycle();
      end

      @(negedge vif.Hclk);
      drive_addr_controls(tr, tr.hreadyin_stall_cycles == 0);
      @(posedge vif.Hclk);

      if (tr.inject_reset_during) begin
        apply_reset(tr.reset_cycles);
        return;
      end

      hold_addr_until_ready(tr);

      @(negedge vif.Hclk);
      vif.Hsel     <= tr.hsel;
      vif.Hwrite   <= tr.hwrite;
      vif.Hreadyin <= 1'b1;
      vif.Htrans   <= 2'b00;
      vif.Hsize    <= tr.hsize;
      vif.Hburst   <= tr.hburst;
      vif.Hprot    <= tr.hprot;
      vif.Hmastlock <= tr.hmastlock;
      vif.Haddr    <= tr.haddr;
      vif.Hwdata   <= tr.hwdata;
      @(posedge vif.Hclk);

      hold_data_until_ready(tr);

      repeat (tr.post_idle_cycles) begin
        drive_idle_cycle();
      end
    endtask

    task hold_data_until_ready(ahb_item tr);
      int unsigned guard;

      guard = 0;

      // Always insert at least one non-address cycle after the data phase.
      // Without this, a zero-delay race can accidentally turn a single-transfer
      // test into a pipelined test before Hreadyout has deasserted.
      do begin
        @(negedge vif.Hclk);
        vif.Hsel     <= tr.hsel;
        vif.Hwrite   <= tr.hwrite;
        vif.Hreadyin <= 1'b0;
        vif.Htrans   <= 2'b00;
        vif.Hsize    <= tr.hsize;
        vif.Hburst   <= tr.hburst;
        vif.Hprot    <= tr.hprot;
        vif.Hmastlock <= tr.hmastlock;
        vif.Haddr    <= tr.haddr;
        vif.Hwdata   <= tr.hwdata;
        @(posedge vif.Hclk);
        guard++;

        if (guard == 20) begin
          `uvm_error("AHB_DRV", "Timeout holding data while waiting for Hreadyout")
          break;
        end
      end while (vif.Hreadyout !== 1'b1);


      @(negedge vif.Hclk);
      vif.drive_idle();
      @(posedge vif.Hclk);
    endtask

    task run_pipeline_mode();
      ahb_item tr;
      ahb_item burst_q[$];

      forever begin
        burst_q.delete();

        seq_item_port.get_next_item(tr);
        burst_q.push_back(tr);
        seq_item_port.item_done();

        repeat (pipeline_burst_len - 1) begin
          tr = null;
          #0;
          seq_item_port.try_next_item(tr);
          if (tr == null) begin
            break;
          end

          burst_q.push_back(tr);
          seq_item_port.item_done();
        end

        drive_pipeline_burst(burst_q);
      end
    endtask

    task drive_pipeline_burst(ref ahb_item burst_q[$]);
      int unsigned i;
      int unsigned guard;

      if (burst_q.size() == 0) begin
        return;
      end

      wait_readyout();

      @(negedge vif.Hclk);
      vif.Hsel     <= burst_q[0].hsel;
      vif.Hwrite   <= burst_q[0].hwrite;
      vif.Hreadyin <= 1'b1;
      vif.Htrans   <= 2'b10;
      vif.Hsize    <= burst_q[0].hsize;
      vif.Hburst   <= burst_q[0].hburst;
      vif.Hprot    <= burst_q[0].hprot;
      vif.Hmastlock <= burst_q[0].hmastlock;
      vif.Haddr    <= burst_q[0].haddr;
      vif.Hwdata   <= 32'h0000_0000;
      @(posedge vif.Hclk);

      for (i = 1; i < burst_q.size(); i++) begin
        guard = 0;
        do begin
          @(negedge vif.Hclk);
          vif.Hsel     <= burst_q[i].hsel;
          vif.Hwrite   <= burst_q[i].hwrite;
          vif.Hreadyin <= vif.Hreadyout;
          vif.Htrans   <= 2'b11;
          vif.Hsize    <= burst_q[i].hsize;
          vif.Hburst   <= burst_q[i].hburst;
          vif.Hprot    <= burst_q[i].hprot;
          vif.Hmastlock <= burst_q[i].hmastlock;
          vif.Haddr    <= burst_q[i].haddr;
          vif.Hwdata   <= burst_q[i-1].hwdata;
          @(posedge vif.Hclk);
          guard++;

        if (guard == 20) begin
          `uvm_error("AHB_DRV", "Timeout in pipeline address phase waiting for Hreadyout")
          break;
        end
        end while (vif.Hreadyout !== 1'b1);
      end

      guard = 0;
      do begin
        @(negedge vif.Hclk);
        vif.Hsel     <= 1'b0;
        vif.Hwrite   <= 1'b0;
        vif.Hreadyin <= vif.Hreadyout;
        vif.Htrans   <= 2'b00;
        vif.Hsize    <= 3'b010;
        vif.Hburst   <= 3'b000;
        vif.Hprot    <= 4'b0011;
        vif.Hmastlock <= 1'b0;
        vif.Haddr    <= 32'h0000_0000;
        vif.Hwdata   <= burst_q[burst_q.size()-1].hwdata;
        @(posedge vif.Hclk);
        guard++;

        if (guard == 20) begin
          `uvm_error("AHB_DRV", "Timeout completing final pipeline data phase")
          break;
        end
      end while (vif.Hreadyout !== 1'b1);

      @(negedge vif.Hclk);
      vif.drive_idle();
      @(posedge vif.Hclk);
    endtask
  endclass

  class ahb_monitor extends uvm_component;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_if vif;
    uvm_analysis_port #(ahb_item) analysis_port;
    bit monitor_log;
    int unsigned monitor_log_count;
    int unsigned monitor_log_max;
    longint unsigned cycle_count;

    function new(string name = "ahb_monitor", uvm_component parent = null);
      super.new(name, parent);
      analysis_port = new("analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ahb_if was not set for ahb_monitor")
      end
      monitor_log = !$test$plusargs("NO_MONITOR_LOG");
      monitor_log_max = 200;
      void'($value$plusargs("MONITOR_LOG_MAX=%0d", monitor_log_max));
    endfunction

    task run_phase(uvm_phase phase);
      ahb_item tr;
      ahb_item pending_write;
      bit have_pending_write;

      forever begin
        @(posedge vif.Hclk);
        cycle_count++;
        if (!vif.Hresetn) begin
          pending_write = null;
          have_pending_write = 1'b0;
          cycle_count = 0;
          continue;
        end

        if (have_pending_write) begin
          pending_write.hwdata = vif.Hwdata;

          if (monitor_log && monitor_log_count < monitor_log_max) begin
            `uvm_info("AHB_MON", $sformatf(
              "hsel=%0b hwrite=%0b htrans=%02b hsize=%03b hburst=%03b hprot=%04b hmastlock=%0b hreadyin=%0b haddr=0x%08h hwdata=0x%08h valid=%0b error=%0b exp_pselx=%03b",
              pending_write.hsel, pending_write.hwrite, pending_write.htrans,
              pending_write.hsize, pending_write.hburst, pending_write.hprot,
              pending_write.hmastlock, pending_write.hreadyin,
              pending_write.haddr, pending_write.hwdata,
              pending_write.expected_valid, pending_write.expected_error,
              pending_write.expected_pselx), UVM_NONE)
            monitor_log_count++;
          end

          analysis_port.write(pending_write);
          pending_write = null;
          have_pending_write = 1'b0;
        end

        if (!(vif.Hreadyout && vif.Hsel && vif.Hreadyin && vif.Htrans[1])) begin
          continue;
        end

        tr = ahb_item::type_id::create("tr", this);
        tr.hsel     = vif.Hsel;
        tr.hwrite   = vif.Hwrite;
        tr.htrans   = vif.Htrans;
        tr.hsize    = vif.Hsize;
        tr.hburst   = vif.Hburst;
        tr.hprot    = vif.Hprot;
        tr.hmastlock = vif.Hmastlock;
        tr.hreadyin = vif.Hreadyin;
        tr.haddr    = vif.Haddr;
        tr.hwdata   = vif.Hwdata;
        tr.accept_cycle = cycle_count;

        tr.expected_valid = tr.is_valid_transfer();
        tr.expected_error = tr.is_unsupported_selected_transfer();
        tr.expected_pselx = tr.decode_pselx();

        if (tr.hwrite && tr.expected_valid) begin
          pending_write = tr;
          have_pending_write = 1'b1;
          continue;
        end

        if (monitor_log && monitor_log_count < monitor_log_max) begin
          `uvm_info("AHB_MON", $sformatf(
            "hsel=%0b hwrite=%0b htrans=%02b hsize=%03b hburst=%03b hprot=%04b hmastlock=%0b hreadyin=%0b haddr=0x%08h hwdata=0x%08h valid=%0b error=%0b exp_pselx=%03b",
            tr.hsel, tr.hwrite, tr.htrans, tr.hsize, tr.hburst, tr.hprot,
            tr.hmastlock, tr.hreadyin, tr.haddr, tr.hwdata,
            tr.expected_valid, tr.expected_error, tr.expected_pselx), UVM_NONE)
          monitor_log_count++;
        end

        analysis_port.write(tr);
      end
    endtask
  endclass

  class ahb_agent extends uvm_agent;
    `uvm_component_utils(ahb_agent)

    ahb_sequencer sequencer;
    ahb_driver    driver;
    ahb_monitor   monitor;

    function new(string name = "ahb_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = ahb_monitor::type_id::create("monitor", this);
      if (is_active == UVM_ACTIVE) begin
        sequencer = ahb_sequencer::type_id::create("sequencer", this);
        driver    = ahb_driver::type_id::create("driver", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (is_active == UVM_ACTIVE) begin
        driver.seq_item_port.connect(sequencer.seq_item_export);
      end
    endfunction
  endclass

  class apb_monitor extends uvm_component;
    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;
    uvm_analysis_port #(apb_item) analysis_port;
    bit monitor_log;
    int unsigned monitor_log_count;
    int unsigned monitor_log_max;

    function new(string name = "apb_monitor", uvm_component parent = null);
      super.new(name, parent);
      analysis_port = new("analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "apb_if was not set for apb_monitor")
      end
      monitor_log = !$test$plusargs("NO_MONITOR_LOG");
      monitor_log_max = 200;
      void'($value$plusargs("MONITOR_LOG_MAX=%0d", monitor_log_max));
    endfunction

    task run_phase(uvm_phase phase);
      apb_item tr;

      forever begin
        @(posedge vif.Pclk);
        if (!vif.Hresetn) begin
          continue;
        end

        if (vif.Pselx != 3'b000) begin
          tr = apb_item::type_id::create("tr", this);
          tr.phase   = (vif.Penable) ? APB_ENABLE : APB_SETUP;
          tr.pwrite  = vif.Pwrite;
          tr.penable = vif.Penable;
          tr.pready  = vif.Pready;
          tr.pslverr = vif.Pslverr;
          tr.pselx   = vif.Pselx;
          tr.paddr   = vif.Paddr;
          tr.pwdata  = vif.Pwdata;
          tr.prdata  = vif.Prdata;
          tr.pstrb   = vif.Pstrb;
          tr.pprot   = vif.Pprot;

          if (monitor_log && monitor_log_count < monitor_log_max) begin
            `uvm_info("APB_MON", $sformatf(
              "phase=%s pwrite=%0b pselx=%03b penable=%0b pready=%0b pslverr=%0b paddr=0x%08h pwdata=0x%08h prdata=0x%08h pstrb=%04b pprot=%03b",
              tr.phase.name(), tr.pwrite, tr.pselx, tr.penable,
              tr.pready, tr.pslverr, tr.paddr, tr.pwdata, tr.prdata,
              tr.pstrb, tr.pprot), UVM_NONE)
            monitor_log_count++;
          end

          analysis_port.write(tr);
        end
      end
    endtask
  endclass

  class apb_slave_model extends uvm_component;
    `uvm_component_utils(apb_slave_model)

    virtual apb_if vif;
    int unsigned max_wait_cycles;
    int unsigned err_percent;
    bit seen_zero_wait;
    bit seen_wait;
    bit seen_okay;
    bit seen_error;

    function new(string name = "apb_slave_model", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      int cfg_value;

      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "apb_if was not set for apb_slave_model")
      end
      max_wait_cycles = 3;
      err_percent = 15;
      if (uvm_config_db#(int)::get(this, "", "max_wait_cycles", cfg_value)) begin
        max_wait_cycles = cfg_value;
      end
      if (uvm_config_db#(int)::get(this, "", "err_percent", cfg_value)) begin
        err_percent = cfg_value;
      end
      void'($value$plusargs("APB_MAX_WAIT=%0d", max_wait_cycles));
      void'($value$plusargs("APB_ERR_PERCENT=%0d", err_percent));
      if (err_percent > 100) begin
        err_percent = 100;
      end
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned wait_left;
      bit inject_error;
      bit [31:0] rsp_data;

      vif.Prdata <= 32'h0000_0000;
      vif.Pready <= 1'b1;
      vif.Pslverr <= 1'b0;
      wait_left = 0;
      inject_error = 1'b0;
      rsp_data = 32'h0000_0000;

      forever begin
        @(negedge vif.Pclk);
        if (!vif.Hresetn) begin
          vif.Prdata  <= 32'h0000_0000;
          vif.Pready  <= 1'b1;
          vif.Pslverr <= 1'b0;
          wait_left = 0;
          inject_error = 1'b0;
        end else if (vif.Pselx != 3'b000 && vif.Penable == 1'b0) begin
          wait_left = (max_wait_cycles == 0) ? 0 : $urandom_range(0, max_wait_cycles);
          inject_error = (err_percent != 0) && ($urandom_range(0, 99) < err_percent);

          if (!seen_zero_wait) begin
            wait_left = 0;
          end else if (!seen_wait && max_wait_cycles != 0) begin
            wait_left = $urandom_range(1, max_wait_cycles);
          end

          if (!seen_okay) begin
            inject_error = 1'b0;
          end else if (!seen_error && err_percent != 0) begin
            inject_error = 1'b1;
          end

          rsp_data = {$urandom(), $urandom()} ^ vif.Paddr ^ {29'h0, vif.Pselx};
          vif.Prdata  <= rsp_data;
          vif.Pready  <= 1'b1;
          vif.Pslverr <= 1'b0;
        end else if (vif.Pselx != 3'b000 && vif.Penable == 1'b1) begin
          vif.Prdata <= rsp_data;
          if (wait_left != 0) begin
            vif.Pready  <= 1'b0;
            vif.Pslverr <= 1'b0;
            wait_left--;
            seen_wait = 1'b1;
          end else begin
            vif.Pready  <= 1'b1;
            vif.Pslverr <= inject_error;
            seen_zero_wait = 1'b1;
            if (inject_error) begin
              seen_error = 1'b1;
            end else begin
              seen_okay = 1'b1;
            end
          end
        end else begin
          vif.Pready  <= 1'b1;
          vif.Pslverr <= 1'b0;
        end
      end
    endtask
  endclass

  class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_monitor     monitor;
    apb_slave_model slave_model;

    function new(string name = "apb_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = apb_monitor::type_id::create("monitor", this);
      if (is_active == UVM_ACTIVE) begin
        slave_model = apb_slave_model::type_id::create("slave_model", this);
      end
    endfunction
  endclass

  class bridge_scoreboard extends uvm_component;
    `uvm_component_utils(bridge_scoreboard)

    uvm_analysis_imp_ahb #(ahb_item, bridge_scoreboard) ahb_export;
    uvm_analysis_imp_apb #(apb_item, bridge_scoreboard) apb_export;

    virtual ahb_if vif;
    apb_item expected_q[$];
    apb_item active_exp;
    apb_item setup_obs;
    bit have_setup;
    int unsigned ahb_valid_count;
    int unsigned ahb_invalid_count;
    int unsigned apb_setup_count;
    int unsigned apb_enable_count;
    int unsigned apb_wait_count;
    int unsigned apb_error_count;
    int unsigned hrdata_check_count;
    int unsigned ahb_response_check_count;
    int unsigned local_error_count;
    ahb_rsp_check_s rsp_check_q[$];

    function new(string name = "bridge_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      ahb_export = new("ahb_export", this);
      apb_export = new("apb_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ahb_if was not set for bridge_scoreboard")
      end
    endfunction

    function string rsp_kind_name(rsp_kind_e kind);
      case (kind)
        RSP_OKAY:        return "OKAY";
        RSP_LOCAL_ERROR: return "LOCAL_ERROR";
        RSP_APB_ERROR:   return "APB_ERROR";
        default:         return "UNKNOWN";
      endcase
    endfunction

    function void enqueue_ahb_rsp_check(
      bit          exp_hreadyout,
      bit [1:0]    exp_hresp,
      rsp_kind_e   kind,
      int unsigned delay,
      bit          check_hrdata,
      bit [31:0]   exp_hrdata,
      bit [31:0]   paddr
    );
      ahb_rsp_check_s check;

      check.exp_hreadyout = exp_hreadyout;
      check.exp_hresp = exp_hresp;
      check.kind = kind;
      check.check_hrdata = check_hrdata;
      check.exp_hrdata = exp_hrdata;
      check.paddr = paddr;
      check.delay = delay;
      rsp_check_q.push_back(check);
    endfunction

    function void enqueue_error_response(rsp_kind_e kind);
      enqueue_ahb_rsp_check(1'b0, 2'b01, kind, 0, 1'b0, 32'h0000_0000, 32'h0000_0000);
      enqueue_ahb_rsp_check(1'b1, 2'b01, kind, 1, 1'b0, 32'h0000_0000, 32'h0000_0000);
    endfunction

    function void process_ahb_response_checks();
      int i;

      i = 0;
      while (i < rsp_check_q.size()) begin
        if (rsp_check_q[i].delay != 0) begin
          rsp_check_q[i].delay--;
          i++;
          continue;
        end

        ahb_response_check_count++;
        if (vif.Hreadyout !== rsp_check_q[i].exp_hreadyout ||
            vif.Hresp !== rsp_check_q[i].exp_hresp) begin
          `uvm_error("SCB", red_mismatch($sformatf(
            "AHB %s response cycle invalid: exp HREADYOUT=%0b HRESP=%02b got HREADYOUT=%0b HRESP=%02b",
            rsp_kind_name(rsp_check_q[i].kind), rsp_check_q[i].exp_hreadyout,
            rsp_check_q[i].exp_hresp, vif.Hreadyout, vif.Hresp)))
        end

        if (rsp_check_q[i].check_hrdata) begin
          hrdata_check_count++;
          if (vif.Hrdata !== rsp_check_q[i].exp_hrdata) begin
            `uvm_error("SCB", red_mismatch($sformatf(
              "HRDATA did not match registered APB PRDATA exp=0x%08h got=0x%08h addr=0x%08h",
              rsp_check_q[i].exp_hrdata, vif.Hrdata, rsp_check_q[i].paddr)))
          end
        end

        rsp_check_q.delete(i);
      end
    endfunction

    task run_phase(uvm_phase phase);
      fork
        forever begin
          @(negedge vif.Hresetn);
          if (expected_q.size() != 0 || have_setup || rsp_check_q.size() != 0) begin
            `uvm_info("SCB", $sformatf(
              "Reset observed, flushing %0d queued expected APB transfers, have_setup=%0b pending_rsp_checks=%0d",
              expected_q.size(), have_setup, rsp_check_q.size()), UVM_MEDIUM)
            expected_q.delete();
            have_setup = 1'b0;
            active_exp = null;
            setup_obs = null;
            rsp_check_q.delete();
          end
        end

        forever begin
          @(negedge vif.Hclk);
          if (!vif.Hresetn) begin
            rsp_check_q.delete();
            continue;
          end

          process_ahb_response_checks();
        end
      join
    endtask

    function void write_ahb(ahb_item tr);
      apb_item exp;

      if (!tr.is_valid_transfer()) begin
        ahb_invalid_count++;
        if (tr.is_unsupported_selected_transfer()) begin
          local_error_count++;
          enqueue_error_response(RSP_LOCAL_ERROR);
        end
        return;
      end

      ahb_valid_count++;
      exp = apb_item::type_id::create("exp", this);
      exp.phase   = APB_SETUP;
      exp.pwrite  = tr.hwrite;
      exp.penable = 1'b0;
      exp.pselx   = tr.decode_pselx();
      exp.paddr   = tr.make_paddr();
      exp.pwdata  = tr.hwdata;
      exp.pstrb   = tr.make_pstrb();
      exp.pprot   = tr.make_pprot();
      expected_q.push_back(exp);
    endfunction

    function void write_apb(apb_item got);
      apb_item exp;

      if (got.phase == APB_SETUP) begin
        apb_setup_count++;

        if (have_setup) begin
          `uvm_error("SCB", red_mismatch($sformatf(
            "New APB setup before previous enable: old_addr=0x%08h new_addr=0x%08h",
            setup_obs.paddr, got.paddr)))
          have_setup = 1'b0;
          active_exp = null;
          setup_obs = null;
        end

        if (expected_q.size() == 0) begin
          `uvm_error("SCB", red_mismatch($sformatf(
            "Unexpected APB setup: pwrite=%0b pselx=%03b paddr=0x%08h pwdata=0x%08h pstrb=%04b pprot=%03b",
            got.pwrite, got.pselx, got.paddr, got.pwdata, got.pstrb, got.pprot)))
          return;
        end

        exp = expected_q.pop_front();
        active_exp = exp;
        setup_obs = got;
        have_setup = 1'b1;

        if (got.penable !== 1'b0) begin
          `uvm_error("SCB", red_mismatch("APB setup observed with Penable not low"))
        end

        if (got.pwrite !== exp.pwrite) begin
          `uvm_error("SCB", red_mismatch($sformatf("Setup PWRITE mismatch exp=%0b got=%0b", exp.pwrite, got.pwrite)))
        end

        if (got.pselx !== exp.pselx) begin
          `uvm_error("SCB", red_mismatch($sformatf("Setup PSELX mismatch exp=%03b got=%03b addr=0x%08h", exp.pselx, got.pselx, exp.paddr)))
        end

        if (got.paddr !== exp.paddr) begin
          `uvm_error("SCB", red_mismatch($sformatf("Setup PADDR mismatch exp=0x%08h got=0x%08h", exp.paddr, got.paddr)))
        end

        if (exp.pwrite && got.pwdata !== exp.pwdata) begin
          `uvm_error("SCB", red_mismatch($sformatf("Setup PWDATA mismatch exp=0x%08h got=0x%08h", exp.pwdata, got.pwdata)))
        end

        if (got.pstrb !== exp.pstrb) begin
          `uvm_error("SCB", red_mismatch($sformatf("Setup PSTRB mismatch exp=%04b got=%04b addr=0x%08h hwrite=%0b", exp.pstrb, got.pstrb, exp.paddr, exp.pwrite)))
        end

        if (got.pprot !== exp.pprot) begin
          `uvm_error("SCB", red_mismatch($sformatf("Setup PPROT mismatch exp=%03b got=%03b", exp.pprot, got.pprot)))
        end

        return;
      end

      apb_enable_count++;

      if (!have_setup) begin
        `uvm_error("SCB", red_mismatch($sformatf(
          "APB enable without prior setup: pwrite=%0b pselx=%03b paddr=0x%08h pwdata=0x%08h pready=%0b pslverr=%0b",
          got.pwrite, got.pselx, got.paddr, got.pwdata, got.pready, got.pslverr)))
        return;
      end

      if (got.penable !== 1'b1) begin
        `uvm_error("SCB", red_mismatch("APB enable observed with Penable not high"))
      end

      if (got.pwrite !== setup_obs.pwrite) begin
        `uvm_error("SCB", red_mismatch($sformatf("PWRITE changed setup->enable setup=%0b enable=%0b", setup_obs.pwrite, got.pwrite)))
      end

      if (got.pselx !== setup_obs.pselx) begin
        `uvm_error("SCB", red_mismatch($sformatf("PSELX changed setup->enable setup=%03b enable=%03b", setup_obs.pselx, got.pselx)))
      end

      if (got.paddr !== setup_obs.paddr) begin
        `uvm_error("SCB", red_mismatch($sformatf("PADDR changed setup->enable setup=0x%08h enable=0x%08h", setup_obs.paddr, got.paddr)))
      end

      if (active_exp.pwrite && got.pwdata !== setup_obs.pwdata) begin
        `uvm_error("SCB", red_mismatch($sformatf("PWDATA changed setup->enable setup=0x%08h enable=0x%08h", setup_obs.pwdata, got.pwdata)))
      end

      if (got.pstrb !== setup_obs.pstrb) begin
        `uvm_error("SCB", red_mismatch($sformatf("PSTRB changed setup->enable setup=%04b enable=%04b", setup_obs.pstrb, got.pstrb)))
      end

      if (got.pprot !== setup_obs.pprot) begin
        `uvm_error("SCB", red_mismatch($sformatf("PPROT changed setup->enable setup=%03b enable=%03b", setup_obs.pprot, got.pprot)))
      end

      if (got.pslverr && !got.pready) begin
        `uvm_error("SCB", red_mismatch("PSLVERR asserted before final APB access cycle"))
      end

      if (!got.pready) begin
        apb_wait_count++;
        if (vif.Hreadyout !== 1'b0) begin
          `uvm_error("SCB", red_mismatch("HREADYOUT was not low during APB wait state"))
        end
        if (vif.Hresp !== 2'b00) begin
          `uvm_error("SCB", red_mismatch($sformatf("HRESP was not OKAY during APB wait state: %02b", vif.Hresp)))
        end
        return;
      end

      if (got.pslverr) begin
        apb_error_count++;
        enqueue_error_response(RSP_APB_ERROR);
      end else begin
        enqueue_ahb_rsp_check(1'b1, 2'b00, RSP_OKAY, 0, !active_exp.pwrite, got.prdata, got.paddr);
      end

      have_setup = 1'b0;
      active_exp = null;
      setup_obs = null;
    endfunction

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (expected_q.size() != 0) begin
        `uvm_error("SCB", red_mismatch($sformatf("%0d expected APB transfers were not observed", expected_q.size())))
      end

      if (have_setup) begin
        `uvm_error("SCB", red_mismatch($sformatf("APB setup at addr=0x%08h was not followed by enable", setup_obs.paddr)))
      end

      if (rsp_check_q.size() != 0) begin
        `uvm_error("SCB", red_mismatch($sformatf(
          "%0d pending AHB response checks were not observed", rsp_check_q.size())))
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("SCB", $sformatf(
        "Summary: ahb_valid=%0d ahb_invalid=%0d local_error=%0d apb_setup=%0d apb_enable=%0d apb_wait=%0d apb_error=%0d ahb_resp_checks=%0d hrdata_checks=%0d pending=%0d pending_rsp=%0d have_setup=%0b",
        ahb_valid_count, ahb_invalid_count, local_error_count, apb_setup_count,
        apb_enable_count, apb_wait_count, apb_error_count, ahb_response_check_count,
        hrdata_check_count, expected_q.size(), rsp_check_q.size(), have_setup), UVM_LOW)
    endfunction
  endclass

  class bridge_coverage extends uvm_component;
    `uvm_component_utils(bridge_coverage)

    uvm_analysis_imp_ahb #(ahb_item, bridge_coverage) ahb_export;
    uvm_analysis_imp_apb #(apb_item, bridge_coverage) apb_export;

    virtual ahb_if vif;

    bit       bus_hsel;
    bit       bus_hreadyin;
    bit [1:0] bus_htrans;

    bit       cov_hwrite;
    bit [1:0] cov_htrans;
    bit [2:0] cov_hsize;
    bit [2:0] cov_hburst;
    bit [3:0] cov_hprot;
    bit       cov_hmastlock;
    bit [2:0] cov_addr_region;
    bit [2:0] cov_pselx;
    bit       cov_pwrite;
    bit       cov_penable;
    bit       cov_pready;
    bit       cov_pslverr;
    bit [3:0] cov_pstrb;
    bit [2:0] cov_pprot;
    bit       cov_apb_phase;
    bit [1:0] cov_prev_rw;
    bit [1:0] cov_curr_rw;
    bit       cov_true_b2b;
    bit       cov_resp_boundary;
    bit       cov_prev_resp_error;
    bit [1:0] cov_next_kind;
    bit       b2b_outstanding;
    bit       b2b_outstanding_write;
    bit       strict_spec_coverage;
    bit       strict_pipeline_coverage;
    bit       error_boundary_only_coverage;

    bit seen_hwrite[2];
    bit seen_hsel[2];
    bit seen_htrans[4];
    bit seen_hsize[8];
    bit seen_hburst[8];
    bit seen_hprot[16];
    bit seen_hmastlock[2];
    bit seen_hreadyin[2];
    bit seen_addr_region[5];
    bit seen_boundary[8];
    bit seen_apb_phase[2];
    bit seen_apb_pwrite[2];
    bit seen_apb_pready[2];
    bit seen_apb_pslverr[2];
    bit seen_apb_pstrb[16];
    bit seen_apb_pprot[8];
    bit seen_apb_psel[3];
    bit seen_apb_pwrite_x_psel[2][3];
    bit seen_b2b[2][2];
    bit seen_error_boundary[4];
    bit seen_unsupported_selected;

    covergroup ahb_bus_cg;
      option.per_instance = 1;

      cp_bus_hsel: coverpoint bus_hsel {
        bins not_selected = {0};
        bins selected     = {1};
      }

      cp_bus_hreadyin: coverpoint bus_hreadyin {
        bins low  = {0};
        bins high = {1};
      }

      cp_bus_htrans: coverpoint bus_htrans {
        bins idle   = {2'b00};
        bins busy   = {2'b01};
        bins nonseq = {2'b10};
        bins seq    = {2'b11};
      }

      cross cp_bus_hsel, cp_bus_htrans;
      cross cp_bus_hreadyin, cp_bus_htrans;
    endgroup

    covergroup ahb_xfer_cg;
      option.per_instance = 1;

      cp_hwrite: coverpoint cov_hwrite {
        bins read  = {0};
        bins write = {1};
      }

      cp_xfer_htrans: coverpoint cov_htrans {
        bins nonseq = {2'b10};
        bins seq    = {2'b11};
      }

      cp_hsize: coverpoint cov_hsize {
        bins hsize_byte       = {3'b000};
        bins hsize_halfword   = {3'b001};
        bins hsize_word       = {3'b010};
        bins hsize_doubleword = {3'b011};
        bins hsize_line4      = {3'b100};
        bins hsize_line8      = {3'b101};
        bins hsize_line16     = {3'b110};
        bins hsize_line32     = {3'b111};
      }

      cp_hburst: coverpoint cov_hburst {
        bins single = {3'b000};
        bins incr   = {3'b001};
        bins wrap4  = {3'b010};
        bins incr4  = {3'b011};
        bins wrap8  = {3'b100};
        bins incr8  = {3'b101};
        bins wrap16 = {3'b110};
        bins incr16 = {3'b111};
      }

      cp_hprot: coverpoint cov_hprot {
        bins values[] = {[4'h0:4'hf]};
      }

      cp_hmastlock: coverpoint cov_hmastlock {
        bins unlocked = {0};
        bins locked   = {1};
      }

      cp_addr_region: coverpoint cov_addr_region {
        bins psel0        = {0};
        bins psel1        = {1};
        bins psel2        = {2};
        bins invalid_low  = {3};
        bins invalid_high = {4};
      }

      cross cp_hwrite, cp_addr_region;
      cross cp_hwrite, cp_xfer_htrans;
      cross cp_hsize, cp_xfer_htrans;
    endgroup

    covergroup ahb_pipeline_cg;
      option.per_instance = 1;

      cp_back_to_back: coverpoint {cov_prev_rw, cov_curr_rw} iff (cov_true_b2b) {
        bins rd_rd = {4'b0000};
        bins rd_wr = {4'b0001};
        bins wr_rd = {4'b0100};
        bins wr_wr = {4'b0101};
      }

      cp_response_boundary: coverpoint {cov_prev_resp_error, cov_next_kind} iff (cov_resp_boundary) {
        bins okay_next_read   = {3'b001};
        bins okay_next_write  = {3'b010};
        bins error_next_idle  = {3'b100};
        bins error_next_read  = {3'b101};
        bins error_next_write = {3'b110};
        bins error_next_bad   = {3'b111};
      }
    endgroup

    covergroup apb_cg;
      option.per_instance = 1;

      cp_pselx: coverpoint cov_pselx {
        bins psel0 = {3'b001};
        bins psel1 = {3'b010};
        bins psel2 = {3'b100};
        illegal_bins multi_hot = {3'b011, 3'b101, 3'b110, 3'b111};
      }

      cp_pwrite: coverpoint cov_pwrite {
        bins read  = {0};
        bins write = {1};
      }

      cp_penable: coverpoint cov_penable {
        bins setup_or_bad = {0};
        bins enable       = {1};
      }

      cp_pready: coverpoint cov_pready iff (cov_penable) {
        bins wait_state = {0};
        bins complete   = {1};
      }

      cp_pslverr: coverpoint cov_pslverr iff (cov_penable && cov_pready) {
        bins okay  = {0};
        bins error = {1};
      }

      cp_pstrb: coverpoint cov_pstrb {
        bins read_none = {4'b0000};
        bins byte0     = {4'b0001};
        bins byte1     = {4'b0010};
        bins byte2     = {4'b0100};
        bins byte3     = {4'b1000};
        bins half_low  = {4'b0011};
        bins half_high = {4'b1100};
        bins word      = {4'b1111};
        illegal_bins unsupported = {4'b0101, 4'b0110, 4'b0111, 4'b1001,
                                    4'b1010, 4'b1011, 4'b1101, 4'b1110};
      }

      cp_pprot: coverpoint cov_pprot {
        bins data_user  = {3'b000};
        bins data_priv  = {3'b001};
        bins instr_user = {3'b100};
        bins instr_priv = {3'b101};
        illegal_bins nonsecure_unmapped = {3'b010, 3'b011, 3'b110, 3'b111};
      }

      cp_phase: coverpoint cov_apb_phase {
        bins setup  = {0};
        bins enable = {1};
      }

      cross cp_pselx, cp_pwrite;
      cross cp_phase, cp_pwrite;
    endgroup

    function new(string name = "bridge_coverage", uvm_component parent = null);
      super.new(name, parent);
      ahb_export = new("ahb_export", this);
      apb_export = new("apb_export", this);
      ahb_bus_cg = new();
      ahb_xfer_cg = new();
      ahb_pipeline_cg = new();
      apb_cg = new();
      cov_prev_rw = 0;
      cov_curr_rw = 0;
      cov_true_b2b = 0;
      cov_resp_boundary = 0;
      cov_prev_resp_error = 0;
      cov_next_kind = 0;
      b2b_outstanding = 0;
      b2b_outstanding_write = 0;
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ahb_if was not set for bridge_coverage")
      end
      strict_spec_coverage = $test$plusargs("STRICT_SPEC_COVERAGE");
      strict_pipeline_coverage = $test$plusargs("STRICT_PIPELINE_COVERAGE");
      if (!uvm_config_db#(bit)::get(this, "", "error_boundary_only_coverage", error_boundary_only_coverage)) begin
        error_boundary_only_coverage = 1'b0;
      end
    endfunction

    task run_phase(uvm_phase phase);
      bit current_active_accept;
      bit current_header_ok;
      bit current_valid_accept;
      bit complete_ok;
      bit complete_any;
      bit error_boundary;

      forever begin
        @(posedge vif.Hclk);
        if (!vif.Hresetn) begin
          cov_true_b2b = 1'b0;
          cov_resp_boundary = 1'b0;
          b2b_outstanding = 1'b0;
          continue;
        end

        bus_hsel = vif.Hsel;
        bus_hreadyin = vif.Hreadyin;
        bus_htrans = vif.Htrans;
        cov_true_b2b = 1'b0;
        cov_resp_boundary = 1'b0;

        seen_hsel[bus_hsel] = 1'b1;
        seen_hreadyin[bus_hreadyin] = 1'b1;
        seen_htrans[bus_htrans] = 1'b1;

        ahb_bus_cg.sample();

        current_active_accept = vif.Hreadyout && vif.Hsel && vif.Hreadyin && vif.Htrans[1];
        current_header_ok = request_ok_from(vif.Haddr, vif.Hsize);
        current_valid_accept = current_active_accept && current_header_ok;
        complete_ok = b2b_outstanding && vif.Hreadyout && (vif.Hresp == 2'b00);
        complete_any = b2b_outstanding && vif.Hreadyout && (vif.Hresp inside {2'b00, 2'b01});
        error_boundary = vif.Hreadyout && (vif.Hresp == 2'b01);

        if (complete_ok && current_valid_accept) begin
          cov_prev_rw = {1'b0, b2b_outstanding_write};
          cov_curr_rw = {1'b0, vif.Hwrite};
          cov_true_b2b = 1'b1;
          cov_resp_boundary = 1'b1;
          cov_prev_resp_error = 1'b0;
          cov_next_kind = vif.Hwrite ? 2'd2 : 2'd1;
          seen_b2b[b2b_outstanding_write][vif.Hwrite] = 1'b1;
        end

        if (error_boundary) begin
          cov_resp_boundary = 1'b1;
          cov_prev_resp_error = 1'b1;
          if (!current_active_accept) begin
            cov_next_kind = 2'd0;
            seen_error_boundary[0] = 1'b1;
          end else if (current_header_ok) begin
            cov_next_kind = vif.Hwrite ? 2'd2 : 2'd1;
            if (vif.Hwrite) begin
              seen_error_boundary[2] = 1'b1;
            end else begin
              seen_error_boundary[1] = 1'b1;
            end
          end else begin
            cov_next_kind = 2'd3;
            seen_error_boundary[3] = 1'b1;
          end
        end

        if (complete_any) begin
          b2b_outstanding = 1'b0;
        end

        if (current_valid_accept) begin
          b2b_outstanding = 1'b1;
          b2b_outstanding_write = vif.Hwrite;
        end

        ahb_pipeline_cg.sample();
      end
    endtask

    function void write_ahb(ahb_item tr);
      cov_hwrite = tr.hwrite;
      cov_htrans = tr.htrans;
      cov_hsize = tr.hsize;
      cov_hburst = tr.hburst;
      cov_hprot = tr.hprot;
      cov_hmastlock = tr.hmastlock;
      cov_addr_region = get_addr_region(tr.haddr);

      if (tr.is_selected_transfer()) begin
        seen_hwrite[tr.hwrite] = 1'b1;
        seen_hsize[tr.hsize] = 1'b1;
        seen_hburst[tr.hburst] = 1'b1;
        seen_hprot[tr.hprot] = 1'b1;
        seen_hmastlock[tr.hmastlock] = 1'b1;
        seen_addr_region[cov_addr_region] = 1'b1;
        update_boundary_hits(tr.haddr);
        ahb_xfer_cg.sample();
      end

      if (tr.expected_error) begin
        seen_unsupported_selected = 1'b1;
      end

    endfunction

    function bit request_ok_from(bit [31:0] addr, bit [2:0] size);
      bit addr_mapped;
      bit size_supported;
      bit addr_aligned;

      addr_mapped = (addr >= 32'h8000_0000) && (addr < 32'h8c00_0000);
      size_supported = (size == 3'b000) || (size == 3'b001) || (size == 3'b010);
      addr_aligned = (size == 3'b000) ||
                     (size == 3'b001 && addr[0] == 1'b0) ||
                     (size == 3'b010 && addr[1:0] == 2'b00);
      return addr_mapped && size_supported && addr_aligned;
    endfunction

    function void write_apb(apb_item tr);
      cov_pselx = tr.pselx;
      cov_pwrite = tr.pwrite;
      cov_penable = tr.penable;
      cov_pready = tr.pready;
      cov_pslverr = tr.pslverr;
      cov_pstrb = tr.pstrb;
      cov_pprot = tr.pprot;
      cov_apb_phase = (tr.phase == APB_ENABLE);
      seen_apb_phase[cov_apb_phase] = 1'b1;
      seen_apb_pwrite[tr.pwrite] = 1'b1;
      seen_apb_pstrb[tr.pstrb] = 1'b1;
      seen_apb_pprot[tr.pprot] = 1'b1;

      if (tr.phase == APB_ENABLE) begin
        seen_apb_pready[tr.pready] = 1'b1;
        if (tr.pready) begin
          seen_apb_pslverr[tr.pslverr] = 1'b1;
        end
      end

      if (get_psel_index(tr.pselx) >= 0) begin
        seen_apb_psel[get_psel_index(tr.pselx)] = 1'b1;
        seen_apb_pwrite_x_psel[tr.pwrite][get_psel_index(tr.pselx)] = 1'b1;
      end

      apb_cg.sample();
    endfunction

    function int get_psel_index(bit [2:0] pselx);
      case (pselx)
        3'b001: return 0;
        3'b010: return 1;
        3'b100: return 2;
        default: return -1;
      endcase
    endfunction

    function void update_boundary_hits(bit [31:0] addr);
      case (addr)
        32'h7fff_fffc: seen_boundary[0] = 1'b1;
        32'h8000_0000: seen_boundary[1] = 1'b1;
        32'h83ff_fffc: seen_boundary[2] = 1'b1;
        32'h8400_0000: seen_boundary[3] = 1'b1;
        32'h87ff_fffc: seen_boundary[4] = 1'b1;
        32'h8800_0000: seen_boundary[5] = 1'b1;
        32'h8bff_fffc: seen_boundary[6] = 1'b1;
        32'h8c00_0000: seen_boundary[7] = 1'b1;
        default: ;
      endcase
    endfunction

    function bit [2:0] get_addr_region(bit [31:0] addr);
      if (addr >= 32'h8000_0000 && addr < 32'h8400_0000) begin
        return 3'd0;
      end else if (addr >= 32'h8400_0000 && addr < 32'h8800_0000) begin
        return 3'd1;
      end else if (addr >= 32'h8800_0000 && addr < 32'h8c00_0000) begin
        return 3'd2;
      end else if (addr < 32'h8000_0000) begin
        return 3'd3;
      end
      return 3'd4;
    endfunction

    function void report_phase(uvm_phase phase);
      real ahb_bus_cov;
      real ahb_xfer_cov;

      super.report_phase(phase);
      ahb_bus_cov = ahb_bus_cg.get_inst_coverage();
      ahb_xfer_cov = ahb_xfer_cg.get_inst_coverage();
      `uvm_info("COV", $sformatf("AHB bus coverage = %.2f%%", ahb_bus_cov), UVM_LOW)
      `uvm_info("COV", $sformatf("AHB accepted-transfer coverage = %.2f%%", ahb_xfer_cov), UVM_LOW)
      `uvm_info("COV", $sformatf("AHB aggregate coverage = %.2f%%", (ahb_bus_cov + ahb_xfer_cov) / 2.0), UVM_LOW)
      if (strict_pipeline_coverage) begin
        `uvm_info("COV", $sformatf("AHB response-boundary coverage = %.2f%%", ahb_pipeline_cg.get_inst_coverage()), UVM_LOW)
      end
      `uvm_info("COV", $sformatf("APB coverage = %.2f%%", apb_cg.get_inst_coverage()), UVM_LOW)
      report_spec_hits();
    endfunction

    function void check_spec_bin(string name, bit hit, ref int missing);
      if (!hit) begin
        missing++;
        if (strict_spec_coverage) begin
          `uvm_error("SPEC_MISS", $sformatf("Missing spec coverage bin: %s", name))
        end else begin
          `uvm_info("SPEC_MISS", $sformatf("Missing spec coverage bin: %s", name), UVM_LOW)
        end
      end
    endfunction

    function void report_spec_hits();
      int missing;

      missing = 0;

      if (error_boundary_only_coverage) begin
        check_spec_bin("response-boundary ERROR->idle", seen_error_boundary[0], missing);
        check_spec_bin("response-boundary ERROR->read", seen_error_boundary[1], missing);
        check_spec_bin("response-boundary ERROR->write", seen_error_boundary[2], missing);
        check_spec_bin("response-boundary ERROR->invalid", seen_error_boundary[3], missing);
        if (missing == 0) begin
          `uvm_info("SPEC_COV", "All tracked error-boundary coverage bins were hit in this run", UVM_LOW)
        end else begin
          `uvm_info("SPEC_COV", $sformatf("Tracked error-boundary coverage missing bins = %0d", missing), UVM_LOW)
        end
        return;
      end

      check_spec_bin("AHB read", seen_hwrite[0], missing);
      check_spec_bin("AHB write", seen_hwrite[1], missing);
      check_spec_bin("HSEL low", seen_hsel[0], missing);
      check_spec_bin("HSEL high", seen_hsel[1], missing);
      check_spec_bin("HTRANS IDLE", seen_htrans[0], missing);
      check_spec_bin("HTRANS BUSY", seen_htrans[1], missing);
      check_spec_bin("HTRANS NONSEQ", seen_htrans[2], missing);
      check_spec_bin("HTRANS SEQ", seen_htrans[3], missing);
      check_spec_bin("HSIZE byte", seen_hsize[0], missing);
      check_spec_bin("HSIZE halfword", seen_hsize[1], missing);
      check_spec_bin("HSIZE word", seen_hsize[2], missing);
      check_spec_bin("HSIZE doubleword", seen_hsize[3], missing);
      check_spec_bin("HSIZE line4", seen_hsize[4], missing);
      check_spec_bin("HSIZE line8", seen_hsize[5], missing);
      check_spec_bin("HSIZE line16", seen_hsize[6], missing);
      check_spec_bin("HSIZE line32", seen_hsize[7], missing);
      check_spec_bin("HBURST SINGLE", seen_hburst[0], missing);
      check_spec_bin("HBURST INCR", seen_hburst[1], missing);
      check_spec_bin("HBURST WRAP4", seen_hburst[2], missing);
      check_spec_bin("HBURST INCR4", seen_hburst[3], missing);
      check_spec_bin("HBURST WRAP8", seen_hburst[4], missing);
      check_spec_bin("HBURST INCR8", seen_hburst[5], missing);
      check_spec_bin("HBURST WRAP16", seen_hburst[6], missing);
      check_spec_bin("HBURST INCR16", seen_hburst[7], missing);
      check_spec_bin("HPROT 0", seen_hprot[0], missing);
      check_spec_bin("HPROT 1", seen_hprot[1], missing);
      check_spec_bin("HPROT 2", seen_hprot[2], missing);
      check_spec_bin("HPROT 3", seen_hprot[3], missing);
      check_spec_bin("HPROT 4", seen_hprot[4], missing);
      check_spec_bin("HPROT 5", seen_hprot[5], missing);
      check_spec_bin("HPROT 6", seen_hprot[6], missing);
      check_spec_bin("HPROT 7", seen_hprot[7], missing);
      check_spec_bin("HPROT 8", seen_hprot[8], missing);
      check_spec_bin("HPROT 9", seen_hprot[9], missing);
      check_spec_bin("HPROT A", seen_hprot[10], missing);
      check_spec_bin("HPROT B", seen_hprot[11], missing);
      check_spec_bin("HPROT C", seen_hprot[12], missing);
      check_spec_bin("HPROT D", seen_hprot[13], missing);
      check_spec_bin("HPROT E", seen_hprot[14], missing);
      check_spec_bin("HPROT F", seen_hprot[15], missing);
      check_spec_bin("HMASTLOCK low", seen_hmastlock[0], missing);
      check_spec_bin("HMASTLOCK high", seen_hmastlock[1], missing);
      check_spec_bin("HREADYIN low", seen_hreadyin[0], missing);
      check_spec_bin("HREADYIN high", seen_hreadyin[1], missing);
      check_spec_bin("unsupported selected AHB transfer", seen_unsupported_selected, missing);

      check_spec_bin("addr invalid_low", seen_addr_region[3], missing);
      check_spec_bin("addr psel0", seen_addr_region[0], missing);
      check_spec_bin("addr psel1", seen_addr_region[1], missing);
      check_spec_bin("addr psel2", seen_addr_region[2], missing);
      check_spec_bin("addr invalid_high", seen_addr_region[4], missing);

      check_spec_bin("APB setup phase", seen_apb_phase[0], missing);
      check_spec_bin("APB enable phase", seen_apb_phase[1], missing);
      check_spec_bin("APB read", seen_apb_pwrite[0], missing);
      check_spec_bin("APB write", seen_apb_pwrite[1], missing);
      check_spec_bin("APB psel0", seen_apb_psel[0], missing);
      check_spec_bin("APB psel1", seen_apb_psel[1], missing);
      check_spec_bin("APB psel2", seen_apb_psel[2], missing);
      check_spec_bin("APB PREADY wait", seen_apb_pready[0], missing);
      check_spec_bin("APB PREADY complete", seen_apb_pready[1], missing);
      check_spec_bin("APB PSLVERR okay", seen_apb_pslverr[0], missing);
      check_spec_bin("APB PSLVERR error", seen_apb_pslverr[1], missing);
      check_spec_bin("APB PSTRB read none", seen_apb_pstrb[4'b0000], missing);
      check_spec_bin("APB PSTRB byte lane 0", seen_apb_pstrb[4'b0001], missing);
      check_spec_bin("APB PSTRB byte lane 1", seen_apb_pstrb[4'b0010], missing);
      check_spec_bin("APB PSTRB byte lane 2", seen_apb_pstrb[4'b0100], missing);
      check_spec_bin("APB PSTRB byte lane 3", seen_apb_pstrb[4'b1000], missing);
      check_spec_bin("APB PSTRB halfword low", seen_apb_pstrb[4'b0011], missing);
      check_spec_bin("APB PSTRB halfword high", seen_apb_pstrb[4'b1100], missing);
      check_spec_bin("APB PSTRB word", seen_apb_pstrb[4'b1111], missing);
      check_spec_bin("APB PPROT data user", seen_apb_pprot[3'b000], missing);
      check_spec_bin("APB PPROT data privileged", seen_apb_pprot[3'b001], missing);
      check_spec_bin("APB PPROT instruction user", seen_apb_pprot[3'b100], missing);
      check_spec_bin("APB PPROT instruction privileged", seen_apb_pprot[3'b101], missing);

      check_spec_bin("APB read x psel0", seen_apb_pwrite_x_psel[0][0], missing);
      check_spec_bin("APB read x psel1", seen_apb_pwrite_x_psel[0][1], missing);
      check_spec_bin("APB read x psel2", seen_apb_pwrite_x_psel[0][2], missing);
      check_spec_bin("APB write x psel0", seen_apb_pwrite_x_psel[1][0], missing);
      check_spec_bin("APB write x psel1", seen_apb_pwrite_x_psel[1][1], missing);
      check_spec_bin("APB write x psel2", seen_apb_pwrite_x_psel[1][2], missing);

      if (strict_pipeline_coverage) begin
        check_spec_bin("response-boundary OKAY read->read", seen_b2b[0][0], missing);
        check_spec_bin("response-boundary OKAY read->write", seen_b2b[0][1], missing);
        check_spec_bin("response-boundary OKAY write->read", seen_b2b[1][0], missing);
        check_spec_bin("response-boundary OKAY write->write", seen_b2b[1][1], missing);
        check_spec_bin("response-boundary ERROR->idle", seen_error_boundary[0], missing);
        check_spec_bin("response-boundary ERROR->read", seen_error_boundary[1], missing);
        check_spec_bin("response-boundary ERROR->write", seen_error_boundary[2], missing);
        check_spec_bin("response-boundary ERROR->invalid", seen_error_boundary[3], missing);
      end

      check_spec_bin("boundary 0x7FFF_FFFC", seen_boundary[0], missing);
      check_spec_bin("boundary 0x8000_0000", seen_boundary[1], missing);
      check_spec_bin("boundary 0x83FF_FFFC", seen_boundary[2], missing);
      check_spec_bin("boundary 0x8400_0000", seen_boundary[3], missing);
      check_spec_bin("boundary 0x87FF_FFFC", seen_boundary[4], missing);
      check_spec_bin("boundary 0x8800_0000", seen_boundary[5], missing);
      check_spec_bin("boundary 0x8BFF_FFFC", seen_boundary[6], missing);
      check_spec_bin("boundary 0x8C00_0000", seen_boundary[7], missing);

      if (missing == 0) begin
        `uvm_info("SPEC_COV", "All tracked spec coverage bins were hit in this run", UVM_LOW)
      end else begin
        `uvm_info("SPEC_COV", $sformatf("Tracked spec coverage missing bins = %0d", missing), UVM_LOW)
      end
    endfunction
  endclass

  class bridge_env extends uvm_env;
    `uvm_component_utils(bridge_env)

    ahb_agent         ahb;
    apb_agent         apb;
    bridge_scoreboard scb;
    bridge_coverage   cov;
    bit               ahb_active_cfg;

    function new(string name = "bridge_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ahb = ahb_agent::type_id::create("ahb", this);
      apb = apb_agent::type_id::create("apb", this);
      scb = bridge_scoreboard::type_id::create("scb", this);
      cov = bridge_coverage::type_id::create("cov", this);
      if (!uvm_config_db#(bit)::get(this, "", "ahb_active", ahb_active_cfg)) begin
        ahb_active_cfg = 1'b1;
      end
      ahb.is_active = ahb_active_cfg ? UVM_ACTIVE : UVM_PASSIVE;
      apb.is_active = UVM_ACTIVE;
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      ahb.monitor.analysis_port.connect(scb.ahb_export);
      apb.monitor.analysis_port.connect(scb.apb_export);
      ahb.monitor.analysis_port.connect(cov.ahb_export);
      apb.monitor.analysis_port.connect(cov.apb_export);
    endfunction
  endclass

  class ahb_base_seq extends uvm_sequence #(ahb_item);
    `uvm_object_utils(ahb_base_seq)

    int unsigned num_items = 100;
    int unsigned max_items = 5000;

    function new(string name = "ahb_base_seq");
      super.new(name);
    endfunction

    function int addr_region_index(bit [31:0] addr);
      if (addr >= 32'h8000_0000 && addr < 32'h8400_0000) begin
        return 0;
      end else if (addr >= 32'h8400_0000 && addr < 32'h8800_0000) begin
        return 1;
      end else if (addr >= 32'h8800_0000 && addr < 32'h8c00_0000) begin
        return 2;
      end else if (addr < 32'h8000_0000) begin
        return 3;
      end
      return 4;
    endfunction

    function int boundary_index(bit [31:0] addr);
      case (addr)
        32'h7fff_fffc: return 0;
        32'h8000_0000: return 1;
        32'h83ff_fffc: return 2;
        32'h8400_0000: return 3;
        32'h87ff_fffc: return 4;
        32'h8800_0000: return 5;
        32'h8bff_fffc: return 6;
        32'h8c00_0000: return 7;
        default:       return -1;
      endcase
    endfunction
  endclass

  class ahb_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_random_seq)

    function new(string name = "ahb_random_seq");
      super.new(name);
    endfunction

    task body();
      ahb_item tr;

      repeat (num_items) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize()) begin
          `uvm_error("RAND", "Failed to randomize ahb_item")
        end
        finish_item(tr);
      end
    endtask
  endclass

  class ahb_spec_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_spec_random_seq)

    function new(string name = "ahb_spec_random_seq");
      super.new(name);
      num_items = 300;
    endfunction

    task body();
      ahb_item tr;
      int unsigned count;
      int missing;
      int i;
      int j;
      int region;
      int boundary;
      bit hit_unsupported_selected;
      bit hit_hwrite[2];
      bit hit_hsel[2];
      bit hit_htrans[4];
      bit hit_hsize[8];
      bit hit_hburst[8];
      bit hit_hprot[16];
      bit hit_hmastlock[2];
      bit hit_hreadyin[2];
      bit hit_addr_region[5];
      bit hit_boundary[8];
      bit hit_valid_region_rw[3][2];
      bit hit_valid_pstrb[16];
      bit hit_valid_pprot[8];

      count = 0;
      missing = 1;
      hit_unsupported_selected = 1'b0;

      for (i = 0; i < 2; i++) begin
        hit_hwrite[i] = 1'b0;
        hit_hsel[i] = 1'b0;
        hit_hreadyin[i] = 1'b0;
        hit_hmastlock[i] = 1'b0;
      end

      for (i = 0; i < 4; i++) begin
        hit_htrans[i] = 1'b0;
      end

      for (i = 0; i < 8; i++) begin
        hit_hsize[i] = 1'b0;
        hit_hburst[i] = 1'b0;
      end

      for (i = 0; i < 16; i++) begin
        hit_valid_pstrb[i] = 1'b0;
      end

      for (i = 0; i < 8; i++) begin
        hit_valid_pprot[i] = 1'b0;
      end

      for (i = 0; i < 16; i++) begin
        hit_hprot[i] = 1'b0;
      end

      for (i = 0; i < 5; i++) begin
        hit_addr_region[i] = 1'b0;
      end

      for (i = 0; i < 8; i++) begin
        hit_boundary[i] = 1'b0;
      end

      for (i = 0; i < 3; i++) begin
        for (j = 0; j < 2; j++) begin
          hit_valid_region_rw[i][j] = 1'b0;
        end
      end

      while ((count < num_items) || ((missing != 0) && (count < max_items))) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          hsel dist {0 := 10, 1 := 90};
          hwrite dist {0 := 50, 1 := 50};
          htrans dist {2'b00 := 10, 2'b01 := 10, 2'b10 := 40, 2'b11 := 40};
          hsize dist {
            3'b000 := 15,
            3'b001 := 15,
            3'b010 := 45,
            3'b011 := 5,
            3'b100 := 5,
            3'b101 := 4,
            3'b110 := 3,
            3'b111 := 3
          };
          hburst dist {
            3'b000 := 30,
            3'b001 := 20,
            3'b010 := 10,
            3'b011 := 10,
            3'b100 := 10,
            3'b101 := 8,
            3'b110 := 6,
            3'b111 := 6
          };
          haddr[1:0] dist {2'b00 := 40, 2'b01 := 20, 2'b10 := 20, 2'b11 := 20};
          hmastlock dist {0 := 95, 1 := 5};
          hreadyin_stall_cycles dist {0 := 85, [1:3] := 10, [4:10] := 5};
          addr_kind dist {
            ADDR_PSEL0        := 18,
            ADDR_PSEL1        := 18,
            ADDR_PSEL2        := 18,
            ADDR_INVALID_LOW  := 10,
            ADDR_INVALID_HIGH := 10,
            ADDR_BOUNDARY     := 26
          };
          pre_idle_cycles inside {[0:2]};
          post_idle_cycles inside {[0:2]};
          inject_reset_before == 1'b0;
          inject_reset_during == 1'b0;
        }) begin
          `uvm_error("RAND", "Failed to randomize spec-biased ahb_item")
        end
        finish_item(tr);

        hit_hsel[tr.hsel] = 1'b1;
        hit_htrans[tr.htrans] = 1'b1;
        hit_hreadyin[tr.hreadyin] = 1'b1;

        region = addr_region_index(tr.haddr);
        boundary = boundary_index(tr.haddr);

        if (tr.is_selected_transfer()) begin
          hit_hwrite[tr.hwrite] = 1'b1;
          hit_hsize[tr.hsize] = 1'b1;
          hit_hburst[tr.hburst] = 1'b1;
          hit_hprot[tr.hprot] = 1'b1;
          hit_hmastlock[tr.hmastlock] = 1'b1;
          hit_addr_region[region] = 1'b1;
          if (boundary >= 0) begin
            hit_boundary[boundary] = 1'b1;
          end
        end

        if (tr.is_valid_transfer()) begin
          if (region >= 0 && region < 3) begin
            hit_valid_region_rw[region][tr.hwrite] = 1'b1;
          end

          hit_valid_pstrb[tr.make_pstrb()] = 1'b1;
          hit_valid_pprot[tr.make_pprot()] = 1'b1;

        end else if (tr.is_unsupported_selected_transfer()) begin
          hit_unsupported_selected = 1'b1;
        end

        missing = 0;
        if (!hit_unsupported_selected) begin
          missing++;
        end
        for (i = 0; i < 2; i++) begin
          if (!hit_hwrite[i]) begin
            missing++;
          end
          if (!hit_hsel[i]) begin
            missing++;
          end
          if (!hit_hreadyin[i]) begin
            missing++;
          end
          if (!hit_hmastlock[i]) begin
            missing++;
          end
        end

        for (i = 0; i < 4; i++) begin
          if (!hit_htrans[i]) begin
            missing++;
          end
        end

        for (i = 0; i < 8; i++) begin
          if (!hit_hsize[i]) begin
            missing++;
          end
          if (!hit_hburst[i]) begin
            missing++;
          end
        end

        for (i = 0; i < 16; i++) begin
          if (!hit_hprot[i]) begin
            missing++;
          end
        end

        if (!hit_valid_pstrb[4'b0000]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b0001]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b0010]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b0100]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b1000]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b0011]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b1100]) begin
          missing++;
        end
        if (!hit_valid_pstrb[4'b1111]) begin
          missing++;
        end

        if (!hit_valid_pprot[3'b000]) begin
          missing++;
        end
        if (!hit_valid_pprot[3'b001]) begin
          missing++;
        end
        if (!hit_valid_pprot[3'b100]) begin
          missing++;
        end
        if (!hit_valid_pprot[3'b101]) begin
          missing++;
        end

        for (i = 0; i < 5; i++) begin
          if (!hit_addr_region[i]) begin
            missing++;
          end
        end

        for (i = 0; i < 8; i++) begin
          if (!hit_boundary[i]) begin
            missing++;
          end
        end

        for (i = 0; i < 3; i++) begin
          for (j = 0; j < 2; j++) begin
            if (!hit_valid_region_rw[i][j]) begin
              missing++;
            end
          end
        end

        count++;
      end

      if (missing != 0) begin
        `uvm_warning("RAND_COV", $sformatf(
          "Spec-random stimulus stopped with %0d unhit stimulus bins after %0d items",
          missing, count))
      end
    endtask
  endclass

  class ahb_invalid_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_invalid_random_seq)

    function new(string name = "ahb_invalid_random_seq");
      super.new(name);
    endfunction

    task body();
      ahb_item tr;

      repeat (num_items) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          addr_kind dist {
            ADDR_INVALID_LOW  := 35,
            ADDR_INVALID_HIGH := 35,
            ADDR_BOUNDARY     := 15,
            ADDR_PSEL0        := 5,
            ADDR_PSEL1        := 5,
            ADDR_PSEL2        := 5
          };
          htrans dist {2'b00 := 30, 2'b01 := 30, 2'b10 := 20, 2'b11 := 20};
          hreadyin_stall_cycles dist {0 := 60, [1:3] := 25, [4:10] := 15};
        }) begin
          `uvm_error("RAND", "Failed to randomize invalid-biased ahb_item")
        end
        finish_item(tr);
      end
    endtask
  endclass

  class ahb_boundary_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_boundary_random_seq)

    function new(string name = "ahb_boundary_random_seq");
      super.new(name);
    endfunction

    task body();
      ahb_item tr;
      bit seen_boundary[8];
      int unsigned count;
      int missing;
      int boundary;
      int i;

      count = 0;
      missing = 1;
      for (i = 0; i < 8; i++) begin
        seen_boundary[i] = 1'b0;
      end

      while ((count < num_items) || ((missing != 0) && (count < max_items))) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          addr_kind == ADDR_BOUNDARY;
          htrans dist {2'b00 := 5, 2'b01 := 5, 2'b10 := 45, 2'b11 := 45};
          hreadyin_stall_cycles dist {0 := 90, [1:3] := 7, [4:10] := 3};
        }) begin
          `uvm_error("RAND", "Failed to randomize boundary ahb_item")
        end
        finish_item(tr);

        boundary = boundary_index(tr.haddr);
        if (boundary >= 0) begin
          seen_boundary[boundary] = 1'b1;
        end

        missing = 0;
        for (i = 0; i < 8; i++) begin
          if (!seen_boundary[i]) begin
            missing++;
          end
        end

        count++;
      end

      if (missing != 0) begin
        `uvm_warning("RAND_COV", $sformatf(
          "Boundary-random stimulus stopped with %0d unhit boundary bins after %0d items",
          missing, count))
      end
    endtask
  endclass

  class ahb_pipeline_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_pipeline_random_seq)

    function new(string name = "ahb_pipeline_random_seq");
      super.new(name);
      num_items = 100;
    endfunction

    task body();
      ahb_item tr;

      repeat (num_items) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          hsel == 1'b1;
          hwrite dist {0 := 50, 1 := 50};
          htrans inside {2'b10, 2'b11};
          hsize == 3'b010;
          hreadyin == 1'b1;
          addr_kind dist {
            ADDR_PSEL0    := 28,
            ADDR_PSEL1    := 28,
            ADDR_PSEL2    := 28,
            ADDR_BOUNDARY := 16
          };
          pre_idle_cycles == 0;
          post_idle_cycles == 0;
          inject_reset_before == 1'b0;
          inject_reset_during == 1'b0;
        }) begin
          `uvm_error("RAND", "Failed to randomize pipeline-random ahb_item")
        end
        finish_item(tr);
      end
    endtask
  endclass

  class ahb_back_to_back_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_back_to_back_random_seq)

    function new(string name = "ahb_back_to_back_random_seq");
      super.new(name);
    endfunction

    task body();
      ahb_item tr;

      repeat (num_items) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          hsel == 1'b1;
          addr_kind dist {ADDR_PSEL0 := 30, ADDR_PSEL1 := 30, ADDR_PSEL2 := 30, ADDR_BOUNDARY := 10};
          htrans inside {2'b10, 2'b11};
          hsize == 3'b010;
          hreadyin == 1'b1;
          pre_idle_cycles == 0;
          post_idle_cycles == 0;
          inject_reset_before == 1'b0;
          inject_reset_during == 1'b0;
        }) begin
          `uvm_error("RAND", "Failed to randomize back-to-back ahb_item")
        end
        finish_item(tr);
      end
    endtask
  endclass

  class ahb_reset_random_seq extends ahb_base_seq;
    `uvm_object_utils(ahb_reset_random_seq)

    function new(string name = "ahb_reset_random_seq");
      super.new(name);
    endfunction

    task body();
      ahb_item tr;

      repeat (num_items) begin
        tr = ahb_item::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
          inject_reset_before dist {0 := 80, 1 := 20};
          inject_reset_during dist {0 := 90, 1 := 10};
          htrans dist {2'b00 := 5, 2'b01 := 5, 2'b10 := 45, 2'b11 := 45};
        }) begin
          `uvm_error("RAND", "Failed to randomize reset-biased ahb_item")
        end
        finish_item(tr);
      end
    endtask
  endclass

  class ahb_stress_random_seq extends ahb_spec_random_seq;
    `uvm_object_utils(ahb_stress_random_seq)

    function new(string name = "ahb_stress_random_seq");
      super.new(name);
      num_items = 1000;
    endfunction
  endclass

  class bridge_base_test extends uvm_test;
    `uvm_component_utils(bridge_base_test)

    bridge_env env;

    function new(string name = "bridge_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = bridge_env::type_id::create("env", this);
    endfunction

    task run_ahb_sequence(uvm_phase phase, ahb_base_seq seq, int unsigned default_items);
      int plusarg_items;
      int plusarg_max_items;

      phase.raise_objection(this);
      seq.num_items = default_items;
      if ($value$plusargs("NUM_ITEMS=%0d", plusarg_items)) begin
        seq.num_items = plusarg_items;
      end

      if ($value$plusargs("MAX_ITEMS=%0d", plusarg_max_items)) begin
        seq.max_items = plusarg_max_items;
      end

      `uvm_info("TEST", $sformatf(
        "Starting %s with num_items=%0d max_items=%0d",
        seq.get_type_name(), seq.num_items, seq.max_items), UVM_LOW)
      seq.start(env.ahb.sequencer);
      #(500ns);
      phase.drop_objection(this);
    endtask
  endclass

  class bridge_sanity_test extends bridge_base_test;
    `uvm_component_utils(bridge_sanity_test)

    function new(string name = "bridge_sanity_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_back_to_back_random_seq seq;
      seq = ahb_back_to_back_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 20);
    endtask
  endclass

  class bridge_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_random_test)

    function new(string name = "bridge_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_spec_random_seq seq;
      seq = ahb_spec_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 300);
    endtask
  endclass

  class bridge_ahb_apb4_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_ahb_apb4_random_test)

    function new(string name = "bridge_ahb_apb4_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_spec_random_seq seq;
      seq = ahb_spec_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 500);
    endtask
  endclass

  class bridge_amba_rev2_random_test extends bridge_ahb_apb4_random_test;
    `uvm_component_utils(bridge_amba_rev2_random_test)

    function new(string name = "bridge_amba_rev2_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
      super.start_of_simulation_phase(phase);
      `uvm_warning("TEST_ALIAS", "bridge_amba_rev2_random_test is a compatibility alias; use bridge_ahb_apb4_random_test for the supported AHB/APB4 subset")
    endfunction
  endclass

  class bridge_invalid_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_invalid_random_test)

    function new(string name = "bridge_invalid_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_invalid_random_seq seq;
      seq = ahb_invalid_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 100);
    endtask
  endclass

  class bridge_boundary_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_boundary_random_test)

    function new(string name = "bridge_boundary_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_boundary_random_seq seq;
      seq = ahb_boundary_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 100);
    endtask
  endclass

  class bridge_back_to_back_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_back_to_back_random_test)

    function new(string name = "bridge_back_to_back_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_back_to_back_random_seq seq;
      seq = ahb_back_to_back_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 100);
    endtask
  endclass

  class bridge_hreadyout_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_hreadyout_random_test)

    function new(string name = "bridge_hreadyout_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_spec_random_seq seq;
      seq = ahb_spec_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 200);
    endtask
  endclass

  class bridge_pipeline_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_pipeline_random_test)

    function new(string name = "bridge_pipeline_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      uvm_config_db#(bit)::set(this, "env.ahb.driver", "pipeline_driver_mode", 1'b1);
      super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_pipeline_random_seq seq;
      seq = ahb_pipeline_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 100);
    endtask
  endclass

  class bridge_error_boundary_test extends bridge_base_test;
    `uvm_component_utils(bridge_error_boundary_test)

    virtual ahb_if vif;

    function new(string name = "bridge_error_boundary_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      uvm_config_db#(bit)::set(this, "env", "ahb_active", 1'b0);
      uvm_config_db#(bit)::set(this, "env.cov", "error_boundary_only_coverage", 1'b1);
      uvm_config_db#(int)::set(this, "env.apb.slave_model", "max_wait_cycles", 0);
      uvm_config_db#(int)::set(this, "env.apb.slave_model", "err_percent", 100);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("NOVIF", "ahb_if was not set for bridge_error_boundary_test")
      end
    endfunction

    task init_bus();
      vif.Hresetn  <= 1'b0;
      vif.Hsel     <= 1'b0;
      vif.Hwrite   <= 1'b0;
      vif.Hreadyin <= 1'b1;
      vif.Htrans   <= 2'b00;
      vif.Hsize    <= 3'b010;
      vif.Hburst   <= 3'b000;
      vif.Hprot    <= 4'b0011;
      vif.Hmastlock <= 1'b0;
      vif.Haddr    <= 32'h0000_0000;
      vif.Hwdata   <= 32'h0000_0000;
    endtask

    task apply_reset(int unsigned cycles = 5);
      @(negedge vif.Hclk);
      init_bus();
      repeat (cycles) @(posedge vif.Hclk);
      @(negedge vif.Hclk);
      vif.Hresetn <= 1'b1;
      @(posedge vif.Hclk);
    endtask

    task drive_idle_negedge();
      @(negedge vif.Hclk);
      vif.drive_idle();
    endtask

    task wait_readyout();
      int unsigned guard;

      guard = 0;
      while (!((vif.Hreadyout === 1'b1) && (vif.Hresp === 2'b00)) && guard < 40) begin
        drive_idle_negedge();
        @(posedge vif.Hclk);
        guard++;
      end

      if (guard == 40) begin
        `uvm_error("ERR_BOUNDARY", "Timeout waiting for idle OKAY HREADYOUT")
      end
    endtask

    task drive_addr_negedge(
      bit        hsel,
      bit        hwrite,
      bit [1:0]  htrans,
      bit [2:0]  hsize,
      bit [2:0]  hburst,
      bit [31:0] haddr,
      bit [31:0] hwdata
    );
      @(negedge vif.Hclk);
      vif.Hsel     <= hsel;
      vif.Hwrite   <= hwrite;
      vif.Hreadyin <= 1'b1;
      vif.Htrans   <= htrans;
      vif.Hsize    <= hsize;
      vif.Hburst   <= hburst;
      vif.Hprot    <= 4'b0011;
      vif.Hmastlock <= 1'b0;
      vif.Haddr    <= haddr;
      vif.Hwdata   <= hwdata;
    endtask

    function bit request_ok_from(bit [31:0] addr, bit [2:0] size);
      bit addr_mapped;
      bit size_supported;
      bit addr_aligned;

      addr_mapped = (addr >= 32'h8000_0000) && (addr < 32'h8c00_0000);
      size_supported = (size == 3'b000) || (size == 3'b001) || (size == 3'b010);
      addr_aligned = (size == 3'b000) ||
                     (size == 3'b001 && addr[0] == 1'b0) ||
                     (size == 3'b010 && addr[1:0] == 2'b00);
      return addr_mapped && size_supported && addr_aligned;
    endfunction

    task drive_error_boundary(
      bit        has_next,
      bit        next_write,
      bit [31:0] next_addr,
      bit [1:0]  next_trans,
      bit [2:0]  next_hsize,
      bit [2:0]  next_hburst,
      bit [31:0] next_wdata
    );
      wait_readyout();

      drive_addr_negedge(1'b1, 1'b0, 2'b10, 3'b010, 3'b000, 32'h8c00_0000, 32'h0000_0000);
      @(posedge vif.Hclk); // Local error accepted, next state is ERROR_1.

      if (has_next) begin
        drive_addr_negedge(1'b1, next_write, next_trans, next_hsize, next_hburst, next_addr, 32'h0000_0000);
      end else begin
        drive_idle_negedge();
      end
      @(posedge vif.Hclk); // ERROR_1 holds the address phase, not accepted yet.
      @(posedge vif.Hclk); // ERROR_2 accepts the held valid transfer when present.

      if (has_next && next_write && request_ok_from(next_addr, next_hsize)) begin
        drive_addr_negedge(1'b0, 1'b0, 2'b00, 3'b010, 3'b000, 32'h0000_0000, next_wdata);
        @(posedge vif.Hclk); // Write data phase capture.
      end

      drive_idle_negedge();
      @(posedge vif.Hclk);
      wait_readyout();
    endtask

    task drive_apb_okay_prime();
      wait_readyout();
      drive_addr_negedge(1'b1, 1'b0, 2'b10, 3'b010, 3'b000, 32'h8000_0010, 32'h0000_0000);
      @(posedge vif.Hclk);
      drive_idle_negedge();
      @(posedge vif.Hclk);
      wait_readyout();
    endtask

    task wait_error1();
      int unsigned guard;

      guard = 0;
      while (!((vif.Hreadyout === 1'b0) && (vif.Hresp === 2'b01)) && guard < 80) begin
        drive_idle_negedge();
        @(posedge vif.Hclk);
        guard++;
      end

      if (guard == 80) begin
        `uvm_error("ERR_BOUNDARY", "Timeout waiting for first AHB ERROR response cycle")
      end
    endtask

    task drive_apb_error_boundary(
      bit        has_next,
      bit        next_write,
      bit [31:0] next_addr,
      bit [1:0]  next_trans,
      bit [2:0]  next_hsize,
      bit [2:0]  next_hburst,
      bit [31:0] next_wdata
    );
      wait_readyout();

      drive_addr_negedge(1'b1, 1'b0, 2'b10, 3'b010, 3'b000, 32'h8000_0020, 32'h0000_0000);
      @(posedge vif.Hclk); // Valid APB read accepted; APB slave model forces PSLVERR after the prime transfer.
      wait_error1();

      if (has_next) begin
        drive_addr_negedge(1'b1, next_write, next_trans, next_hsize, next_hburst, next_addr, 32'h0000_0000);
      end else begin
        drive_idle_negedge();
      end
      @(posedge vif.Hclk); // ERROR_1 holds the address phase, not accepted yet.
      @(posedge vif.Hclk); // ERROR_2 accepts the held valid transfer when present.

      if (has_next && next_write && request_ok_from(next_addr, next_hsize)) begin
        drive_addr_negedge(1'b0, 1'b0, 2'b00, 3'b010, 3'b000, 32'h0000_0000, next_wdata);
        @(posedge vif.Hclk); // Write data phase capture.
      end

      drive_idle_negedge();
      @(posedge vif.Hclk);
      wait_readyout();
    endtask

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      init_bus();
      apply_reset(5);

      drive_apb_okay_prime();

      drive_error_boundary(1'b0, 1'b0, 32'h0000_0000, 2'b00, 3'b010, 3'b000, 32'h0000_0000);
      drive_error_boundary(1'b1, 1'b0, 32'h8000_0000, 2'b10, 3'b010, 3'b000, 32'h0000_0000);
      drive_error_boundary(1'b1, 1'b1, 32'h8400_0000, 2'b10, 3'b010, 3'b000, 32'hcafe_0001);
      drive_error_boundary(1'b1, 1'b0, 32'h7fff_fffc, 2'b10, 3'b010, 3'b000, 32'h0000_0000);
      drive_error_boundary(1'b1, 1'b0, 32'h8800_0000, 2'b11, 3'b010, 3'b001, 32'h0000_0000);

      drive_apb_error_boundary(1'b0, 1'b0, 32'h0000_0000, 2'b00, 3'b010, 3'b000, 32'h0000_0000);
      drive_apb_error_boundary(1'b1, 1'b0, 32'h8000_0040, 2'b10, 3'b010, 3'b000, 32'h0000_0000);
      drive_apb_error_boundary(1'b1, 1'b1, 32'h8400_0040, 2'b10, 3'b010, 3'b000, 32'hcafe_0002);
      drive_apb_error_boundary(1'b1, 1'b0, 32'h8c00_0000, 2'b10, 3'b010, 3'b000, 32'h0000_0000);

      #(500ns);
      phase.drop_objection(this);
    endtask
  endclass

  class bridge_reset_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_reset_random_test)

    function new(string name = "bridge_reset_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_reset_random_seq seq;
      seq = ahb_reset_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 100);
    endtask
  endclass

  class bridge_stress_random_test extends bridge_base_test;
    `uvm_component_utils(bridge_stress_random_test)

    function new(string name = "bridge_stress_random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      ahb_stress_random_seq seq;
      seq = ahb_stress_random_seq::type_id::create("seq");
      run_ahb_sequence(phase, seq, 1000);
    endtask
  endclass
endpackage

module bridge_assertions(
  input logic        Hclk,
  input logic        Hresetn,
  input logic        Hsel,
  input logic        Hwrite,
  input logic        Hreadyin,
  input logic        Hreadyout,
  input logic [1:0]  Htrans,
  input logic [2:0]  Hsize,
  input logic [31:0] Haddr,
  input logic        Penable,
  input logic        Pwrite,
  input logic        Pready,
  input logic        Pslverr,
  input logic [2:0]  Pselx,
  input logic [31:0] Paddr,
  input logic [31:0] Pwdata,
  input logic [31:0] Prdata,
  input logic [3:0]  Pstrb,
  input logic [2:0]  Pprot,
  input logic [1:0]  Hresp,
  input logic [31:0] Hrdata
);
  bit enable_asserts;
  int unsigned liveness_limit;
  int unsigned wait_count;

  initial begin
    enable_asserts = !$test$plusargs("DISABLE_ASSERTS");
    liveness_limit = 16;
    void'($value$plusargs("APB_LIVENESS_LIMIT=%0d", liveness_limit));
  end

  function string red_assert(string msg);
    if ($test$plusargs("NO_COLOR_MISMATCH")) begin
      return {"MISMATCH: ", msg};
    end
    return $sformatf("%c[31mMISMATCH: %s%c[0m", 8'h1b, msg, 8'h1b);
  endfunction

  function bit request_ok_from(bit [31:0] addr, bit [2:0] size);
    bit addr_mapped;
    bit size_supported;
    bit addr_aligned;

      addr_mapped = (addr >= 32'h8000_0000) && (addr < 32'h8c00_0000);
    size_supported = (size == 3'b000) || (size == 3'b001) || (size == 3'b010);
    addr_aligned = (size == 3'b000) ||
                   (size == 3'b001 && addr[0] == 1'b0) ||
                   (size == 3'b010 && addr[1:0] == 2'b00);
    return addr_mapped && size_supported && addr_aligned;
  endfunction

  default clocking cb @(posedge Hclk);
  endclocking

  default disable iff (!Hresetn || !enable_asserts);

  ap_psel_onehot: assert property ($onehot0(Pselx))
    else $error("%s", red_assert($sformatf("Pselx is not one-hot0: %03b", Pselx)));

  ap_enable_has_select: assert property (Penable |-> (Pselx != 3'b000))
    else $error("%s", red_assert("Penable asserted without Pselx"));

  ap_setup_to_enable: assert property ((Pselx != 3'b000 && !Penable) |=> Penable)
    else $error("%s", red_assert("APB setup cycle was not followed by enable cycle"));

  ap_ctrl_stable_setup_to_enable: assert property (
    (Pselx != 3'b000 && !Penable) |=>
      ($stable(Paddr) && $stable(Pwrite) && $stable(Pselx) &&
       $stable(Pstrb) && $stable(Pprot))
  ) else $error("%s", red_assert("APB control changed from setup to enable"));

  ap_wdata_stable_setup_to_enable: assert property (
    (Pselx != 3'b000 && !Penable && Pwrite) |=> $stable(Pwdata)
  ) else $error("%s", red_assert("APB write data changed from setup to enable"));

  ap_ctrl_stable_during_wait: assert property (
    (Pselx != 3'b000 && Penable && !Pready) |=>
      (Pselx != 3'b000 && Penable && $stable(Paddr) && $stable(Pwrite) &&
       $stable(Pselx) && $stable(Pstrb) && $stable(Pprot))
  ) else $error("%s", red_assert("APB control changed while PREADY was low"));

  ap_wdata_stable_during_wait: assert property (
    (Pselx != 3'b000 && Penable && Pwrite && !Pready) |=> $stable(Pwdata)
  ) else $error("%s", red_assert("APB write data changed while PREADY was low"));

  ap_wait_stalls_ahb: assert property (
    (Pselx != 3'b000 && Penable && !Pready) |-> (!Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("APB wait state did not stall AHB with OKAY response"));

  ap_pslverr_only_at_completion: assert property (
    (Pselx != 3'b000 && Penable && Pslverr) |-> Pready
  ) else $error("%s", red_assert("PSLVERR asserted before final APB access cycle"));

  ap_pslverr_maps_to_ahb_error: assert property (
    (Pselx != 3'b000 && Penable && Pready && Pslverr) |=>
      (!Hreadyout && Hresp == 2'b01) ##1 (Hreadyout && Hresp == 2'b01)
  ) else $error("%s", red_assert("APB PSLVERR did not map to two-cycle AHB ERROR"));

  ap_pready_okay_completes_ahb: assert property (
    (Pselx != 3'b000 && Penable && Pready && !Pslverr) |=>
      (Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("APB OKAY completion did not complete AHB with OKAY"));

  ap_apb_final_waits_for_registered_response: assert property (
    (Pselx != 3'b000 && Penable && Pready) |-> (!Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("APB final cycle did not wait for registered AHB response"));

  ap_hrdata_captures_final_prdata: assert property (
    (Pselx != 3'b000 && Penable && Pready && !Pslverr && !Pwrite) |=>
      (Hrdata == $past(Prdata))
  ) else $error("%s", red_assert("HRDATA did not capture final APB PRDATA"));

  ap_read_pstrb_zero: assert property ((Pselx != 3'b000 && !Pwrite) |-> (Pstrb == 4'b0000))
    else $error("%s", red_assert($sformatf("Read transfer drove nonzero PSTRB=%04b", Pstrb)));

  ap_paddr_word_aligned: assert property ((Pselx != 3'b000) |-> (Paddr[1:0] == 2'b00))
    else $error("%s", red_assert($sformatf("APB PADDR is not word aligned: 0x%08h", Paddr)));

  ap_hresp_legal: assert property (Hresp inside {2'b00, 2'b01})
    else $error("%s", red_assert($sformatf("Hresp is not OKAY/ERROR: %02b", Hresp)));

  ap_error_two_cycle: assert property (
    (Hresp == 2'b01 && !Hreadyout) |=> (Hresp == 2'b01 && Hreadyout)
  ) else $error("%s", red_assert("AHB ERROR response is not two-cycle with final Hreadyout high"));

  ap_hrdata_zero_on_error: assert property (
    Hresp == 2'b01 |-> (Hrdata == 32'h0000_0000)
  ) else $error("%s", red_assert($sformatf("HRDATA was not zero during ERROR response: 0x%08h", Hrdata)));

  ap_error2_read_accepted: assert property (
    (Hreadyout && Hresp == 2'b01 && Hsel && Hreadyin && Htrans[1] &&
     request_ok_from(Haddr, Hsize) && !Hwrite) |=>
      (Pselx != 3'b000 && !Penable && !Pwrite)
  ) else $error("%s", red_assert("ERROR_2 read address phase was not followed by APB setup"));

  ap_error2_write_accepted: assert property (
    (Hreadyout && Hresp == 2'b01 && Hsel && Hreadyin && Htrans[1] &&
     request_ok_from(Haddr, Hsize) && Hwrite) |=>
      (Pselx == 3'b000 && !Penable && !Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("ERROR_2 write address phase was not followed by write-data wait"));

  ap_error2_bad_request: assert property (
    (Hreadyout && Hresp == 2'b01 && Hsel && Hreadyin && Htrans[1] &&
     !request_ok_from(Haddr, Hsize)) |=>
      (!Hreadyout && Hresp == 2'b01 && Pselx == 3'b000 && !Penable)
  ) else $error("%s", red_assert("ERROR_2 invalid address phase was not followed by ERROR_1"));

  ap_unsupported_selected_gets_error: assert property (
    (Hreadyout && Hsel && Hreadyin && Htrans[1] && !request_ok_from(Haddr, Hsize))
      |=> ((!Hreadyout && Hresp == 2'b01) ##1 (Hreadyout && Hresp == 2'b01))
  ) else $error("%s", red_assert("Unsupported selected AHB transfer did not return ERROR response"));

  always @(posedge Hclk) begin
    if (!Hresetn) begin
      wait_count <= 0;
      if (enable_asserts) begin
        if (Pselx !== 3'b000 || Penable !== 1'b0 || Hreadyout !== 1'b1 || Hresp !== 2'b00) begin
          $error("%s", red_assert($sformatf(
            "Reset outputs not idle: Pselx=%03b Penable=%0b Hreadyout=%0b Hresp=%02b",
            Pselx, Penable, Hreadyout, Hresp)));
        end
      end
    end else if (enable_asserts) begin
      if (Pselx != 3'b000 && Penable && !Pready) begin
        wait_count <= wait_count + 1;
        if (wait_count >= liveness_limit) begin
          $error("%s", red_assert($sformatf(
            "APB transfer exceeded liveness limit while PREADY was low: limit=%0d",
            liveness_limit)));
        end
      end else begin
        wait_count <= 0;
      end
    end
  end
endmodule

import uvm_pkg::*;
`include "uvm_macros.svh"
import bridge_uvm_pkg::*;

module tb_top;
  logic Hclk;
  string testname;

  ahb_if ahb_vif(Hclk);
  apb_if apb_vif(Hclk);

  assign apb_vif.Hresetn = ahb_vif.Hresetn;

  initial begin
    Hclk = 1'b0;
  end

  always #5 Hclk = ~Hclk;

  Bridge_Top dut(
    .Hclk      (Hclk),
    .Hresetn   (ahb_vif.Hresetn),
    .Pclken    (1'b1),
    .Hsel      (ahb_vif.Hsel),
    .Hwrite    (ahb_vif.Hwrite),
    .Hreadyin  (ahb_vif.Hreadyin),
    .Hreadyout (ahb_vif.Hreadyout),
    .Hsize     (ahb_vif.Hsize),
    .Hburst    (ahb_vif.Hburst),
    .Hprot     (ahb_vif.Hprot),
    .Hmastlock (ahb_vif.Hmastlock),
    .Hwdata    (ahb_vif.Hwdata),
    .Haddr     (ahb_vif.Haddr),
    .Htrans    (ahb_vif.Htrans),
    .Prdata    (apb_vif.Prdata),
    .Pready    (apb_vif.Pready),
    .Pslverr   (apb_vif.Pslverr),
    .Penable   (apb_vif.Penable),
    .Pwrite    (apb_vif.Pwrite),
    .Pselx     (apb_vif.Pselx),
    .Paddr     (apb_vif.Paddr),
    .Pwdata    (apb_vif.Pwdata),
    .Pstrb     (apb_vif.Pstrb),
    .Pprot     (apb_vif.Pprot),
    .Hresp     (ahb_vif.Hresp),
    .Hrdata    (ahb_vif.Hrdata)
  );

  bridge_assertions assertions(
    .Hclk      (Hclk),
    .Hresetn   (ahb_vif.Hresetn),
    .Hsel      (ahb_vif.Hsel),
    .Hwrite    (ahb_vif.Hwrite),
    .Hreadyin  (ahb_vif.Hreadyin),
    .Hreadyout (ahb_vif.Hreadyout),
    .Htrans    (ahb_vif.Htrans),
    .Hsize     (ahb_vif.Hsize),
    .Haddr     (ahb_vif.Haddr),
    .Penable   (apb_vif.Penable),
    .Pwrite    (apb_vif.Pwrite),
    .Pready    (apb_vif.Pready),
    .Pslverr   (apb_vif.Pslverr),
    .Pselx     (apb_vif.Pselx),
    .Paddr     (apb_vif.Paddr),
    .Pwdata    (apb_vif.Pwdata),
    .Prdata    (apb_vif.Prdata),
    .Pstrb     (apb_vif.Pstrb),
    .Pprot     (apb_vif.Pprot),
    .Hresp     (ahb_vif.Hresp),
    .Hrdata    (ahb_vif.Hrdata)
  );

  initial begin
    if ($test$plusargs("DUMP")) begin
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_top);
    end
  end

  initial begin
    uvm_config_db#(virtual ahb_if)::set(null, "*", "vif", ahb_vif);
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", apb_vif);

`ifndef BRIDGE_RTL_ASSERTIONS
    if (!$test$plusargs("ALLOW_NO_RTL_ASSERTIONS")) begin
      `uvm_fatal("RTL_ASSERTS_OFF", "BRIDGE_RTL_ASSERTIONS is not defined; compile with +define+BRIDGE_RTL_ASSERTIONS or pass +ALLOW_NO_RTL_ASSERTIONS only for non-signoff debug")
    end
`endif

    if ($value$plusargs("UVM_TESTNAME=%s", testname)) begin
      run_test();
    end else begin
      run_test("bridge_ahb_apb4_random_test");
    end
  end

  initial begin
    #1ms;
    `uvm_fatal("TIMEOUT", "Simulation timeout")
  end
endmodule
