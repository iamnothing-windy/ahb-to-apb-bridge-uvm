class apb_item extends uvm_sequence_item;
  apb_phase_e phase;
  bit        pwrite;
  bit        penable;
  bit [2:0]  pselx;
  bit [31:0] paddr;
  bit [31:0] pwdata;
  bit [31:0] prdata;

  `uvm_object_utils_begin(apb_item)
    `uvm_field_enum(apb_phase_e, phase, UVM_ALL_ON)
    `uvm_field_int(pwrite, UVM_ALL_ON)
    `uvm_field_int(penable, UVM_ALL_ON)
    `uvm_field_int(pselx, UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(paddr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pwdata, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(prdata, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "apb_item");
    super.new(name);
  endfunction
endclass
