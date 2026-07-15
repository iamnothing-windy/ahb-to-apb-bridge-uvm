module bridge_assertions(
  input logic        Hclk,
  input logic        Hresetn,
  input logic        Penable,
  input logic        Pwrite,
  input logic [2:0]  Pselx,
  input logic [31:0] Paddr,
  input logic [31:0] Pwdata,
  input logic [1:0]  Hresp
);
  bit enable_asserts;

  initial begin
    enable_asserts = !$test$plusargs("DISABLE_ASSERTS");
  end

  default clocking cb @(posedge Hclk);
  endclocking

  default disable iff (!Hresetn || !enable_asserts);

  ap_psel_onehot: assert property ($onehot0(Pselx))
    else $error("Pselx is not one-hot0: %03b", Pselx);

  ap_enable_has_select: assert property (Penable |-> (Pselx != 3'b000))
    else $error("Penable asserted without Pselx");

  ap_setup_to_enable: assert property ((Pselx != 3'b000 && !Penable) |=> Penable)
    else $error("APB setup cycle was not followed by enable cycle");

  ap_ctrl_stable_setup_to_enable: assert property (
    (Pselx != 3'b000 && !Penable) |=>
      ($stable(Paddr) && $stable(Pwrite) && $stable(Pselx))
  ) else $error("APB control changed from setup to enable");

  ap_wdata_stable_setup_to_enable: assert property (
    (Pselx != 3'b000 && !Penable && Pwrite) |=> $stable(Pwdata)
  ) else $error("APB write data changed from setup to enable");

  ap_hresp_okay: assert property (Hresp == 2'b00)
    else $error("Hresp is not OKAY: %02b", Hresp);
endmodule
