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

  task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.Hresetn);
      if (expected_q.size() != 0 || have_setup) begin
        `uvm_info("SCB", $sformatf(
          "Reset observed, flushing %0d queued expected APB transfers, have_setup=%0b",
          expected_q.size(), have_setup), UVM_MEDIUM)
        expected_q.delete();
        have_setup = 1'b0;
        active_exp = null;
        setup_obs = null;
      end
    end
  endtask

  function void write_ahb(ahb_item tr);
    apb_item exp;

    if (!tr.is_valid_transfer()) begin
      ahb_invalid_count++;
      return;
    end

    ahb_valid_count++;
    exp = apb_item::type_id::create("exp", this);
    exp.phase   = APB_SETUP;
    exp.pwrite  = tr.hwrite;
    exp.penable = 1'b0;
    exp.pselx   = tr.decode_pselx();
    exp.paddr   = tr.haddr;
    exp.pwdata  = tr.hwdata;
    expected_q.push_back(exp);
  endfunction

  function void write_apb(apb_item got);
    apb_item exp;

    if (got.phase == APB_SETUP) begin
      apb_setup_count++;

      if (have_setup) begin
        `uvm_error("SCB", $sformatf(
          "New APB setup before previous enable: old_addr=0x%08h new_addr=0x%08h",
          setup_obs.paddr, got.paddr))
        have_setup = 1'b0;
        active_exp = null;
        setup_obs = null;
      end

      if (expected_q.size() == 0) begin
        `uvm_error("SCB", $sformatf(
          "Unexpected APB setup: pwrite=%0b pselx=%03b paddr=0x%08h pwdata=0x%08h",
          got.pwrite, got.pselx, got.paddr, got.pwdata))
        return;
      end

      exp = expected_q.pop_front();
      active_exp = exp;
      setup_obs = got;
      have_setup = 1'b1;

      if (got.penable !== 1'b0) begin
        `uvm_error("SCB", "APB setup observed with Penable not low")
      end

      if (got.pwrite !== exp.pwrite) begin
        `uvm_error("SCB", $sformatf("Setup PWRITE mismatch exp=%0b got=%0b", exp.pwrite, got.pwrite))
      end

      if (got.pselx !== exp.pselx) begin
        `uvm_error("SCB", $sformatf("Setup PSELX mismatch exp=%03b got=%03b addr=0x%08h", exp.pselx, got.pselx, exp.paddr))
      end

      if (got.paddr !== exp.paddr) begin
        `uvm_error("SCB", $sformatf("Setup PADDR mismatch exp=0x%08h got=0x%08h", exp.paddr, got.paddr))
      end

      if (exp.pwrite && got.pwdata !== exp.pwdata) begin
        `uvm_error("SCB", $sformatf("Setup PWDATA mismatch exp=0x%08h got=0x%08h", exp.pwdata, got.pwdata))
      end

      return;
    end

    apb_enable_count++;

    if (!have_setup) begin
      `uvm_error("SCB", $sformatf(
        "APB enable without prior setup: pwrite=%0b pselx=%03b paddr=0x%08h pwdata=0x%08h",
        got.pwrite, got.pselx, got.paddr, got.pwdata))
      return;
    end

    if (got.penable !== 1'b1) begin
      `uvm_error("SCB", "APB enable observed with Penable not high")
    end

    if (got.pwrite !== setup_obs.pwrite) begin
      `uvm_error("SCB", $sformatf("PWRITE changed setup->enable setup=%0b enable=%0b", setup_obs.pwrite, got.pwrite))
    end

    if (got.pselx !== setup_obs.pselx) begin
      `uvm_error("SCB", $sformatf("PSELX changed setup->enable setup=%03b enable=%03b", setup_obs.pselx, got.pselx))
    end

    if (got.paddr !== setup_obs.paddr) begin
      `uvm_error("SCB", $sformatf("PADDR changed setup->enable setup=0x%08h enable=0x%08h", setup_obs.paddr, got.paddr))
    end

    if (active_exp.pwrite && got.pwdata !== setup_obs.pwdata) begin
      `uvm_error("SCB", $sformatf("PWDATA changed setup->enable setup=0x%08h enable=0x%08h", setup_obs.pwdata, got.pwdata))
    end

    have_setup = 1'b0;
    active_exp = null;
    setup_obs = null;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (expected_q.size() != 0) begin
      `uvm_error("SCB", $sformatf("%0d expected APB transfers were not observed", expected_q.size()))
    end

    if (have_setup) begin
      `uvm_error("SCB", $sformatf("APB setup at addr=0x%08h was not followed by enable", setup_obs.paddr))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf(
      "Summary: ahb_valid=%0d ahb_invalid=%0d apb_setup=%0d apb_enable=%0d pending=%0d have_setup=%0b",
      ahb_valid_count, ahb_invalid_count, apb_setup_count, apb_enable_count,
      expected_q.size(), have_setup), UVM_LOW)
  endfunction
endclass
