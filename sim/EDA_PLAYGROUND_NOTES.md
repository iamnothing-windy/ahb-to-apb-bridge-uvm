# EDA Playground Notes

Use a SystemVerilog/UVM simulator such as Questa/ModelSim.

The active EDA Playground flow is the flattened source under `edaplayground/`:

```text
edaplayground/design.sv
edaplayground/testbench.sv
edaplayground/run.bash
```

Compile with internal RTL assertions enabled:

```text
+define+BRIDGE_RTL_ASSERTIONS
```

Enable simulator functional/code/assertion coverage when using `run.bash`; it writes `bridge.ucdb`, `bridge_cvg_detail.rpt`, `bridge_assert_detail.rpt`, `bridge_code_assert_detail.rpt`, and `bridge_vcover_detail.rpt` when the simulator supports those report modes.

Use the checked-in regression wrapper for full runs:

```text
cd edaplayground
MODE=regression SEEDS=10 bash run.bash
bash report_coverage.sh bridge.ucdb bridge_vcover_detail.rpt
```

On EDA Playground web, choose either `run.bash` or `run.do`, not both. For regression and assertion/code coverage reporting, choose `run.bash`.

Legacy split-file compile order, not the active flattened EDA flow:

```text
AHB_Slave_Interface.v
APB_Controller.v
bridge_top.v
tb/interfaces/ahb_if.sv
tb/interfaces/apb_if.sv
tb/bridge_uvm_pkg.sv
tb/top/bridge_assertions.sv
tb/top/tb_top.sv
```

Include directories:

```text
tb
tb/ahb_agent
tb/apb_agent
tb/env
tb/seq
tb/tests
tb/top
tb/interfaces
```

Useful run arguments:

```text
+UVM_TESTNAME=bridge_ahb_apb4_random_test +NUM_ITEMS=500 +MAX_ITEMS=10000 +STRICT_SPEC_COVERAGE
+UVM_TESTNAME=bridge_random_test +NUM_ITEMS=100
+UVM_TESTNAME=bridge_invalid_random_test +NUM_ITEMS=100
+UVM_TESTNAME=bridge_boundary_random_test +NUM_ITEMS=100
+UVM_TESTNAME=bridge_back_to_back_random_test +NUM_ITEMS=100
+UVM_TESTNAME=bridge_pipeline_random_test +NUM_ITEMS=100 +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE
+UVM_TESTNAME=bridge_error_boundary_test +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE
+UVM_TESTNAME=bridge_reset_random_test +NUM_ITEMS=100
+UVM_TESTNAME=bridge_stress_random_test +NUM_ITEMS=1000
```

For first bring-up, use:

```text
+UVM_TESTNAME=bridge_sanity_test +NUM_ITEMS=20
```
