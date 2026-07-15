`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import bridge_uvm_pkg::*;

module tb_top;
  logic Hclk;
  string testname;

  ahb_if ahb_vif(Hclk);
  apb_if apb_vif(Hclk);

  assign apb_vif.Hresetn = ahb_vif.Hresetn;

  initial begin
    Hclk = 1'b0;
  end

  always #5 Hclk = ~Hclk;

  Bridge_Top dut (
    .Hclk      (Hclk),
    .Hresetn   (ahb_vif.Hresetn),
    .Pclken    (1'b1),
    .Hsel      (ahb_vif.Hsel),
    .Hwrite    (ahb_vif.Hwrite),
    .Hreadyin  (ahb_vif.Hreadyin),
    .Hreadyout (ahb_vif.Hreadyout),
    .Hsize     (ahb_vif.Hsize),
    .Hburst    (ahb_vif.Hburst),
    .Hprot     (ahb_vif.Hprot),
    .Hmastlock (ahb_vif.Hmastlock),
    .Hwdata    (ahb_vif.Hwdata),
    .Haddr     (ahb_vif.Haddr),
    .Htrans    (ahb_vif.Htrans),
    .Prdata    (apb_vif.Prdata),
    .Pready    (apb_vif.Pready),
    .Pslverr   (apb_vif.Pslverr),
    .Penable   (apb_vif.Penable),
    .Pwrite    (apb_vif.Pwrite),
    .Pselx     (apb_vif.Pselx),
    .Paddr     (apb_vif.Paddr),
    .Pwdata    (apb_vif.Pwdata),
    .Pstrb     (apb_vif.Pstrb),
    .Pprot     (apb_vif.Pprot),
    .Hresp     (ahb_vif.Hresp),
    .Hrdata    (ahb_vif.Hrdata)
  );

  bridge_assertions assertions (
    .Hclk    (Hclk),
    .Hresetn (ahb_vif.Hresetn),
    .Hsel    (ahb_vif.Hsel),
    .Hwrite  (ahb_vif.Hwrite),
    .Hreadyin(ahb_vif.Hreadyin),
    .Hreadyout(ahb_vif.Hreadyout),
    .Htrans  (ahb_vif.Htrans),
    .Hsize   (ahb_vif.Hsize),
    .Haddr   (ahb_vif.Haddr),
    .Penable (apb_vif.Penable),
    .Pwrite  (apb_vif.Pwrite),
    .Pready  (apb_vif.Pready),
    .Pslverr (apb_vif.Pslverr),
    .Pselx   (apb_vif.Pselx),
    .Paddr   (apb_vif.Paddr),
    .Pwdata  (apb_vif.Pwdata),
    .Prdata  (apb_vif.Prdata),
    .Pstrb   (apb_vif.Pstrb),
    .Pprot   (apb_vif.Pprot),
    .Hresp   (ahb_vif.Hresp),
    .Hrdata  (ahb_vif.Hrdata)
  );

  initial begin
    uvm_config_db#(virtual ahb_if)::set(null, "*", "vif", ahb_vif);
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", apb_vif);

    if ($value$plusargs("UVM_TESTNAME=%s", testname)) begin
      run_test();
    end else begin
      run_test("bridge_ahb_apb4_random_test");
    end
  end

  initial begin
    #1ms;
    `uvm_fatal("TIMEOUT", "Simulation timeout")
  end
endmodule
