interface apb_if(input logic Pclk);
  logic        Hresetn;
  logic        Penable;
  logic        Pwrite;
  logic [2:0]  Pselx;
  logic [31:0] Paddr;
  logic [31:0] Pwdata;
  logic [31:0] Prdata;
endinterface
