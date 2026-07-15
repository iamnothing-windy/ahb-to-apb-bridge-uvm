interface ahb_if(input logic Hclk);
  logic        Hresetn;
  logic        Hsel;
  logic        Hwrite;
  logic        Hreadyin;
  logic        Hreadyout;
  logic [31:0] Hwdata;
  logic [31:0] Haddr;
  logic [1:0]  Htrans;
  logic [2:0]  Hsize;
  logic [2:0]  Hburst;
  logic [3:0]  Hprot;
  logic        Hmastlock;
  logic [1:0]  Hresp;
  logic [31:0] Hrdata;

  task automatic drive_idle();
    Hsel      <= 1'b0;
    Hwrite    <= 1'b0;
    Hreadyin  <= 1'b1;
    Htrans    <= 2'b00;
    Hsize     <= 3'b010;
    Hburst    <= 3'b000;
    Hprot     <= 4'b0011;
    Hmastlock <= 1'b0;
    Haddr     <= 32'h0000_0000;
    Hwdata    <= 32'h0000_0000;
  endtask
endinterface
