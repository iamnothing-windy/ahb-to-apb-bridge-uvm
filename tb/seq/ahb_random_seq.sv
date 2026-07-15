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
