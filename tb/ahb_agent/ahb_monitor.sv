class ahb_monitor extends uvm_component;
  `uvm_component_utils(ahb_monitor)

  virtual ahb_if vif;
  uvm_analysis_port #(ahb_item) analysis_port;
  bit monitor_log;
  int unsigned monitor_log_count;
  int unsigned monitor_log_max;

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
    bit skip_next_cycle;

    forever begin
      @(posedge vif.Hclk);
      if (!vif.Hresetn) begin
        skip_next_cycle = 1'b0;
        continue;
      end

      if (skip_next_cycle) begin
        skip_next_cycle = 1'b0;
        continue;
      end

      if (vif.Hsel == 1'b0 && vif.Htrans == 2'b00 && vif.Haddr == 32'h0000_0000 &&
          vif.Hwrite == 1'b0 && vif.Hreadyin == 1'b1) begin
        continue;
      end

      if (vif.Htrans inside {2'b00, 2'b01, 2'b10, 2'b11}) begin
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

        if (vif.Hwrite && vif.Hreadyin && (vif.Htrans inside {2'b10, 2'b11})) begin
          @(posedge vif.Hclk);
          if (!vif.Hresetn) begin
            continue;
          end
          tr.hwdata = vif.Hwdata;
        end

        tr.expected_valid = tr.is_valid_transfer();
        tr.expected_pselx = tr.decode_pselx();

        if (monitor_log && monitor_log_count < monitor_log_max) begin
          `uvm_info("AHB_MON", $sformatf(
            "hsel=%0b hwrite=%0b htrans=%02b hsize=%03b hburst=%03b hprot=%04b hmastlock=%0b hreadyin=%0b haddr=0x%08h hwdata=0x%08h valid=%0b error=%0b exp_pselx=%03b",
            tr.hsel, tr.hwrite, tr.htrans, tr.hsize, tr.hburst, tr.hprot,
            tr.hmastlock, tr.hreadyin, tr.haddr, tr.hwdata,
            tr.expected_valid, tr.expected_error, tr.expected_pselx), UVM_NONE)
          monitor_log_count++;
        end

        analysis_port.write(tr);

        if (!(vif.Hwrite && vif.Hreadyin && (vif.Htrans inside {2'b10, 2'b11}))) begin
          skip_next_cycle = 1'b1;
        end
      end
    end
  endtask
endclass
