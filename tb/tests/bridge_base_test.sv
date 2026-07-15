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
