class ahb_stress_random_seq extends ahb_random_seq;
  `uvm_object_utils(ahb_stress_random_seq)

  function new(string name = "ahb_stress_random_seq");
    super.new(name);
    num_items = 1000;
  endfunction
endclass
