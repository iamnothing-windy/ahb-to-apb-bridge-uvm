class ahb_item extends uvm_sequence_item;
  rand bit        hwrite;
  rand bit [1:0]  htrans;
  rand bit        hreadyin;
  rand bit [31:0] haddr;
  rand bit [31:0] hwdata;
  rand int unsigned pre_idle_cycles;
  rand int unsigned post_idle_cycles;
  rand bit        inject_reset_before;
  rand bit        inject_reset_during;
  rand int unsigned reset_cycles;
  rand addr_kind_e addr_kind;

  bit        expected_valid;
  bit [2:0]  expected_pselx;

  `uvm_object_utils_begin(ahb_item)
    `uvm_field_int(hwrite, UVM_ALL_ON)
    `uvm_field_int(htrans, UVM_ALL_ON)
    `uvm_field_int(hreadyin, UVM_ALL_ON)
    `uvm_field_int(haddr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(hwdata, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pre_idle_cycles, UVM_ALL_ON)
    `uvm_field_int(post_idle_cycles, UVM_ALL_ON)
    `uvm_field_int(inject_reset_before, UVM_ALL_ON)
    `uvm_field_int(inject_reset_during, UVM_ALL_ON)
    `uvm_field_int(reset_cycles, UVM_ALL_ON)
    `uvm_field_enum(addr_kind_e, addr_kind, UVM_ALL_ON)
  `uvm_object_utils_end

  constraint c_default_dist {
    hwrite dist {0 := 50, 1 := 50};
    htrans dist {2'b00 := 10, 2'b01 := 10, 2'b10 := 45, 2'b11 := 35};
    hreadyin dist {0 := 15, 1 := 85};
    addr_kind dist {
      ADDR_PSEL0        := 22,
      ADDR_PSEL1        := 22,
      ADDR_PSEL2        := 22,
      ADDR_INVALID_LOW  := 12,
      ADDR_INVALID_HIGH := 12,
      ADDR_BOUNDARY     := 10
    };
    soft inject_reset_before == 1'b0;
    soft inject_reset_during == 1'b0;
  }

  constraint c_addr {
    if (addr_kind == ADDR_PSEL0) {
      haddr inside {[32'h8000_0000:32'h83ff_ffff]};
    } else if (addr_kind == ADDR_PSEL1) {
      haddr inside {[32'h8400_0000:32'h87ff_ffff]};
    } else if (addr_kind == ADDR_PSEL2) {
      haddr inside {[32'h8800_0000:32'h8bff_ffff]};
    } else if (addr_kind == ADDR_INVALID_LOW) {
      haddr < 32'h8000_0000;
    } else if (addr_kind == ADDR_INVALID_HIGH) {
      haddr >= 32'h8c00_0000;
    } else {
      haddr inside {
        32'h7fff_fffc,
        32'h8000_0000,
        32'h83ff_fffc,
        32'h8400_0000,
        32'h87ff_fffc,
        32'h8800_0000,
        32'h8bff_fffc,
        32'h8c00_0000
      };
    }
  }

  constraint c_timing {
    pre_idle_cycles inside {[0:3]};
    post_idle_cycles inside {[0:3]};
    reset_cycles inside {[2:5]};
  }

  function new(string name = "ahb_item");
    super.new(name);
  endfunction

  function bit is_valid_transfer();
    return hreadyin && (htrans inside {2'b10, 2'b11}) &&
           (haddr >= 32'h8000_0000) && (haddr < 32'h8c00_0000);
  endfunction

  function bit [2:0] decode_pselx();
    if (haddr >= 32'h8000_0000 && haddr < 32'h8400_0000) begin
      return 3'b001;
    end else if (haddr >= 32'h8400_0000 && haddr < 32'h8800_0000) begin
      return 3'b010;
    end else if (haddr >= 32'h8800_0000 && haddr < 32'h8c00_0000) begin
      return 3'b100;
    end
    return 3'b000;
  endfunction

  function void post_randomize();
    expected_valid = is_valid_transfer();
    expected_pselx = decode_pselx();
  endfunction
endclass
