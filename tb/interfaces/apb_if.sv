interface apb_if(input logic Pclk);
  logic        Hresetn;
  logic        Penable;
  logic        Pwrite;
  logic        Pready;
  logic        Pslverr;
  logic [2:0]  Pselx;
  logic [31:0] Paddr;
  logic [31:0] Pwdata;
  logic [31:0] Prdata;
  logic [3:0]  Pstrb;
  logic [2:0]  Pprot;
endinterface
