class ahb_item extends uvm_sequence_item;
  rand bit        hsel;
  rand bit        hwrite;
  rand bit [1:0]  htrans;
  rand bit [2:0]  hsize;
  rand bit [2:0]  hburst;
  rand bit [3:0]  hprot;
  rand bit        hmastlock;
  bit             hreadyin;
  rand bit [31:0] haddr;
  rand bit [31:0] hwdata;
  rand int unsigned pre_idle_cycles;
  rand int unsigned post_idle_cycles;
  rand int unsigned hreadyin_stall_cycles;
  rand bit        inject_reset_before;
  rand bit        inject_reset_during;
  rand int unsigned reset_cycles;
  rand addr_kind_e addr_kind;

  bit        expected_valid;
  bit        expected_error;
  bit [2:0]  expected_pselx;

  `uvm_object_utils_begin(ahb_item)
    `uvm_field_int(hsel, UVM_ALL_ON)
    `uvm_field_int(hwrite, UVM_ALL_ON)
    `uvm_field_int(htrans, UVM_ALL_ON)
    `uvm_field_int(hsize, UVM_ALL_ON)
    `uvm_field_int(hburst, UVM_ALL_ON)
    `uvm_field_int(hprot, UVM_ALL_ON)
    `uvm_field_int(hmastlock, UVM_ALL_ON)
    `uvm_field_int(hreadyin, UVM_ALL_ON)
    `uvm_field_int(hreadyin_stall_cycles, UVM_ALL_ON)
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
    hsel dist {0 := 10, 1 := 90};
    hwrite dist {0 := 50, 1 := 50};
    htrans dist {2'b00 := 10, 2'b01 := 10, 2'b10 := 45, 2'b11 := 35};
    hsize dist {
      3'b000 := 5,
      3'b001 := 5,
      3'b010 := 70,
      3'b011 := 5,
      3'b100 := 5,
      3'b101 := 4,
      3'b110 := 3,
      3'b111 := 3
    };
    hburst dist {
      3'b000 := 30,
      3'b001 := 20,
      3'b010 := 10,
      3'b011 := 10,
      3'b100 := 10,
      3'b101 := 8,
      3'b110 := 6,
      3'b111 := 6
    };
    hprot dist {
      4'h0 := 5,  4'h1 := 5,  4'h2 := 5,  4'h3 := 25,
      4'h4 := 5,  4'h5 := 5,  4'h6 := 5,  4'h7 := 5,
      4'h8 := 5,  4'h9 := 5,  4'ha := 5,  4'hb := 5,
      4'hc := 5,  4'hd := 5,  4'he := 5,  4'hf := 5
    };
    hmastlock dist {0 := 95, 1 := 5};
    hreadyin dist {0 := 15, 1 := 85};
    hreadyin_stall_cycles dist {0 := 85, [1:3] := 10, [4:10] := 5};
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

  constraint c_alignment_dist {
    haddr[1:0] dist {2'b00 := 80, 2'b01 := 7, 2'b10 := 7, 2'b11 := 6};
  }

  function new(string name = "ahb_item");
    super.new(name);
  endfunction

  function bit is_supported_size();
    return hsize inside {3'b000, 3'b001, 3'b010};
  endfunction

  function bit is_aligned_transfer();
    if (hsize == 3'b000) begin
      return 1'b1;
    end else if (hsize == 3'b001) begin
      return (haddr[0] == 1'b0);
    end else if (hsize == 3'b010) begin
      return (haddr[1:0] == 2'b00);
    end
    return 1'b0;
  endfunction

  function bit is_valid_transfer();
    return hsel && hreadyin && (htrans inside {2'b10, 2'b11}) &&
           is_supported_size() && is_aligned_transfer() &&
           (haddr >= 32'h8000_0000) && (haddr < 32'h8c00_0000);
  endfunction

  function bit is_selected_transfer();
    return hsel && hreadyin && (htrans inside {2'b10, 2'b11});
  endfunction

  function bit is_unsupported_selected_transfer();
    return is_selected_transfer() && !is_valid_transfer();
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

  function bit [31:0] make_paddr();
    return {haddr[31:2], 2'b00};
  endfunction

  function bit [3:0] make_pstrb();
    if (!hwrite) begin
      return 4'b0000;
    end

    case (hsize)
      3'b000: begin
        case (haddr[1:0])
          2'b00: return 4'b0001;
          2'b01: return 4'b0010;
          2'b10: return 4'b0100;
          default: return 4'b1000;
        endcase
      end
      3'b001: begin
        case (haddr[1])
          1'b0: return 4'b0011;
          default: return 4'b1100;
        endcase
      end
      3'b010: return 4'b1111;
      default: return 4'b0000;
    endcase
  endfunction

  function bit [2:0] make_pprot();
    case (hprot[1:0])
      2'b00: return 3'b100;
      2'b01: return 3'b000;
      2'b10: return 3'b101;
      2'b11: return 3'b001;
    endcase
    return 3'b000;
  endfunction

  function void post_randomize();
    hreadyin = (hreadyin_stall_cycles == 0);
    expected_valid = is_valid_transfer();
    expected_error = is_unsupported_selected_transfer();
    expected_pselx = decode_pselx();
  endfunction
endclass
