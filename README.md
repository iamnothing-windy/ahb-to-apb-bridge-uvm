# AHB-to-APB Bridge UVM

SystemVerilog/Verilog AHB-to-APB bridge project with UVM verification assets and a Quartus timing sign-off wrapper.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `edaplayground/design.sv` | Active SystemVerilog AHB-to-APB bridge RTL used by the current DV/timing flow |
| `edaplayground/testbench.sv` | EDA Playground-compatible UVM testbench bundle |
| `tb/` | Structured UVM agents, sequences, tests, scoreboard, coverage, and assertions |
| `sim/` | Local ModelSim/Questa Makefile and run script |
| `quartus_fmax/` | Active Quartus low-I/O timing project and post-fit STA script |
| `AHB-to-APB-Bridge/` | Original educational Verilog design/reference files |
| `DV_PLAN.md` | Verification plan and closure requirements |
| `AMBA_REV2_COMPLIANCE_MATRIX.md` | AMBA Rev 2.0 claim boundary and compliance matrix |
| `TIMING_SIGNOFF_STATUS.md` | Current Quartus timing sign-off status |

## Current Timing Status

The active timing project is `quartus_fmax/bridge_core_fmax.qpf`.

Current post-fit TimeQuest evidence passes the 100 MHz target on Cyclone V `5CSEMA5F31C6`:

| Check | Worst Slack | TNS |
| --- | ---: | ---: |
| Setup | +0.174 ns | 0.000 ns |
| Hold | +0.162 ns | 0.000 ns |

The focused STA artifact is:

```text
quartus_fmax/output_files_core/bridge_core_fmax.postfit_sta.short.summary
```

See `TIMING_SIGNOFF_STATUS.md` for commands, constraints, host notes, and full multicorner slack details.

## Simulation

Local structured testbench flow:

```sh
make -C sim run TEST=bridge_random_test NUM_ITEMS=100 SEED=random
```

EDA/Questa bundled flow:

```sh
cd edaplayground
MODE=single TEST=bridge_ahb_apb4_random_test SEEDS=1 bash run.bash
```

Generated simulator databases, Quartus databases, and scratch timing experiments are intentionally ignored by Git. Archived evidence that is referenced by the documentation is kept explicitly.
