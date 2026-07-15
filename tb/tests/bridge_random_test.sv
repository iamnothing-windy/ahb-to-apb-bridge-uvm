class bridge_random_test extends bridge_base_test;
  `uvm_component_utils(bridge_random_test)

  function new(string name = "bridge_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_random_seq seq;
    seq = ahb_random_seq::type_id::create("seq");
    run_ahb_sequence(phase, seq, 100);
  endtask
endclass
