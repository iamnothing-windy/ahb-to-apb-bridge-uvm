class ahb_base_seq extends uvm_sequence #(ahb_item);
  `uvm_object_utils(ahb_base_seq)

  int unsigned num_items = 100;
  int unsigned max_items = 5000;

  function new(string name = "ahb_base_seq");
    super.new(name);
  endfunction

  function int boundary_index(bit [31:0] addr);
    case (addr)
      32'h7fff_fffc: return 0;
      32'h8000_0000: return 1;
      32'h83ff_fffc: return 2;
      32'h8400_0000: return 3;
      32'h87ff_fffc: return 4;
      32'h8800_0000: return 5;
      32'h8bff_fffc: return 6;
      32'h8c00_0000: return 7;
      default:       return -1;
    endcase
  endfunction
endclass
