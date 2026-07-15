class bridge_coverage extends uvm_component;
  `uvm_component_utils(bridge_coverage)

  uvm_analysis_imp_ahb #(ahb_item, bridge_coverage) ahb_export;
  uvm_analysis_imp_apb #(apb_item, bridge_coverage) apb_export;

  bit        cov_hwrite;
  bit [1:0]  cov_htrans;
  bit        cov_hreadyin;
  bit [2:0]  cov_addr_region;
  bit [2:0]  cov_pselx;
  bit        cov_pwrite;
  bit        cov_penable;
  bit        cov_apb_phase;
  bit [1:0]  cov_prev_rw;
  bit [1:0]  cov_curr_rw;
  bit        have_prev_valid;

  covergroup ahb_cg;
    option.per_instance = 1;

    cp_hwrite: coverpoint cov_hwrite {
      bins read  = {0};
      bins write = {1};
    }

    cp_htrans: coverpoint cov_htrans {
      bins idle   = {2'b00};
      bins busy   = {2'b01};
      bins nonseq = {2'b10};
      bins seq    = {2'b11};
    }

    cp_hreadyin: coverpoint cov_hreadyin {
      bins low  = {0};
      bins high = {1};
    }

    cp_addr_region: coverpoint cov_addr_region {
      bins psel0        = {0};
      bins psel1        = {1};
      bins psel2        = {2};
      bins invalid_low  = {3};
      bins invalid_high = {4};
    }

    cp_back_to_back: coverpoint {cov_prev_rw, cov_curr_rw} iff (have_prev_valid) {
      bins rd_rd = {4'b0000};
      bins rd_wr = {4'b0001};
      bins wr_rd = {4'b0100};
      bins wr_wr = {4'b0101};
    }

    cross cp_hwrite, cp_addr_region;
    cross cp_hwrite, cp_htrans;
    cross cp_hreadyin, cp_htrans;
  endgroup

  covergroup apb_cg;
    option.per_instance = 1;

    cp_pselx: coverpoint cov_pselx {
      bins none  = {3'b000};
      bins psel0 = {3'b001};
      bins psel1 = {3'b010};
      bins psel2 = {3'b100};
      illegal_bins multi_hot = {[3'b011:3'b111]} with (!$onehot0(item));
    }

    cp_pwrite: coverpoint cov_pwrite {
      bins read  = {0};
      bins write = {1};
    }

    cp_penable: coverpoint cov_penable {
      bins setup_or_bad = {0};
      bins enable       = {1};
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
    ahb_cg = new();
    apb_cg = new();
  endfunction

  function void write_ahb(ahb_item tr);
    cov_hwrite   = tr.hwrite;
    cov_htrans   = tr.htrans;
    cov_hreadyin = tr.hreadyin;
    cov_addr_region = get_addr_region(tr.haddr);

    if (tr.is_valid_transfer()) begin
      cov_prev_rw = cov_curr_rw;
      cov_curr_rw = {1'b0, tr.hwrite};
      have_prev_valid = 1'b1;
    end

    ahb_cg.sample();
  endfunction

  function void write_apb(apb_item tr);
    cov_pselx   = tr.pselx;
    cov_pwrite  = tr.pwrite;
    cov_penable = tr.penable;
    cov_apb_phase = (tr.phase == APB_ENABLE);
    apb_cg.sample();
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
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("AHB coverage = %.2f%%", ahb_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info("COV", $sformatf("APB coverage = %.2f%%", apb_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
