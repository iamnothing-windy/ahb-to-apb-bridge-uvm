class ahb_reset_random_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_reset_random_seq)

  function new(string name = "ahb_reset_random_seq");
    super.new(name);
  endfunction

  task body();
    ahb_item tr;

    repeat (num_items) begin
      tr = ahb_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
        inject_reset_before dist {0 := 80, 1 := 20};
        inject_reset_during dist {0 := 90, 1 := 10};
        htrans dist {2'b00 := 5, 2'b01 := 5, 2'b10 := 45, 2'b11 := 45};
      }) begin
        `uvm_error("RAND", "Failed to randomize reset-biased ahb_item")
      end
      finish_item(tr);
    end
  endtask
endclass
