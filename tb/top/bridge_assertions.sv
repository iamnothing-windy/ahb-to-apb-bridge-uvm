module bridge_assertions(
  input logic        Hclk,
  input logic        Hresetn,
  input logic        Hsel,
  input logic        Hwrite,
  input logic        Hreadyin,
  input logic        Hreadyout,
  input logic [1:0]  Htrans,
  input logic [2:0]  Hsize,
  input logic [31:0] Haddr,
  input logic        Penable,
  input logic        Pwrite,
  input logic        Pready,
  input logic        Pslverr,
  input logic [2:0]  Pselx,
  input logic [31:0] Paddr,
  input logic [31:0] Pwdata,
  input logic [31:0] Prdata,
  input logic [3:0]  Pstrb,
  input logic [2:0]  Pprot,
  input logic [1:0]  Hresp,
  input logic [31:0] Hrdata
);
  bit enable_asserts;
  int unsigned liveness_limit;
  int unsigned wait_count;

  initial begin
    enable_asserts = !$test$plusargs("DISABLE_ASSERTS");
    liveness_limit = 16;
    void'($value$plusargs("APB_LIVENESS_LIMIT=%0d", liveness_limit));
  end

  function string red_assert(string msg);
    if ($test$plusargs("NO_COLOR_MISMATCH")) begin
      return {"MISMATCH: ", msg};
    end
    return $sformatf("%c[31mMISMATCH: %s%c[0m", 8'h1b, msg, 8'h1b);
  endfunction

  function bit request_ok_from(bit [31:0] addr, bit [2:0] size);
    bit addr_mapped;
    bit size_supported;
    bit addr_aligned;

    addr_mapped = (addr >= 32'h8000_0000) && (addr < 32'h8c00_0000);
    size_supported = (size == 3'b000) || (size == 3'b001) || (size == 3'b010);
    addr_aligned = (size == 3'b000) ||
                   (size == 3'b001 && addr[0] == 1'b0) ||
                   (size == 3'b010 && addr[1:0] == 2'b00);
    return addr_mapped && size_supported && addr_aligned;
  endfunction

  default clocking cb @(posedge Hclk);
  endclocking

  default disable iff (!Hresetn || !enable_asserts);

  ap_psel_onehot: assert property ($onehot0(Pselx))
    else $error("%s", red_assert($sformatf("Pselx is not one-hot0: %03b", Pselx)));

  ap_enable_has_select: assert property (Penable |-> (Pselx != 3'b000))
    else $error("%s", red_assert("Penable asserted without Pselx"));

  ap_setup_to_enable: assert property ((Pselx != 3'b000 && !Penable) |=> Penable)
    else $error("%s", red_assert("APB setup cycle was not followed by enable cycle"));

  ap_ctrl_stable_setup_to_enable: assert property (
    (Pselx != 3'b000 && !Penable) |=>
      ($stable(Paddr) && $stable(Pwrite) && $stable(Pselx) &&
       $stable(Pstrb) && $stable(Pprot))
  ) else $error("%s", red_assert("APB control changed from setup to enable"));

  ap_wdata_stable_setup_to_enable: assert property (
    (Pselx != 3'b000 && !Penable && Pwrite) |=> $stable(Pwdata)
  ) else $error("%s", red_assert("APB write data changed from setup to enable"));

  ap_ctrl_stable_during_wait: assert property (
    (Pselx != 3'b000 && Penable && !Pready) |=>
      (Pselx != 3'b000 && Penable && $stable(Paddr) && $stable(Pwrite) &&
       $stable(Pselx) && $stable(Pstrb) && $stable(Pprot))
  ) else $error("%s", red_assert("APB control changed while PREADY was low"));

  ap_wdata_stable_during_wait: assert property (
    (Pselx != 3'b000 && Penable && Pwrite && !Pready) |=> $stable(Pwdata)
  ) else $error("%s", red_assert("APB write data changed while PREADY was low"));

  ap_wait_stalls_ahb: assert property (
    (Pselx != 3'b000 && Penable && !Pready) |-> (!Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("APB wait state did not stall AHB with OKAY response"));

  ap_pslverr_only_at_completion: assert property (
    (Pselx != 3'b000 && Penable && Pslverr) |-> Pready
  ) else $error("%s", red_assert("PSLVERR asserted before final APB access cycle"));

  ap_pslverr_maps_to_ahb_error: assert property (
    (Pselx != 3'b000 && Penable && Pready && Pslverr) |=>
      (!Hreadyout && Hresp == 2'b01) ##1 (Hreadyout && Hresp == 2'b01)
  ) else $error("%s", red_assert("APB PSLVERR did not map to two-cycle AHB ERROR"));

  ap_pready_okay_completes_ahb: assert property (
    (Pselx != 3'b000 && Penable && Pready && !Pslverr) |=>
      (Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("APB OKAY completion did not complete AHB with OKAY"));

  ap_apb_final_waits_for_registered_response: assert property (
    (Pselx != 3'b000 && Penable && Pready) |-> (!Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("APB final cycle did not wait for registered AHB response"));

  ap_hrdata_captures_final_prdata: assert property (
    (Pselx != 3'b000 && Penable && Pready && !Pslverr && !Pwrite) |=>
      (Hrdata == $past(Prdata))
  ) else $error("%s", red_assert("HRDATA did not capture final APB PRDATA"));

  ap_read_pstrb_zero: assert property ((Pselx != 3'b000 && !Pwrite) |-> (Pstrb == 4'b0000))
    else $error("%s", red_assert($sformatf("Read transfer drove nonzero PSTRB=%04b", Pstrb)));

  ap_paddr_word_aligned: assert property ((Pselx != 3'b000) |-> (Paddr[1:0] == 2'b00))
    else $error("%s", red_assert($sformatf("APB PADDR is not word aligned: 0x%08h", Paddr)));

  ap_hresp_legal: assert property (Hresp inside {2'b00, 2'b01})
    else $error("%s", red_assert($sformatf("Hresp is not OKAY/ERROR: %02b", Hresp)));

  ap_error_two_cycle: assert property (
    (Hresp == 2'b01 && !Hreadyout) |=> (Hresp == 2'b01 && Hreadyout)
  ) else $error("%s", red_assert("AHB ERROR response is not two-cycle with final Hreadyout high"));

  ap_hrdata_zero_on_error: assert property (
    Hresp == 2'b01 |-> (Hrdata == 32'h0000_0000)
  ) else $error("%s", red_assert($sformatf("HRDATA was not zero during ERROR response: 0x%08h", Hrdata)));

  ap_error2_read_accepted: assert property (
    (Hreadyout && Hresp == 2'b01 && Hsel && Hreadyin && Htrans[1] &&
     request_ok_from(Haddr, Hsize) && !Hwrite) |=>
      (Pselx != 3'b000 && !Penable && !Pwrite)
  ) else $error("%s", red_assert("ERROR_2 read address phase was not followed by APB setup"));

  ap_error2_write_accepted: assert property (
    (Hreadyout && Hresp == 2'b01 && Hsel && Hreadyin && Htrans[1] &&
     request_ok_from(Haddr, Hsize) && Hwrite) |=>
      (Pselx == 3'b000 && !Penable && !Hreadyout && Hresp == 2'b00)
  ) else $error("%s", red_assert("ERROR_2 write address phase was not followed by write-data wait"));

  ap_error2_bad_request: assert property (
    (Hreadyout && Hresp == 2'b01 && Hsel && Hreadyin && Htrans[1] &&
     !request_ok_from(Haddr, Hsize)) |=>
      (!Hreadyout && Hresp == 2'b01 && Pselx == 3'b000 && !Penable)
  ) else $error("%s", red_assert("ERROR_2 invalid address phase was not followed by ERROR_1"));

  ap_unsupported_selected_gets_error: assert property (
    (Hreadyout && Hsel && Hreadyin && Htrans[1] && !request_ok_from(Haddr, Hsize))
      |=> ((!Hreadyout && Hresp == 2'b01) ##1 (Hreadyout && Hresp == 2'b01))
  ) else $error("%s", red_assert("Unsupported selected AHB transfer did not return ERROR response"));

  always @(posedge Hclk) begin
    if (!Hresetn) begin
      wait_count <= 0;
      if (enable_asserts) begin
        if (Pselx !== 3'b000 || Penable !== 1'b0 || Hreadyout !== 1'b1 || Hresp !== 2'b00) begin
          $error("%s", red_assert($sformatf(
            "Reset outputs not idle: Pselx=%03b Penable=%0b Hreadyout=%0b Hresp=%02b",
            Pselx, Penable, Hreadyout, Hresp)));
        end
      end
    end else if (enable_asserts) begin
      if (Pselx != 3'b000 && Penable && !Pready) begin
        wait_count <= wait_count + 1;
        if (wait_count >= liveness_limit) begin
          $error("%s", red_assert($sformatf(
            "APB transfer exceeded liveness limit while PREADY was low: limit=%0d",
            liveness_limit)));
        end
      end else begin
        wait_count <= 0;
      end
    end
  end
endmodule
