# EDA Playground Result

This summarizes the downloaded `edaplayground/result/` bundle from the successful Questa run.

Evidence kept in the repo:

```text
edaplayground/result/regression_logs/bridge_ahb_apb4_random_test_seed1.log
edaplayground/result/regression_logs/bridge_ahb_apb4_random_test_seed1_vcover_detail.rpt
```

## Run

```text
qrun -clean -batch -access=rw+/. -uvmhome uvm-1.2 -timescale 1ns/1ns -mfcu +define+BRIDGE_RTL_ASSERTIONS -coverage -sv_seed 1 design.sv testbench.sv
```

Test:

```text
bridge_ahb_apb4_random_test
```

## Outcome

```text
UVM_ERROR : 0
UVM_FATAL : 0
```

Coverage:

```text
AHB bus coverage                 = 100.00%
AHB accepted-transfer coverage    = 98.75%
AHB aggregate coverage           = 99.38%
APB coverage                     = 100.00%
All tracked spec coverage bins hit
```

Scoreboard summary:

```text
ahb_valid=508 ahb_invalid=583 local_error=583 apb_setup=508 apb_enable=1255 apb_wait=747 apb_error=72 ahb_resp_checks=1746 hrdata_checks=208 pending=0 pending_rsp=0 have_setup=0
```

Assertion coverage from the archived `vcover` report:

```text
bridge_7state_core : 87.09%
bridge_assertions  : 86.36%
```

Selected log excerpt:

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

The UCDB and simulator working directories are intentionally not committed; the retained text logs are the portable evidence for this repository.
