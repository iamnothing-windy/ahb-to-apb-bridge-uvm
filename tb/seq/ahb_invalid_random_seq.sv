class ahb_invalid_random_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_invalid_random_seq)

  function new(string name = "ahb_invalid_random_seq");
    super.new(name);
  endfunction

  task body();
    ahb_item tr;

    repeat (num_items) begin
      tr = ahb_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
        addr_kind dist {
          ADDR_INVALID_LOW  := 35,
          ADDR_INVALID_HIGH := 35,
          ADDR_BOUNDARY     := 15,
          ADDR_PSEL0        := 5,
          ADDR_PSEL1        := 5,
          ADDR_PSEL2        := 5
        };
        htrans dist {2'b00 := 30, 2'b01 := 30, 2'b10 := 20, 2'b11 := 20};
        hreadyin dist {0 := 40, 1 := 60};
      }) begin
        `uvm_error("RAND", "Failed to randomize invalid-biased ahb_item")
      end
      finish_item(tr);
    end
  endtask
endclass
