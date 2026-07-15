`timescale 1ns/1ps
`default_nettype none

module bridge_fmax_core_top (
  input  wire logic       clk,
  input  wire logic       reset_n,
  output      logic [7:0] led
);
  logic [31:0] lfsr;
  logic        hresetn;

  logic        hsel;
  logic        hwrite;
  logic        hreadyin;
  logic        hreadyout;
  logic [2:0]  hsize;
  logic [2:0]  hburst;
  logic [3:0]  hprot;
  logic        hmastlock;
  logic [31:0] hwdata;
  logic [31:0] haddr;
  logic [1:0]  htrans;
  logic [1:0]  hresp;
  logic [31:0] hrdata;

  logic        penable;
  logic        pwrite;
  logic        pready;
  logic        pslverr;
  logic [2:0]  pselx;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic [3:0]  pstrb;
  logic [2:0]  pprot;

  logic [7:0]  status_accum;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      lfsr <= 32'h1ace_b00c;
      hresetn <= 1'b0;
      status_accum <= 8'h00;
      led <= 8'h00;
    end else begin
      lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
      hresetn <= 1'b1;
      status_accum <= status_accum ^ {hresp, hreadyout, penable, pwrite, pselx[2:0]};
      led <= status_accum ^ hrdata[7:0] ^ paddr[7:0] ^ pwdata[7:0] ^ {pstrb, pprot, pready};
    end
  end

  always_comb begin
    hsel = 1'b1;
    hwrite = lfsr[2];
    hreadyin = 1'b1;
    hsize = lfsr[4] ? 3'b001 : (lfsr[3] ? 3'b000 : 3'b010);
    hburst = lfsr[7:5];
    hprot = {lfsr[11:10], lfsr[1], lfsr[0]};
    hmastlock = lfsr[12];
    hwdata = lfsr ^ 32'ha5a5_5a5a;
    haddr = 32'h8000_0000 | {2'b00, lfsr[25:0], 2'b00};
    htrans = lfsr[6] ? 2'b11 : 2'b10;

    pready = !lfsr[13];
    pslverr = penable && pready && lfsr[17] && paddr[4];
    prdata = paddr ^ pwdata ^ {24'h0, status_accum};
  end

  Bridge_Top #(
    .USE_PCLKEN (1'b0)
  ) dut (
    .Hclk      (clk),
    .Hresetn   (hresetn),
    .Pclken    (1'b1),
    .Hsel      (hsel),
    .Hwrite    (hwrite),
    .Hreadyin  (hreadyin),
    .Hreadyout (hreadyout),
    .Hsize     (hsize),
    .Hburst    (hburst),
    .Hprot     (hprot),
    .Hmastlock (hmastlock),
    .Hwdata    (hwdata),
    .Haddr     (haddr),
    .Htrans    (htrans),
    .Prdata    (prdata),
    .Pready    (pready),
    .Pslverr   (pslverr),
    .Penable   (penable),
    .Pwrite    (pwrite),
    .Pselx     (pselx),
    .Paddr     (paddr),
    .Pwdata    (pwdata),
    .Pstrb     (pstrb),
    .Pprot     (pprot),
    .Hresp     (hresp),
    .Hrdata    (hrdata)
  );
endmodule

`default_nettype wire
