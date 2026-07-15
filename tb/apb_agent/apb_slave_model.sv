class apb_slave_model extends uvm_component;
  `uvm_component_utils(apb_slave_model)

  virtual apb_if vif;
  int unsigned max_wait_cycles;
  int unsigned err_percent;

  function new(string name = "apb_slave_model", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    int cfg_value;

    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "apb_if was not set for apb_slave_model")
    end
    max_wait_cycles = 3;
    err_percent = 15;
    if (uvm_config_db#(int)::get(this, "", "max_wait_cycles", cfg_value)) begin
      max_wait_cycles = cfg_value;
    end
    if (uvm_config_db#(int)::get(this, "", "err_percent", cfg_value)) begin
      err_percent = cfg_value;
    end
    void'($value$plusargs("APB_MAX_WAIT=%0d", max_wait_cycles));
    void'($value$plusargs("APB_ERR_PERCENT=%0d", err_percent));
    if (err_percent > 100) begin
      err_percent = 100;
    end
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned wait_left;
    bit inject_error;
    bit [31:0] rsp_data;

    vif.Prdata <= 32'h0000_0000;
    vif.Pready <= 1'b1;
    vif.Pslverr <= 1'b0;
    wait_left = 0;
    inject_error = 1'b0;
    rsp_data = 32'h0000_0000;

    forever begin
      @(negedge vif.Pclk);
      if (!vif.Hresetn) begin
        vif.Prdata  <= 32'h0000_0000;
        vif.Pready  <= 1'b1;
        vif.Pslverr <= 1'b0;
        wait_left = 0;
        inject_error = 1'b0;
      end else if (vif.Pselx != 3'b000 && vif.Penable == 1'b0) begin
        wait_left = (max_wait_cycles == 0) ? 0 : $urandom_range(0, max_wait_cycles);
        inject_error = (err_percent != 0) && ($urandom_range(0, 99) < err_percent);
        rsp_data = {$urandom(), $urandom()} ^ vif.Paddr ^ {29'h0, vif.Pselx};
        vif.Prdata  <= rsp_data;
        vif.Pready  <= 1'b1;
        vif.Pslverr <= 1'b0;
      end else if (vif.Pselx != 3'b000 && vif.Penable == 1'b1) begin
        vif.Prdata <= rsp_data;
        if (wait_left != 0) begin
          vif.Pready  <= 1'b0;
          vif.Pslverr <= 1'b0;
          wait_left--;
        end else begin
          vif.Pready  <= 1'b1;
          vif.Pslverr <= inject_error;
        end
      end else if (vif.Pselx != 3'b000 && vif.Pwrite == 1'b0) begin
        vif.Prdata  <= rsp_data;
        vif.Pready  <= 1'b1;
        vif.Pslverr <= 1'b0;
      end else begin
        vif.Pready  <= 1'b1;
        vif.Pslverr <= 1'b0;
      end
    end
  endtask
endclass
