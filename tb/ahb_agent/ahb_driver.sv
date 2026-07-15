class ahb_driver extends uvm_driver #(ahb_item);
  `uvm_component_utils(ahb_driver)

  virtual ahb_if vif;

  function new(string name = "ahb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "ahb_if was not set for ahb_driver")
    end
  endfunction

  task run_phase(uvm_phase phase);
    ahb_item tr;

    init_bus();
    apply_reset(5);

    forever begin
      seq_item_port.get_next_item(tr);
      drive_transfer(tr);
      seq_item_port.item_done();
    end
  endtask

  task init_bus();
    vif.Hresetn  <= 1'b0;
    vif.Hsel     <= 1'b0;
    vif.Hwrite   <= 1'b0;
    vif.Hreadyin <= 1'b1;
    vif.Htrans   <= 2'b00;
    vif.Hsize    <= 3'b010;
    vif.Hburst   <= 3'b000;
    vif.Hprot    <= 4'b0011;
    vif.Hmastlock <= 1'b0;
    vif.Haddr    <= 32'h0000_0000;
    vif.Hwdata   <= 32'h0000_0000;
  endtask

  task apply_reset(int unsigned cycles);
    @(negedge vif.Hclk);
    vif.Hresetn  <= 1'b0;
    vif.Hsel     <= 1'b0;
    vif.Hwrite   <= 1'b0;
    vif.Hreadyin <= 1'b1;
    vif.Htrans   <= 2'b00;
    vif.Hsize    <= 3'b010;
    vif.Hburst   <= 3'b000;
    vif.Hprot    <= 4'b0011;
    vif.Hmastlock <= 1'b0;
    vif.Haddr    <= 32'h0000_0000;
    vif.Hwdata   <= 32'h0000_0000;
    repeat (cycles) @(posedge vif.Hclk);
    @(negedge vif.Hclk);
    vif.Hresetn <= 1'b1;
    @(posedge vif.Hclk);
  endtask

  task drive_idle_cycle();
    @(negedge vif.Hclk);
    vif.drive_idle();
    @(posedge vif.Hclk);
  endtask

  task wait_readyout();
    int unsigned guard;

    guard = 0;
    while (vif.Hreadyout !== 1'b1 && guard < 20) begin
      drive_idle_cycle();
      guard++;
    end

    if (guard == 20) begin
      `uvm_error("AHB_DRV", "Timeout waiting for Hreadyout")
    end
  endtask

  task drive_addr_controls(ahb_item tr, bit hreadyin_value);
    vif.Hsel      <= tr.hsel;
    vif.Hwrite    <= tr.hwrite;
    vif.Hreadyin  <= hreadyin_value;
    vif.Htrans    <= tr.htrans;
    vif.Hsize     <= tr.hsize;
    vif.Hburst    <= tr.hburst;
    vif.Hprot     <= tr.hprot;
    vif.Hmastlock <= tr.hmastlock;
    vif.Haddr     <= tr.haddr;
    vif.Hwdata    <= 32'h0000_0000;
  endtask

  task hold_addr_until_ready(ahb_item tr);
    int unsigned low_cycles_seen;

    if (tr.hreadyin_stall_cycles == 0) begin
      return;
    end

    low_cycles_seen = 1;
    while (low_cycles_seen < tr.hreadyin_stall_cycles) begin
      @(negedge vif.Hclk);
      drive_addr_controls(tr, 1'b0);
      @(posedge vif.Hclk);
      low_cycles_seen++;
    end

    @(negedge vif.Hclk);
    drive_addr_controls(tr, 1'b1);
    @(posedge vif.Hclk);
  endtask

  task drive_transfer(ahb_item tr);
    if (tr.inject_reset_before) begin
      apply_reset(tr.reset_cycles);
    end

    repeat (tr.pre_idle_cycles) begin
      drive_idle_cycle();
    end

    @(negedge vif.Hclk);
    drive_addr_controls(tr, (tr.hreadyin_stall_cycles == 0));
    @(posedge vif.Hclk);

    hold_addr_until_ready(tr);

    if (tr.inject_reset_during) begin
      apply_reset(tr.reset_cycles);
      return;
    end

    @(negedge vif.Hclk);
    vif.Hsel     <= tr.hsel;
    vif.Hwrite   <= tr.hwrite;
    vif.Hreadyin <= 1'b1;
    vif.Htrans   <= 2'b00;
    vif.Hsize    <= tr.hsize;
    vif.Hburst   <= tr.hburst;
    vif.Hprot    <= tr.hprot;
    vif.Hmastlock <= tr.hmastlock;
    vif.Haddr    <= tr.haddr;
    vif.Hwdata   <= tr.hwdata;
    @(posedge vif.Hclk);

    @(negedge vif.Hclk);
    vif.drive_idle();
    @(posedge vif.Hclk);

    wait_readyout();

    repeat (tr.post_idle_cycles) begin
      drive_idle_cycle();
    end
  endtask
endclass
