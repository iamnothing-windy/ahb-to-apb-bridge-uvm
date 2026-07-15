class bridge_env extends uvm_env;
  `uvm_component_utils(bridge_env)

  ahb_agent         ahb;
  apb_agent         apb;
  bridge_scoreboard scb;
  bridge_coverage   cov;

  function new(string name = "bridge_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ahb = ahb_agent::type_id::create("ahb", this);
    apb = apb_agent::type_id::create("apb", this);
    scb = bridge_scoreboard::type_id::create("scb", this);
    cov = bridge_coverage::type_id::create("cov", this);

    ahb.is_active = UVM_ACTIVE;
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
