class ahb_back_to_back_random_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_back_to_back_random_seq)

  function new(string name = "ahb_back_to_back_random_seq");
    super.new(name);
  endfunction

  task body();
    ahb_item tr;

    repeat (num_items) begin
      tr = ahb_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
        addr_kind dist {ADDR_PSEL0 := 30, ADDR_PSEL1 := 30, ADDR_PSEL2 := 30, ADDR_BOUNDARY := 10};
        htrans inside {2'b10, 2'b11};
        hreadyin == 1'b1;
        pre_idle_cycles == 0;
        post_idle_cycles == 0;
        inject_reset_before == 1'b0;
        inject_reset_during == 1'b0;
      }) begin
        `uvm_error("RAND", "Failed to randomize back-to-back ahb_item")
      end
      finish_item(tr);
    end
  endtask
endclass
