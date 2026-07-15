class ahb_boundary_random_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_boundary_random_seq)

  function new(string name = "ahb_boundary_random_seq");
    super.new(name);
  endfunction

  task body();
    ahb_item tr;
    bit seen_boundary[8];
    int unsigned count;
    int missing;
    int boundary;
    int i;

    count = 0;
    missing = 1;
    for (i = 0; i < 8; i++) begin
      seen_boundary[i] = 1'b0;
    end

    while ((count < num_items) || ((missing != 0) && (count < max_items))) begin
      tr = ahb_item::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
        addr_kind == ADDR_BOUNDARY;
        htrans dist {2'b00 := 5, 2'b01 := 5, 2'b10 := 45, 2'b11 := 45};
        hreadyin dist {0 := 10, 1 := 90};
      }) begin
        `uvm_error("RAND", "Failed to randomize boundary ahb_item")
      end
      finish_item(tr);

      boundary = boundary_index(tr.haddr);
      if (boundary >= 0) begin
        seen_boundary[boundary] = 1'b1;
      end

      missing = 0;
      for (i = 0; i < 8; i++) begin
        if (!seen_boundary[i]) begin
          missing++;
        end
      end

      count++;
    end

    if (missing != 0) begin
      `uvm_warning("RAND_COV", $sformatf(
        "Boundary-random stimulus stopped with %0d unhit boundary bins after %0d items",
        missing, count))
    end
  endtask
endclass
