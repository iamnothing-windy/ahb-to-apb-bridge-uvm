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
