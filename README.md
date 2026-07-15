# AHB-to-APB Bridge UVM

This repository contains the active SystemVerilog AHB-to-APB bridge RTL, a structured UVM environment, a flattened EDA Playground bundle, and a Quartus low-I/O timing signoff wrapper.

`edaplayground/design.sv` is the RTL source of truth. `edaplayground/result/` is archived simulator evidence only.

## Project Snapshot

| Area | Status |
| --- | --- |
| RTL source | `edaplayground/design.sv` |
| Local UVM | `tb/` + `sim/` |
| EDA bundle | `edaplayground/testbench.sv` + `edaplayground/run.bash` |
| Quartus signoff | `quartus_fmax/bridge_core_fmax.qpf` |
| Architecture doc | `docs/architecture_overview.md` |
| Timing evidence | `docs/timing_signoff_status.md` |
| Archived Questa evidence | `docs/eda_playground_result.md` |

## Architecture

![Bridge state machine](docs/state.png)

The bridge is a 32-bit, 3-slave, transaction-buffered AHB-to-APB bridge. `Bridge_Top` is organized as `ahb_request_validator -> bridge_7state_core -> APB outputs`.

| AHB address range | APB select |
| --- | --- |
| `0x8000_0000` to `0x83FF_FFFF` | `Pselx[0]` |
| `0x8400_0000` to `0x87FF_FFFF` | `Pselx[1]` |
| `0x8800_0000` to `0x8BFF_FFFF` | `Pselx[2]` |
| Other addresses | local AHB `ERROR`, no APB transfer |

See `docs/architecture_overview.md` for the state machine, request buffering, and scope limits.

## Verification Evidence

### UVM Regression Result

| Field | Value |
| --- | --- |
| Test | `bridge_ahb_apb4_random_test` |
| Seed | `1` |
| Run config | `+define+BRIDGE_RTL_ASSERTIONS`, `NUM_ITEMS=500`, `MAX_ITEMS=10000`, `APB_MAX_WAIT=3`, `APB_ERR_PERCENT=15`, `STRICT_SPEC_COVERAGE` |
| UVM summary | `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0` |
| Coverage | AHB bus `100.00%`, accepted `98.75%`, aggregate `99.38%`, APB `100.00%`, all tracked spec bins hit |
| Scoreboard | `ahb_valid=508`, `ahb_invalid=583`, `local_error=583`, `apb_setup=508`, `apb_enable=1255`, `apb_wait=747`, `apb_error=72`, `ahb_resp_checks=1746`, `hrdata_checks=208`, `pending=0`, `pending_rsp=0`, `have_setup=0` |
| Assertion coverage | `bridge_7state_core 87.09%`, `bridge_assertions 86.36%` |

Artifacts:

| Artifact | Meaning |
| --- | --- |
| `edaplayground/result/regression_logs/bridge_ahb_apb4_random_test_seed1.log` | Archived clean Questa regression log |
| `edaplayground/result/regression_logs/bridge_ahb_apb4_random_test_seed1_vcover_detail.rpt` | Assertion coverage detail |
| `docs/eda_playground_result.md` | Short written summary of the archived UVM run |

Log excerpt:

```text
# UVM_INFO /usr/share/questa/questasim/verilog_src/uvm-1.2/src/base/uvm_objection.svh(1270) @ 116015000: reporter [TEST_DONE] 'run' phase is ready to proceed to the 'extract' phase
# UVM_INFO testbench.sv(1723) @ 116015000: uvm_test_top.env.cov [COV] AHB bus coverage = 100.00%
# UVM_INFO testbench.sv(1724) @ 116015000: uvm_test_top.env.cov [COV] AHB accepted-transfer coverage = 98.75%
# UVM_INFO testbench.sv(1725) @ 116015000: uvm_test_top.env.cov [COV] AHB aggregate coverage = 99.38%
# UVM_INFO testbench.sv(1729) @ 116015000: uvm_test_top.env.cov [COV] APB coverage = 100.00%
# UVM_INFO testbench.sv(1866) @ 116015000: uvm_test_top.env.cov [SPEC_COV] All tracked spec coverage bins were hit in this run
# UVM_INFO testbench.sv(1274) @ 116015000: uvm_test_top.env.scb [SCB] Summary: ahb_valid=508 ahb_invalid=583 local_error=583 apb_setup=508 apb_enable=1255 apb_wait=747 apb_error=72 ahb_resp_checks=1746 hrdata_checks=208 pending=0 pending_rsp=0 have_setup=0
# --- UVM Report Summary ---
# UVM_INFO :  411
# UVM_WARNING :    0
# UVM_ERROR :    0
# UVM_FATAL :    0
```

### Post-Fit Timing

| Metric | Value |
| --- | --- |
| Setup slack | `+0.174 ns` |
| Hold slack | `+0.162 ns` |
| TNS | `0.000 ns` |

Timing artifact:

| Artifact | Meaning |
| --- | --- |
| `quartus_fmax/output_files_core/bridge_core_fmax.postfit_sta.short.summary` | Current post-fit timing summary |

## How To Run

Local compile:

```sh
make -C sim compile
```

Local simulation:

```sh
make -C sim run TEST=bridge_ahb_apb4_random_test NUM_ITEMS=100 SEED=random
```

Archived EDA bundle:

```sh
cd edaplayground
MODE=single TEST=bridge_ahb_apb4_random_test SEEDS=1 bash run.bash
```

Quartus timing:

- Use `docs/timing_signoff_status.md` for the exact 64-bit compatibility environment and `postfit_sta_short.tcl` flow.

## Scope

This repo documents an educational AHB/APB bridge subset, not full AMBA Rev 2.0 compliance.

| Area | Current scope |
| --- | --- |
| `HBURST` | Sideband only |
| `HMASTLOCK` | Sideband only |
| `RETRY` / `SPLIT` | Not implemented |
| `PPROT[1]` | Hardwired secure |
| AMBA TIC/test interface | Not implemented |
| `USE_PCLKEN=1` | Supported in RTL, default verification profile is same-clock |

## Documentation

- `docs/dv_plan.md`
- `docs/architecture_overview.md`
- `docs/amba_rev2_compliance_matrix.md`
- `docs/eda_playground_notes.md`
- `docs/eda_playground_result.md`
- `docs/timing_signoff_status.md`
