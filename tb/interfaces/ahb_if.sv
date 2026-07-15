interface ahb_if(input logic Hclk);
  logic        Hresetn;
  logic        Hwrite;
  logic        Hreadyin;
  logic        Hreadyout;
  logic [31:0] Hwdata;
  logic [31:0] Haddr;
  logic [1:0]  Htrans;
  logic [1:0]  Hresp;
  logic [31:0] Hrdata;

  task automatic drive_idle();
    Hwrite   <= 1'b0;
    Hreadyin <= 1'b1;
    Htrans   <= 2'b00;
    Haddr    <= 32'h0000_0000;
    Hwdata   <= 32'h0000_0000;
  endtask
endinterface
