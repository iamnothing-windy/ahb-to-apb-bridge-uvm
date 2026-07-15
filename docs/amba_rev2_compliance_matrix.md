# AMBA Rev 2.0 Compliance Matrix

## Position

The current archived EDA result is `bridge_ahb_apb4_random_test`, seed 1, with `+define+BRIDGE_RTL_ASSERTIONS`, coverage enabled, APB wait/error randomization, and `+STRICT_SPEC_COVERAGE`.

That run is a clean pass for the tracked educational AHB/APB bridge subset. It is not a full AMBA Rev 2.0 compliance pass.

If the design claim is full AMBA Rev 2.0 module compliance, missing interfaces/features are design failures or explicit scope waivers. They are not DV passes.

## Current EDA Evidence

Evidence files:

```text
edaplayground/result/regression_logs/bridge_ahb_apb4_random_test_seed1.log
edaplayground/result/regression_logs/bridge_ahb_apb4_random_test_seed1_vcover_detail.rpt
```

Observed result:

```text
Test: bridge_ahb_apb4_random_test
Seed: 1
NUM_ITEMS: 500
MAX_ITEMS: 10000
APB_MAX_WAIT: 3
APB_ERR_PERCENT: 15
UVM_WARNING: 0
UVM_ERROR: 0
UVM_FATAL: 0
Tracked spec coverage bins: all hit
AHB bus coverage: 100.00%
AHB accepted-transfer coverage: 98.75%
AHB aggregate coverage: 99.38%
APB coverage: 100.00%
Scoreboard summary: ahb_valid=508 ahb_invalid=583 local_error=583 apb_setup=508 apb_enable=1255 apb_wait=747 apb_error=72 ahb_resp_checks=1746 hrdata_checks=208 pending=0 pending_rsp=0 have_setup=0
```

Assertion coverage from `vcover report -details -assert -codeAll`:

```text
bridge_7state_core: 31 assertions, 27 hit, 4 not hit, 87.09%
bridge_assertions: 22 assertions, 19 hit, 3 not hit, 86.36%
```

Interpretation:

```text
PASS for the current tracked randomized educational AHB/APB subset.
PASS for current-source runtime with RTL assertions compiled.
NOT A FULL AMBA REV 2.0 PASS.
NOT closure for multi-seed regression, directed ERROR_2 response-boundary tests, reset-random tests, USE_PCLKEN=1, RETRY/SPLIT, exact burst/lock semantics, APB4 non-secure PPROT[1], or AMBA test-interface/TIC compliance.
```

## Current Source Status

```text
edaplayground/design.sv exposes HSEL, HSIZE, HBURST, HPROT, HMASTLOCK, PREADY, PSLVERR, PSTRB, PPROT, and optional synchronous Pclken.
ADDR_WIDTH=32, DATA_WIDTH=32, and NUM_APB_SLAVES=3 are fixed in this release profile.
The bridge is 32-bit little-endian; PADDR is word-aligned and PSTRB represents byte/halfword/word writes.
The AHB driver holds address/control stable across HREADYIN-low wait cycles.
The scoreboard checks local unsupported-selected two-cycle ERROR responses independently of assertions.
APB completion data/error is checked against the following registered AHB response cycle.
Unsupported selected transfers return AHB ERROR and do not create APB traffic.
Default EDA test is bridge_ahb_apb4_random_test; bridge_amba_rev2_random_test is only a compatibility alias.
```

## Interface Compliance

| Area | AMBA Rev 2.0 expectation | Current RTL status | DV status |
| --- | --- | --- | --- |
| AHB transfer type | HTRANS IDLE/BUSY/NONSEQ/SEQ behavior | Present as `Htrans[1:0]`; active transfer uses `Htrans[1]` | Current archived random run clean for tracked bins |
| AHB address/control | HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HSEL, HREADY semantics | `Haddr`, `Hwrite`, `Htrans`, `Hsize`, `Hburst`, `Hprot`, `Hsel`, `Hreadyin/Hreadyout` present | Current archived run clean for validation/decode/control coverage; exact burst semantics limited |
| AHB data | HWDATA, HRDATA | Present | Scoreboard checks APB write data and registered final PRDATA-to-HRDATA mapping |
| AHB response | HRESP | OKAY and ERROR modeled; APB PSLVERR and unsupported selected transfers map to two-cycle ERROR; RETRY/SPLIT not supported | Current random run covers APB/local errors; directed ERROR_2 boundary log still required |
| AHB burst/size/protection | HSIZE, HBURST, HPROT | Byte/halfword/word aligned transfers supported through PSTRB; larger or misaligned selected transfers ERROR; HBURST is sideband only | HSIZE/PSTRB covered; exact burst semantics require waiver or implementation |
| AHB slave select | HSEL | Present | Current archived random run clean for tracked bins |
| APB Rev 2.0 setup/enable | PSEL, PENABLE, PADDR, PWRITE, PWDATA, PRDATA | Present | Current archived random run clean with wait/error-aware scoreboard |
| APB3/APB4 extensions | PREADY, PSLVERR, PSTRB, PPROT | Present; `PPROT[1]` is hardwired secure because there is no AHB-side security input | Current archived random run covers reachable wait/error/control bins; full APB4 security encodings require an added input or waiver |

## AMBA Test Interface Chapter

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

Allowed claim from current evidence:

```text
The current bridge passes one archived Questa constrained-random AHB/APB4-style educational-subset run with RTL assertions compiled, no UVM errors/fatals, all tracked spec coverage bins hit, and clean scoreboard end state.
```

Not allowed claim:

```text
The design is fully ARM AMBA Rev 2.0 compliant.
```

Blocking items for a full AMBA Rev 2.0 claim:

```text
Run the full MODE=regression SEEDS=10 bash run.bash test list across 10-20 seeds with STRICT_SPEC_COVERAGE where applicable.
Archive bridge_error_boundary_test to close local-error and APB-PSLVERR ERROR_2 -> idle/read/write/invalid/SEQ behavior.
Run bridge_pipeline_random_test with STRICT_PIPELINE_COVERAGE for response-boundary coverage through RESP_OK and ERROR_2.
Run or waive USE_PCLKEN=1 profiles.
Implement or waive RETRY/SPLIT behavior.
Implement or waive exact burst wrapping/increment checking beyond pass-through sideband coverage.
Implement or waive full APB4 PPROT[1] non-secure mapping.
Add or waive AMBA test-interface/TIC requirements.
Run reset-random tests that hit reset during WAIT_WDATA, APB setup/access wait, RESP_OK, ERROR_1, and ERROR_2.
Merge UCDBs, inspect detailed covergroup/assertion/code coverage, and add waivers or stimulus for meaningful misses.
```
