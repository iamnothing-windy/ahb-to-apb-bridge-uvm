# AHB-to-APB Bridge UVM DV Plan

## 1. DV Position

Verification must be requirement-driven, not implementation-driven.

The testbench must not assume the RTL is correct. The testbench must also not reduce checks just because the current RTL cannot pass them. If a legal scenario from the spec fails, the result is a bug report, waiver request, or spec clarification.

This plan uses ARM AMBA AHB/APB protocol semantics as the verification reference. The README supplies only project-specific scope, simplified interface details, and the decode map. The demo modules `AHB_Master.v` and `APB_Interface.v` are not the verification reference. They can help understand the original simulation, but they must not define pass/fail behavior.

## 2. Verification Reference

Project-specific requirements from the README:

```text
The bridge converts AHB/system-bus transfers into APB transfers.
The bridge latches address and holds it valid throughout the APB transfer.
The bridge decodes address and generates one-hot PSELx.
Only one PSELx can be active during a transfer.
The bridge drives write data onto APB for write transfer.
The bridge drives APB read data onto AHB for read transfer.
The bridge generates PENABLE timing strobe.
An APB transfer requires two cycles: setup and enable.
```

Implementation-visible decode map:

```text
0x8000_0000 - 0x83FF_FFFF -> PSEL0 / Pselx = 3'b001
0x8400_0000 - 0x87FF_FFFF -> PSEL1 / Pselx = 3'b010
0x8800_0000 - 0x8BFF_FFFF -> PSEL2 / Pselx = 3'b100
Other addresses              -> no selected APB slave
```

Supported RTL interface:

```text
Hclk, Hresetn, Pclken
Hsel, Hwrite, Hreadyin, Htrans[1:0], Hsize[2:0], Hburst[2:0], Hprot[3:0], Hmastlock
Haddr[31:0], Hwdata[31:0]
Hreadyout, Hresp[1:0], Hrdata[31:0]
Pwrite, Penable, Pready, Pslverr, Pselx[2:0]
Paddr[31:0], Pwdata[31:0], Prdata[31:0], Pstrb[3:0], Pprot[2:0]
```

Current release profile:

```text
ADDR_WIDTH=32 and DATA_WIDTH=32 are fixed.
NUM_APB_SLAVES=3 is fixed.
The data bus is 32-bit little-endian.
Paddr is word-aligned as {accepted_Haddr[31:2], 2'b00}.
Subword writes are represented with Pstrb.
Configurable endianness, bus widths, and slave count are out of scope for this source revision.
```

Remaining full-AMBA scope gaps:

```text
HRESP RETRY/SPLIT are not implemented and must be waived or implemented if claimed.
HBURST and HMASTLOCK are present and covered as sideband signals, but exact burst/lock semantics are not implemented.
PPROT[1] non-secure cannot be derived from the current AHB Rev 2.0-side interface and is hardwired secure; full APB4 security protection encodings require an added input or waiver.
AMBA test-interface/TIC functionality is not implemented.
```

The active architecture is the 7-State Transaction-Buffered Synchronous AHB-to-APB4 Bridge: one complete request buffer, registered non-posted response, local-error rejection before APB, optional synchronous `Pclken`, and acceptance windows in `ST_IDLE`, `ST_RESP_OK`, and `ST_ERROR_2`. The EDA flattened RTL/TB has been upgraded beyond APB2 with APB3/APB4-style `PREADY`, `PSLVERR`, `PSTRB`, and `PPROT`. The current archived `bridge_ahb_apb4_random_test` run used `+define+BRIDGE_RTL_ASSERTIONS`, seed 1, 500 items, `+STRICT_SPEC_COVERAGE`, APB wait/error randomization, and ended with `UVM_ERROR=0` and `UVM_FATAL=0`. Full closure still requires multi-seed regression, directed response-boundary tests, reset-random, USE_PCLKEN=1, and code/assertion coverage review.

These gaps are not silently ignored. If the project requirement is full ARM AMBA module compliance, RETRY/SPLIT, burst/lock semantics, and the AMBA test interface require implementation or explicit waiver. If the project requirement is this educational AHB-to-APB bridge, these items are out of scope but must remain documented.

AMBA test-interface chapter coverage policy:

```text
About the AMBA test interface          -> Not implemented in current RTL; fail if claimed.
External test interface                -> Not implemented in current RTL; fail if claimed.
Test vector types                      -> Not testable without the test interface/TIC; fail if claimed.
Test interface controller              -> Not implemented in current RTL; fail if claimed.
AHB Test Interface Controller          -> Not implemented in current RTL; fail if claimed.
Example AMBA AHB test sequences        -> Can guide stimulus only after TIC support exists.
ASB test interface controller          -> Not applicable to an AHB-to-APB bridge unless ASB/TIC is claimed.
Example AMBA ASB test sequences        -> Not applicable unless ASB/TIC is claimed.
```

The current UVM environment must therefore report two different statuses:

```text
Simplified AHB/APB bridge subset       -> Can be tested and closed by the current EDA testbench.
Full ARM AMBA Rev 2.0 module claim     -> Not closed; current RTL has missing interfaces/features.
```

The explicit compliance matrix is maintained in:

```text
docs/amba_rev2_compliance_matrix.md
```

## 3. Plan Mistakes To Correct

The previous plan had these issues:

```text
It treated RTL limitations as expected behavior in some places.
It mixed stimulus coverage with true protocol coverage.
It counted monitor-observed random traffic as coverage closure without enabling simulator coverage.
It did not clearly separate spec-valid positive tests from spec-invalid negative tests.
It did not require APB setup-phase coverage, only APB enable observation.
It did not clearly define HREADY/HREADYOUT behavior expected from an AHB slave.
It used demo intent as context, which is not a verification oracle.
```

Corrected principle:

```text
Spec defines expected behavior.
Stimulus explores legal and illegal cases.
Scoreboard and assertions report mismatches.
Coverage only means closure when simulator coverage is enabled and all planned bins/crosses are hit.
```

## 4. Transaction Classification

AHB transfer type:

```text
HTRANS = 2'b00 -> IDLE
HTRANS = 2'b01 -> BUSY
HTRANS = 2'b10 -> NONSEQ
HTRANS = 2'b11 -> SEQ
```

For this bridge, an AHB request is bridge-addressed when:

```text
Haddr inside 0x8000_0000 - 0x8BFF_FFFF
```

A request is candidate-valid when:

```text
Hresetn == 1
Hsel == 1
Hreadyin == 1
HTRANS inside {NONSEQ, SEQ}
Haddr inside decoded bridge address map
Hsize is byte, halfword, or word
Haddr alignment matches Hsize
```

Expected handling:

```text
Candidate-valid read  -> one APB read transfer
Candidate-valid write -> one APB write transfer
IDLE/BUSY             -> no APB transfer
Out-of-range address  -> two-cycle AHB ERROR, no APB transfer
Unsupported/misaligned HSIZE -> two-cycle AHB ERROR, no APB transfer
Hreadyin low          -> request must not be accepted that cycle
```

If the actual design does anything else, report it.

## 5. APB Protocol Requirements

For every accepted AHB read/write request, APB must perform a two-cycle transfer.

APB setup cycle:

```text
Pselx   != 3'b000
Penable == 0
Paddr   == accepted AHB address aligned to the 32-bit APB data word
Pwrite  == accepted AHB Hwrite
Pwdata  == accepted AHB write data for write transfer
Pstrb   == byte-lane strobe derived from Hsize/Haddr for writes, 0 for reads
Pprot   == protection mapping derived from Hprot
```

APB access phase immediately after setup:

```text
Pselx   stable from setup
Penable == 1
Paddr   stable from setup
Pwrite  stable from setup
Pwdata  stable from setup for write transfer
Pstrb   stable from setup
Pprot   stable from setup
If Pready == 0, all APB control/write data remain stable and Hreadyout remains low.
Final APB completion occurs when Pready == 1.
If Pslverr == 1 on final completion, Hresp returns AHB ERROR.
```

After APB completion:

```text
Penable must deassert before a new setup, unless the protocol allows a back-to-back setup with Penable low.
Pselx can deassert or move to the next selected slave only during the next setup phase.
```

APB one-hot rule:

```text
Pselx must always be one-hot or zero.
Pselx must never be 3'b011, 3'b101, 3'b110, or 3'b111.
```

## 6. AHB-Side Requirements

Reset:

```text
During reset, protocol/control outputs must go to known safe values.
Hresetn may assert asynchronously, but reset deassertion must be synchronized to Hclk by integration logic.
After reset release, datapath outputs are only meaningful when qualified by valid protocol response/transfer signals.
```

Response:

```text
Hresp must be OKAY for supported transfers that complete without APB error.
Unsupported selected transfers must return a two-cycle AHB ERROR response and must not create APB traffic.
APB final-cycle Pslverr is registered, then maps to a two-cycle AHB ERROR response.
The second ERROR response cycle completes the failed transfer and is also an AHB acceptance window for a held valid next address phase.
A valid read held through ERROR_1 is accepted in ERROR_2 and proceeds to APB setup.
A valid write held through ERROR_1 is accepted in ERROR_2 and proceeds to AHB write-data capture.
A bad selected transfer held through ERROR_1 is accepted in ERROR_2 as a new local error and starts another two-cycle ERROR response.
```

Read data:

```text
For a read transfer, Hrdata must reflect the registered Prdata value in the AHB response cycle after APB completion.
```

Ready behavior:

```text
Hreadyout must indicate when the bridge can complete or accept the transfer.
When Hreadyout is low, a protocol-compliant AHB master should hold address/control stable.
When Hreadyin is low, legal-mode stimulus must hold HSEL, HTRANS, HADDR, HWRITE, HSIZE, HBURST, HPROT, and HMASTLOCK stable until Hreadyin is high; Hreadyin low is a bus wait condition, not an independent transaction attribute to drop.
Legal-mode random stimulus uses `hreadyin_stall_cycles` to hold `HREADYIN=0` for 0 to 10 cycles before accepting the same held address/control phase.
The testbench must include legal master behavior under Hreadyout wait states.
If the bridge samples changing address/control while Hreadyout is low and produces a wrong APB transfer, report it.
```

## 7. Testbench Architecture

The UVM environment should contain:

```text
AHB active agent
APB passive monitor
APB read-data slave model
Reference model / scoreboard
Functional coverage collector
Protocol assertions
Reset controller
```

AHB driver must support two modes:

```text
Protocol-legal mode:
  Holds address/control stable while Hreadyout is low.
  Drives write data in the AHB data phase.
  Generates legal IDLE/BUSY/NONSEQ/SEQ timing.

Stress/negative mode:
  Can violate assumptions deliberately.
  Used only to test robustness and ensure failures are reported as negative tests.
```

APB monitor must sample both APB phases:

```text
Setup item:       Pselx != 0, Penable == 0
Access/wait item: Pselx != 0, Penable == 1, Pready == 0
Access/final item:Pselx != 0, Penable == 1, Pready == 1
```

The scoreboard must compare APB setup and enable behavior, not only the enable cycle.

## 8. Reference Model

The reference model must be based on accepted AHB requests, not RTL internal state.

Accepted AHB request record:

```text
addr
write/read
write_data for write
expected_pselx
expected_pstrb
expected_pprot
accept_cycle
```

Expected APB transfer:

```text
setup cycle followed by one or more access cycles until Pready is high
stable address/control/data from setup through every wait-state access cycle
decoded one-hot Pselx
matching Pwrite
matching Paddr
matching Pwdata for write
matching Pstrb and Pprot
read completion updates/checks Hrdata against the registered final-cycle Prdata
Pready low stalls AHB with Hreadyout low
Pslverr final completion maps to AHB ERROR
```

The scoreboard should support latency tolerance if the spec does not define exact latency, but must not tolerate protocol violations.

Allowed tolerance:

```text
The APB transfer may occur after a bounded number of cycles from accepted AHB request.
```

Not allowed tolerance:

```text
Wrong Pselx
Wrong Paddr
Wrong Pwrite
Wrong Pwdata
Missing setup phase
Missing enable phase
Unstable APB control from setup to enable
Unstable APB control while Pready is low
Wrong Pstrb or Pprot
Wrong Hresp/Hreadyout mapping for Pready/Pslverr
Unexpected APB transfer for invalid AHB request
Missing APB transfer for valid AHB request
X/Z on protocol outputs after reset
```

## 9. Stimulus Plan

This is still constrained-random, but the constraints are requirement-oriented.

Normal signoff stimulus must not be hand-driven directed transactions. Boundary, decode, control, and pipeline scenarios are closed with weighted random constraints plus coverage feedback. If random closure cannot hit a required bin within the configured maximum item count, the test reports a coverage miss instead of silently changing the expected behavior.

Positive legal traffic:

```text
Single read
Single write
Read/write to each decoded region
Boundary addresses
Back-to-back legal single transfers
Hreadyout wait-state compliant master behavior
Read-after-write and write-after-read ordering
```

Negative/robustness traffic:

```text
HTRANS IDLE
HTRANS BUSY
Out-of-range low address
Out-of-range high address
Hreadyin low
Reset during idle
Reset during APB setup
Reset during APB enable
Illegal master behavior while Hreadyout low
```

Back-to-back combinations to cover:

```text
read  -> read
read  -> write
write -> read
write -> write
```

Address boundaries to cover:

```text
0x7FFF_FFFC invalid low
0x8000_0000 first valid PSEL0
0x83FF_FFFC last aligned PSEL0 boundary sample
0x8400_0000 first valid PSEL1
0x87FF_FFFC last aligned PSEL1 boundary sample
0x8800_0000 first valid PSEL2
0x8BFF_FFFC last aligned PSEL2 boundary sample
0x8C00_0000 invalid high
```

## 10. Functional Coverage Plan

Coverage must be enabled in the simulator and archived as UCDB/detail reports. In the Questa EDA flow, `run.bash` is the preferred single EDA Playground web entry point; it saves `bridge.ucdb` and writes `bridge_cvg_detail.rpt`, `bridge_assert_detail.rpt`, `bridge_code_assert_detail.rpt`, and `bridge_vcover_detail.rpt` when the simulator has the relevant coverage enabled. `run.do` remains only for flows that choose the Tcl entry point instead of `run.bash`.

```text
coverage save -onexit bridge.ucdb
coverage report -details -cvg -file bridge_cvg_detail.rpt
coverage report -details -assert -file bridge_assert_detail.rpt
coverage report -details -codeAll -assert -file bridge_code_assert_detail.rpt
```

Internal RTL assertions are compiled only when the simulator command includes:

```text
+define+BRIDGE_RTL_ASSERTIONS
```

Assertion closure requires the assertion coverage report to show meaningful attempts for the key internal properties, including state legality, request ownership/no-overwrite, WAIT_WDATA capture, and ERROR_2 acceptance. A clean run without this define does not prove those internal properties.

AHB bus-cycle coverpoints, sampled every clock after reset:

```text
hsel: low, high
htrans: IDLE, BUSY, NONSEQ, SEQ
hreadyin: low, high
hsel x htrans
hreadyin x htrans
```

AHB accepted-transfer coverpoints, sampled only when `Hsel && Hreadyin && Htrans[1]`:

```text
hwrite: read, write
hsize: byte, halfword, word, and unsupported larger encodings
hburst: all AHB Rev 2.0 encodings as sideband coverage
hprot: all 16 values
hmastlock: low, high
addr_region: invalid_low, psel0, psel1, psel2, invalid_high
candidate_valid: valid, invalid
boundary_addr: all listed boundary addresses
hwrite x addr_region
hwrite x active htrans
hsize x active htrans
```

Response-boundary coverpoints are separate and require `bridge_pipeline_random_test` and `bridge_error_boundary_test` plus `+STRICT_PIPELINE_COVERAGE`:

```text
OKAY response-boundary read->read
OKAY response-boundary read->write
OKAY response-boundary write->read
OKAY response-boundary write->write
ERROR_2 response-boundary error->idle
ERROR_2 response-boundary error->read
ERROR_2 response-boundary error->write
ERROR_2 response-boundary error->invalid
ERROR_2 boundary from local error source
ERROR_2 boundary from APB PSLVERR source
```

APB protocol coverpoints:

```text
phase: setup, enable
pselx: 001, 010, 100
pwrite: read, write
pready: wait, complete
pslverr: okay, error on final access
pstrb: read-none, byte lanes, halfword low/high, word
pprot: reachable Hprot-mapped encodings with PPROT[1] hardwired secure
setup_to_enable_seen: yes
stable_control: yes
```

Reset coverpoints:

```text
reset_during_idle
reset_during_ahb_address_phase
reset_during_apb_setup
reset_during_apb_enable
```

Cross coverage:

```text
AHB bus: hsel x htrans
AHB bus: hreadyin x htrans
AHB accepted transfer: hwrite x addr_region
AHB accepted transfer: hwrite x active htrans
AHB accepted transfer: hsize x active htrans
candidate_valid x hwrite
candidate_valid x addr_region
apb pwrite x pselx
apb phase x pwrite
boundary_addr x hwrite
response_boundary_type, pipeline test only
reset_phase x transfer_type
```

Illegal coverage:

```text
multi-hot Pselx must remain zero hits
APB enable without prior setup must remain zero hits
APB control changes from setup to enable must remain zero hits
APB transfer generated for invalid AHB request must remain zero hits
```

Coverage closure requires all planned legal bins and crosses hit, all illegal bins zero, and no scoreboard/assertion errors.

## 11. Assertion Plan

Required assertions:

```systemverilog
$onehot0(Pselx)
Penable |-> (Pselx != 3'b000)
APB setup |=> APB enable
APB setup |=> stable(Paddr, Pwrite, Pselx, Pstrb, Pprot)
APB wait |=> stable(Paddr, Pwrite, Pselx, Pstrb, Pprot)
APB write setup |=> stable(Pwdata)
APB wait -> Hreadyout == 0 and Hresp == OKAY
APB Pslverr final -> two-cycle AHB ERROR
APB Pready final without Pslverr -> next AHB response cycle has Hreadyout == 1 and Hresp == OKAY
AHB final ERROR cycle is a new-transfer accept window when Hsel, Hreadyin, and Htrans[1] are asserted
Accepted unsupported selected transfer returns two-cycle ERROR with no APB setup
Read Pstrb == 0
Hrdata tracks registered Prdata at read completion
No X/Z on APB/AHB protocol-control outputs after reset; datapath is valid-qualified
No APB transfer for IDLE/BUSY
No APB transfer for out-of-range address
```

Assertions should fire bugs. They should not be disabled because the RTL currently fails, unless a formal waiver is documented.

## 12. Regression Plan

Tier 0 bring-up:

```text
Compile
Reset only
One randomized short test with monitor log
```

Tier 1 protocol sanity:

```text
Legal single-transfer random
Boundary random
Read/write per PSEL region
```

Tier 2 stress:

```text
Back-to-back legal traffic
Wait-state legal traffic
Reset random traffic
Invalid traffic
```

Tier 3 closure:

```text
Multi-seed random regression
Coverage enabled with UCDB and detailed covergroup bin report
Scoreboard clean
Assertions clean
Coverage goals met
Failure report generated for every failing seed
```

## 13. Failure Reporting

Every failure must report:

```text
Test name
Seed
Transaction number
AHB request fields
Expected APB behavior
Observed APB behavior
Assertion or scoreboard message
Waveform time
Spec requirement violated
```

Classify result as:

```text
RTL bug
Testbench bug
Spec ambiguity
Out-of-scope feature requiring waiver
```

DV must not hide failures by changing constraints unless the stimulus was illegal for the test intent.

## 14. Immediate TB Fixes From This Review

The existing TB should be corrected before claiming coverage closure:

```text
APB monitor must sample setup and enable phases.
Coverage model must cover APB setup phase, not only enable phase.
AHB driver must add protocol-legal Hreadyout hold behavior.
Coverage must be run with simulator coverage enabled.
Boundary sequence must guarantee all boundary addresses, not merely bias them.
Scoreboard should be latency-tolerant but protocol-strict.
Negative tests must be separated from positive legal tests in reporting.
```

## 15. Implementation Rewrite Plan

The next work should be done in phases. Do not try to fix everything at once.

### Phase 1: Clean protocol monitors

Goal:

```text
Observe protocol accurately without predicting pass/fail.
```

AHB monitor must emit only real AHB address phases:

```text
Sample on Hclk rising edge.
Ignore reset.
Classify HTRANS as IDLE/BUSY/NONSEQ/SEQ.
Capture Hwrite, Hreadyin, Haddr, Htrans.
For write candidate transfers, capture Hwdata from the following AHB data phase.
Record whether Hreadyout was low/high around the transfer.
Do not decide RTL correctness inside the monitor.
```

APB monitor must emit APB phase-level observations:

```text
apb_setup_item  when Pselx != 0 and Penable == 0
apb_enable_item when Pselx != 0 and Penable == 1
```

APB monitor must also detect protocol anomalies:

```text
enable_without_prior_setup
setup_not_followed_by_enable
control_changed_setup_to_enable
multi_hot_pselx
```

These anomalies should be reported to the scoreboard or assertion layer.

### Phase 2: Rewrite reference model

Goal:

```text
Predict expected APB behavior from accepted AHB requests.
```

The reference model should not look at DUT internals.

It should create an expected transaction when this condition is observed:

```text
Hresetn == 1
Hsel == 1
Hreadyin == 1
Htrans inside {NONSEQ, SEQ}
Haddr inside decoded bridge address map
Hsize is byte, halfword, or word with legal alignment
```

Expected APB transaction:

```text
expected_pselx = decode(Haddr)
expected_paddr = {Haddr[31:2], 2'b00}
expected_pwrite = Hwrite
expected_pwdata = captured AHB write data, for write only
expected_pstrb = strobe derived from Hsize/Haddr/Hwrite
expected_pprot = APB protection derived from Hprot
```

The reference model should allow configurable latency:

```text
MIN_APB_LATENCY = 0
MAX_APB_LATENCY = 8 initially
```

If the APB transfer appears outside the allowed latency window, report a failure.

### Phase 3: Protocol-strict scoreboard

Goal:

```text
Compare expected APB transfer against observed APB setup and enable phases.
```

For each expected transfer, scoreboard must check:

```text
One setup phase exists.
One or more enable/access phases follow setup until Pready is high.
Pselx matches expected decode.
Paddr matches the accepted AHB address aligned to the 32-bit APB data word.
Pwrite matches Hwrite.
Pwdata matches captured Hwdata for writes.
Pstrb and Pprot match expected mapping.
Paddr/Pwrite/Pselx/Pwdata/Pstrb/Pprot are stable from setup through wait states.
Pready/Pslverr map to Hreadyout/Hresp.
No unexpected APB transfer occurs for invalid AHB request.
```

Scoreboard must not silently drop expected items on reset unless reset legally cancels the transfer. Reset behavior must be explicitly reported:

```text
If reset occurs before APB setup, mark expected item cancelled_by_reset.
If reset occurs during setup/enable, check outputs return safe and report reset coverage.
```

### Phase 4: Driver legality modes

Goal:

```text
Separate protocol-legal stimulus from negative robustness stimulus.
```

Legal AHB mode:

```text
Drive address/control phase.
If Hreadyout is low, hold address/control stable.
Drive write data in the data phase.
Do not change request fields until transfer accepted/completed.
```

Negative mode:

```text
Change address/control while Hreadyout is low.
Drive invalid HTRANS combinations.
Drive out-of-range addresses.
Assert reset during active transfer.
```

Legal tests and negative tests must have separate scoreboard expectations.

### Phase 5: Coverage closure

Goal:

```text
Functional coverage reflects the verification plan, not just random activity.
```

Coverage must be sampled from monitor observations and scoreboard results:

```text
AHB request coverage from AHB monitor.
APB setup/enable coverage from APB monitor.
Pass/fail coverage from scoreboard result classification.
Reset phase coverage from reset observer.
```

Coverage must be enabled in simulator command line:

```text
Xcelium: -coverage all
Questa:  -coverage or simulator-specific coverage option
```

Merge and report regression UCDBs before claiming closure:

```text
vcover merge bridge_regression.ucdb <per-test ucdb files>
vcover report -details -assert -codeAll bridge_regression.ucdb
```

The active flattened EDA directory also provides:

```text
edaplayground/run.bash
edaplayground/report_coverage.sh
```

`run.bash` compiles every run with `+define+BRIDGE_RTL_ASSERTIONS`, runs either a single test or the supported regression tests across `SEEDS` seeds, stores per-test logs/UCDBs, merges UCDBs, and emits `bridge_regression_vcover_detail.rpt` in regression mode. On EDA Playground web, select `run.bash` only; do not also select `run.do`.

## 16. Test Plan

Tests are still random/constrained-random. The names below define constraint modes, not hand-driven directed tasks.

### bridge_ahb_apb4_random_test

Purpose:

```text
Default supported-subset random test for the 32-bit AHB-to-APB4 bridge profile.
Exercises supported single-beat transfers, unsupported selected transfers, APB wait/error, PSTRB, and PPROT reachable bins.
Does not claim RETRY/SPLIT, full burst continuation semantics, or full locked-transfer semantics.
```

Expected result:

```text
Scoreboard clean.
External and internal RTL assertions clean when +define+BRIDGE_RTL_ASSERTIONS is used.
STRICT_SPEC_COVERAGE closes only the supported functional bins and documented sideband/interface-value bins.
```

### bridge_sanity_test

Purpose:

```text
Fast compile/run sanity.
Small number of legal and invalid transactions.
Monitor log enabled.
```

Pass criteria:

```text
No UVM_FATAL.
Basic monitor activity observed.
```

This is not a signoff test.

### bridge_legal_single_random_test

Purpose:

```text
Only legal single AHB transfers.
All requests are inside decoded address ranges.
HTRANS is NONSEQ or SEQ.
Hreadyin is high.
AHB driver uses legal Hreadyout hold behavior.
```

Expected result:

```text
Every accepted AHB request produces exactly one APB setup and one or more APB access cycles, ending when Pready is high.
No unexpected APB transfer.
No protocol assertion failure.
```

### bridge_decode_random_test

Purpose:

```text
Stress address decode.
Balanced random traffic across PSEL0/PSEL1/PSEL2.
Read/write both directions.
```

Expected result:

```text
Pselx exactly matches address region.
Pselx is always one-hot.
```

### bridge_boundary_random_test

Purpose:

```text
Randomize within the boundary-address bin from the spec.
Use coverage feedback and MAX_ITEMS to close all boundary bins without scripting each transfer.
```

Boundary list:

```text
0x7FFF_FFFC
0x8000_0000
0x83FF_FFFC
0x8400_0000
0x87FF_FFFC
0x8800_0000
0x8BFF_FFFC
0x8C00_0000
```

Expected result:

```text
Invalid boundaries do not generate APB transfer.
Valid boundaries decode to the correct Pselx.
```

### bridge_invalid_random_test

Purpose:

```text
Generate invalid requests and check that the DUT does not create APB transfers.
```

Invalid categories:

```text
HTRANS IDLE
HTRANS BUSY
Hreadyin low
Address below 0x8000_0000
Address >= 0x8C00_0000
```

Expected result:

```text
No APB setup/access associated with invalid requests; unsupported selected requests return AHB ERROR.
```

### bridge_back_to_back_legal_random_test

Purpose:

```text
Legal back-to-back transfers with protocol-compliant master behavior.
```

Cover:

```text
read  -> read
read  -> write
write -> read
write -> write
same PSEL consecutive transfers
different PSEL consecutive transfers
```

Expected result:

```text
Ordering preserved.
No missing or duplicated APB transfer.
Each APB transfer has setup and access/final completion.
```

### bridge_hreadyout_random_test

Purpose:

```text
Specifically verify behavior when Hreadyout inserts wait states.
```

Stimulus:

```text
Legal master holds address/control stable while Hreadyout is low.
Random read/write and address region.
```

Expected result:

```text
DUT does not sample a new transfer until it is ready.
DUT APB output corresponds to the held request.
```

### bridge_pipeline_random_test

Purpose:

```text
Exercise AHB address/data pipelining with randomized legal NONSEQ/SEQ transfers.
Randomize read/write, address region, boundary-bin selection, and write data.
```

Expected result:

```text
Accepted AHB requests preserve order through APB setup/enable transfers.
AHB write data is associated with the previous address phase, per AHB pipeline semantics.
With +STRICT_PIPELINE_COVERAGE, response-boundary bins must close or the test must fail.
```

### bridge_error_boundary_test

Purpose:

```text
Directed ERROR_2 acceptance test with passive AHB agent and direct bus driving.
Exercises local-error -> idle/read/write/invalid/SEQ boundaries.
Exercises APB-PSLVERR -> idle/read/write/invalid boundaries.
Sets error-boundary-only coverage mode so +STRICT_SPEC_COVERAGE fails on missing ERROR-boundary bins without requiring unrelated random bins in this directed test.
```

Expected result:

```text
The next valid address phase held through ERROR_1 is accepted in ERROR_2.
Invalid selected requests held through ERROR_1 start a new local two-cycle ERROR in ERROR_2.
No APB transfer is generated for local invalid requests.
```

### bridge_reset_random_test

Purpose:

```text
Reset robustness.
```

Reset injection points:

```text
idle
AHB address phase
AHB data phase
APB setup phase
APB enable phase
```

Expected result:

```text
Outputs return safe.
No X/Z after reset release.
Pending scoreboard items are either completed before reset or cancelled by reset with explicit record.
```

### bridge_negative_protocol_random_test

Purpose:

```text
Deliberately violate legal master behavior.
```

Expected result:

```text
The test may fail protocol assertions or scoreboard checks.
Failures are classified as expected negative behavior only if the test intent marks them as such.
```

## 17. Coverage Closure Matrix

Closure matrix:

```text
Requirement                              Coverage / Check
-------------------------------------------------------------------------------
AHB read accepted                         hwrite=0 x candidate_valid=1
AHB write accepted                        hwrite=1 x candidate_valid=1
HTRANS IDLE ignored                       htrans=IDLE x no_apb_generated
HTRANS BUSY ignored                       htrans=BUSY x no_apb_generated
Hreadyin low wait                         address/control stable until Hreadyin=1
PSEL0 decode                              addr_region=psel0 x pselx=001
PSEL1 decode                              addr_region=psel1 x pselx=010
PSEL2 decode                              addr_region=psel2 x pselx=100
Invalid low address ignored               addr_region=invalid_low x no_apb_generated
Invalid high address ignored              addr_region=invalid_high x no_apb_generated
APB setup phase                           apb_phase=setup
APB enable phase                          apb_phase=enable
APB wait state                            pready=0 during access
APB final completion                      pready=1 during access
APB error response                        pslverr=1 x Hresp=ERROR
Local AHB error response                  unsupported selected transfer x two-cycle ERROR
APB PSTRB byte lanes                      pstrb byte bins
APB PSTRB half/word                       pstrb halfword and word bins
APB PPROT mapping                         reachable pprot mapped bins
AHB read data mapping                     Hrdata == registered final Prdata
Setup followed by enable                  setup_to_enable_seen
APB stable control                        stable_control_seen
APB write data stable                     stable_pwdata_seen
OKAY response-boundary read/read          b2b=rd_rd
OKAY response-boundary read/write         b2b=rd_wr
OKAY response-boundary write/read         b2b=wr_rd
OKAY response-boundary write/write        b2b=wr_wr
ERROR_2 response-boundary error/idle      err_boundary=idle
ERROR_2 response-boundary error/read      err_boundary=read
ERROR_2 response-boundary error/write     err_boundary=write
ERROR_2 response-boundary error/invalid   err_boundary=invalid
ERROR_2 source local error                directed local-error boundary group
ERROR_2 source APB PSLVERR                directed APB-error boundary group
Boundary low invalid                      boundary=0x7FFF_FFFC
Boundary first PSEL0                      boundary=0x8000_0000
Boundary last PSEL0                       boundary=0x83FF_FFFC
Boundary first PSEL1                      boundary=0x8400_0000
Boundary last PSEL1                       boundary=0x87FF_FFFC
Boundary first PSEL2                      boundary=0x8800_0000
Boundary last PSEL2                       boundary=0x8BFF_FFFC
Boundary high invalid                     boundary=0x8C00_0000
Reset during each phase                   reset_phase bins
No multi-hot Pselx                        illegal bin remains zero
No APB for invalid AHB                    illegal bin remains zero
```

Signoff requires:

```text
All legal bins hit.
All required crosses hit.
All illegal bins zero.
All assertions pass for positive tests.
All scoreboard checks pass for positive tests.
All failures in negative tests classified and documented.
```

## 18. Current TB Gap List

The current UVM TB is useful for bring-up, but it is not yet signoff-quality.

Known gaps after the latest EDA testbench edit:

```text
Latest archived bridge_ahb_apb4_random_test hit all tracked spec bins with no UVM errors/fatals and compiled internal RTL assertions.
Local Questa compile passes for the structured `sim/` flow, but local `vsim` runtime on this host still depends on a valid Questa license checkout.
UCDB save and detailed covergroup/assertion/code reporting are now scripted; use bridge_cvg_detail.rpt, bridge_assert_detail.rpt, and bridge_code_assert_detail.rpt to identify exact uncovered bins before changing stimulus.
Response-boundary coverage now means the next request is accepted on the `RESP_OK` or `ERROR_2` boundary cycle, with no required acceptance bubble; it is gated by +STRICT_PIPELINE_COVERAGE.
bridge_error_boundary_test now targets both local-error and APB-PSLVERR ERROR_2 boundaries, but it has not yet been completed in an archived licensed simulator log for this source revision.
bridge_pipeline_random_test with +STRICT_PIPELINE_COVERAGE has not yet been completed in an archived licensed simulator log for this source revision.
USE_PCLKEN=1 has not been verified; current external assertions are scoped to the default same-clock USE_PCLKEN=0 profile.
Reset cancellation is handled pragmatically, not yet fully phase-classified.
HBURST and HMASTLOCK semantics are not implemented beyond sideband value coverage; burst/lock claims require checker implementation or waiver.
HRESP RETRY/SPLIT are not implemented.
APB wait/error coverage is still coarse and needs wait-length/error-cross bins for signoff-quality closure.
Negative protocol-random tests still need cleaner expected-failure classification.
The AMBA Rev 2.0 test interface / TIC is not implemented in the RTL and is therefore a full-compliance failure if claimed.
```

Next coding order:

```text
1. Run `MODE=regression SEEDS=10 bash run.bash` from `edaplayground/` or equivalent qrun commands with +define+BRIDGE_RTL_ASSERTIONS, STRICT_SPEC_COVERAGE where applicable, code/assertion coverage, and 10-20 seeds.
2. Run bridge_error_boundary_test with STRICT_SPEC_COVERAGE and STRICT_PIPELINE_COVERAGE to archive local-error and APB-PSLVERR ERROR_2 boundaries.
3. Run bridge_pipeline_random_test with STRICT_PIPELINE_COVERAGE to classify response-boundary chaining through RESP_OK and ERROR_2.
4. Run bridge_reset_random_test and improve reset phase classification where needed.
5. Add a USE_PCLKEN=1 regression profile or explicitly waive that parameter setting.
6. Merge UCDBs, inspect bridge_cvg_detail.rpt/bridge_assert_detail.rpt/bridge_code_assert_detail.rpt, and add ignore_bins or directed stimulus for meaningful misses.
7. Split positive and negative protocol-random regressions.
8. Write DV_REPORT.md from the EDA logs with root-cause classification.
```
