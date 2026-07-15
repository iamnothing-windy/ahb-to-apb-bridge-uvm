class apb_slave_model extends uvm_component;
  `uvm_component_utils(apb_slave_model)

  virtual apb_if vif;

  function new(string name = "apb_slave_model", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "apb_if was not set for apb_slave_model")
    end
  endfunction

  task run_phase(uvm_phase phase);
    vif.Prdata <= 32'h0000_0000;

    forever begin
      @(negedge vif.Pclk);
      if (!vif.Hresetn) begin
        vif.Prdata <= 32'h0000_0000;
      end else if (vif.Pselx != 3'b000 && vif.Pwrite == 1'b0) begin
        vif.Prdata <= $urandom();
      end
    end
  endtask
endclass
