# AMBA Rev 2.0 Compliance Matrix

## Position

The latest archived EDA run from the earlier registered-response RTL/TB with `bridge_amba_rev2_random_test` showed a clean tracked non-pipeline educational bridge-subset run, but it did not compile internal RTL assertions and predates the current HREADYIN-driver, local-error-scoreboard, APB-PSLVERR-boundary, and test-name updates.

The current source has been locally compile/vopt checked with `+define+BRIDGE_RTL_ASSERTIONS`; local simulation is blocked by Questa license checkout. The TB now fatals if the define is missing unless `+ALLOW_NO_RTL_ASSERTIONS` is explicitly passed for non-signoff debug. Directed `ERROR_2` response-boundary, strict pipeline, reset-random, assertion-attempt, and code/assertion coverage regressions still need archived licensed simulator logs before those behaviors are considered closed.

If the design claim is full AMBA Rev 2.0 module compliance, missing interfaces/features are design failures or scope waivers. They are not DV passes.

## Current EDA Evidence

Observed result:

```text
bridge_amba_rev2_random_test ran to TEST_DONE on the previous registered-response refactor.
UVM_ERROR = 0.
UVM_FATAL = 0.
Scoreboard summary: ahb_valid=383 ahb_invalid=414 apb_setup=383 apb_enable=947 apb_wait=564 apb_error=75 ahb_resp_checks=458 hrdata_checks=146 pending=0 have_setup=0.
Tracked non-pipeline spec bins: all hit.
AHB bus coverage: 100.00%.
AHB accepted-transfer coverage: 98.75%.
AHB aggregate coverage: 99.38%.
APB covergroup: 100.00%.
```

Interpretation:

```text
PASS for the previous expanded tracked non-pipeline AHB/APB bridge subset exercised by bridge_amba_rev2_random_test.
NOT A FULL AMBA REV 2.0 PASS.
NOT evidence for the current edited source after the HREADYIN-driver/local-error-scoreboard/test-name changes.
NOT evidence for internal RTL assertion attempts, directed ERROR_2 boundary, strict response-boundary pipeline, reset-random, USE_PCLKEN=1, RETRY/SPLIT, full burst/lock semantics, APB4 non-secure PPROT[1], or AMBA test-interface/TIC compliance.
```

Current source status:

```text
edaplayground/design.sv now exposes HSEL, HSIZE, HBURST, HPROT, and HMASTLOCK.
edaplayground/design.sv now also exposes PREADY, PSLVERR, PSTRB, PPROT, and optional synchronous Pclken.
ADDR_WIDTH=32, DATA_WIDTH=32, and NUM_APB_SLAVES=3 are fixed in this release profile.
The bridge is 32-bit little-endian; PADDR is word-aligned and PSTRB represents byte/halfword writes.
edaplayground/testbench.sv now drives/monitors/covers those AHB sideband and APB wait/error/control signals.
The AHB legal-mode driver now holds address/control stable across HREADYIN-low wait cycles instead of dropping that transaction.
HREADYIN wait insertion is controlled by randomized hreadyin_stall_cycles, covering 0 to 10 low-ready cycles.
The scoreboard now checks local unsupported-selected two-cycle ERROR responses independently of assertions.
bridge_error_boundary_test now includes both local-error and APB-PSLVERR ERROR_2 boundary groups.
APB completion data/error is now checked against the following registered AHB response cycle.
Unsupported selected transfers are expected to return AHB ERROR and not create APB traffic.
Default EDA test is now bridge_ahb_apb4_random_test; bridge_amba_rev2_random_test remains only as a compatibility alias.
```

## Interface Compliance

| Area | AMBA Rev 2.0 expectation | Current RTL status | DV status |
| --- | --- | --- | --- |
| AHB transfer type | HTRANS IDLE/BUSY/NONSEQ/SEQ behavior | Present as Htrans[1:0] | Previous random log clean for tracked bins; current-source runtime rerun required |
| AHB address/control | HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HSEL, HREADY semantics | Haddr, Hwrite, Htrans, Hsize, Hburst, Hprot, Hsel, Hreadyin/Hreadyout present in EDA RTL | Current source compile/vopt clean; runtime rerun required; exact burst semantics still limited |
| AHB data | HWDATA, HRDATA | Present | Current source compile/vopt clean; runtime rerun required; scoreboard checks APB write data and registered final PRDATA-to-HRDATA mapping |
| AHB response | HRESP | OKAY and ERROR modeled in EDA RTL; APB PSLVERR and unsupported selected transfers map to two-cycle ERROR; the second ERROR cycle is an acceptance window for the next request; RETRY/SPLIT not supported | Current source compile/vopt clean; directed local/APB ERROR_2 boundary log still required; RETRY/SPLIT must be waived or implemented for full AHB |
| AHB burst/size/protection | HSIZE, HBURST, HPROT | Ports present; byte/halfword/word aligned transfers supported through PSTRB; larger or misaligned selected transfers ERROR; HBURST is sideband only | Sideband/value coverage only; exact burst semantics still require waiver or implementation |
| AHB slave select | HSEL | Present in EDA RTL | Previous random log clean for tracked bins; current-source runtime rerun required |
| APB Rev 2.0 setup/enable | PSEL, PENABLE, PADDR, PWRITE, PWDATA, PRDATA | Present | Current source compile/vopt clean; runtime rerun required with wait/error-aware scoreboard |
| APB3/APB4 extensions | PREADY, PSLVERR, PSTRB, PPROT | Present in EDA RTL/TB; PPROT[1] is hardwired secure because there is no AHB-side security input | Current source compile/vopt clean; runtime rerun required for reachable bins; full APB4 security encodings require an added input or waiver |

## AMBA Test Interface Chapter

The quoted AMBA Rev 2.0 test-interface chapter must be handled as follows.

| Section | Current RTL status | DV conclusion |
| --- | --- | --- |
| About the AMBA test interface | No AMBA test interface exists in the RTL | Not implemented; fail if claimed |
| External interface | No external test-interface ports exist | Not implemented; fail if claimed |
| Test vector types | No TIC/test-interface vector path exists | Not testable; fail if claimed |
| Test interface controller | No TIC exists | Not implemented; fail if claimed |
| AHB Test Interface Controller | No AHB TIC exists | Not implemented; fail if claimed |
| Example AMBA AHB test sequences | Can only guide future stimulus if TIC is added | Not closed |
| ASB test interface controller | DUT is AHB-to-APB, not ASB | N/A unless ASB/TIC is claimed |
| Example AMBA ASB test sequences | DUT is AHB-to-APB, not ASB | N/A unless ASB/TIC is claimed |

## Current Claim Boundary

Allowed claim from current log:

```text
The previous constrained-random EDA test hit all tracked non-pipeline bins for the expanded educational AHB/APB bridge subset and observed no scoreboard/external-assertion failures.
The current edited source compiles/vopts with internal RTL assertions enabled.
```

Not allowed claim:

```text
The design is fully ARM AMBA Rev 2.0 compliant.
```

Blocking items for a full AMBA Rev 2.0 claim:

```text
Run +define+BRIDGE_RTL_ASSERTIONS and archive assertion coverage showing non-vacuous attempts for key internal properties.
Run bridge_ahb_apb4_random_test and the full `MODE=regression SEEDS=10 bash run.bash` test list across 10-20 seeds with STRICT_SPEC_COVERAGE where applicable.
Archive bridge_error_boundary_test to close local-error and APB-PSLVERR ERROR_2 -> idle/read/write/invalid/SEQ behavior.
Use +UVM_TESTNAME=bridge_pipeline_random_test +NUM_ITEMS=100 +PIPELINE_BURST_LEN=8 +APB_MAX_WAIT=3 +APB_ERR_PERCENT=15 +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE for response-boundary coverage through RESP_OK and ERROR_2.
Run or waive USE_PCLKEN=1 profiles.
Implement or waive RETRY/SPLIT behavior.
Implement or waive exact burst wrapping/increment checking beyond pass-through sideband coverage.
Implement or waive full APB4 PPROT[1] non-secure mapping.
Add or waive AMBA test-interface/TIC requirements.
Run reset-random tests that hit reset during WAIT_WDATA, APB setup/access wait, RESP_OK, ERROR_1, and ERROR_2.
Enable simulator functional/code/assertion coverage database and archive merged UCDB plus bridge_cvg_detail.rpt, bridge_assert_detail.rpt, bridge_code_assert_detail.rpt, and vcover report output from `vcover report -details -assert -codeAll`.
Close covergroups/code/assertion goals to target or justify unreachable/invalid bins with ignore_bins/waivers.
```
