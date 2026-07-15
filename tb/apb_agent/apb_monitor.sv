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
        tr.pselx   = vif.Pselx;
        tr.paddr   = vif.Paddr;
        tr.pwdata  = vif.Pwdata;
        tr.prdata  = vif.Prdata;

        if (monitor_log && monitor_log_count < monitor_log_max) begin
          `uvm_info("APB_MON", $sformatf(
            "phase=%s pwrite=%0b pselx=%03b penable=%0b paddr=0x%08h pwdata=0x%08h prdata=0x%08h",
            tr.phase.name(), tr.pwrite, tr.pselx, tr.penable,
            tr.paddr, tr.pwdata, tr.prdata), UVM_NONE)
          monitor_log_count++;
        end

        analysis_port.write(tr);
      end
    end
  endtask
endclass
