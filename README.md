# AHB-to-APB Bridge UVM

SystemVerilog AHB-to-APB bridge project with a structured UVM testbench, an EDA Playground bundle, and a Quartus timing sign-off wrapper.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `edaplayground/design.sv` | Active bridge RTL source used by simulation and Quartus |
| `edaplayground/testbench.sv` | Flattened EDA Playground UVM testbench bundle |
| `edaplayground/run.bash` | EDA Playground/Questa regression wrapper |
| `tb/` | Structured local UVM interfaces, agents, sequences, tests, scoreboard, coverage, and assertions |
| `sim/` | Local ModelSim/Questa Makefile and `run.do` flow |
| `quartus_fmax/` | Active Quartus `bridge_core_fmax` low-I/O timing project |
| `docs/` | Verification plan, compliance boundary, EDA notes, archived-run summary, and timing status |

`edaplayground/design.sv` is the RTL source of truth. The local `tb/` flow compiles that RTL directly instead of maintaining a second RTL copy.

## Architecture

The bridge is implemented as `Bridge_Top` in `edaplayground/design.sv`:

```text
AHB inputs -> ahb_request_validator -> bridge_7state_core -> APB outputs
```

The active release profile is a 32-bit, 3-slave, transaction-buffered AHB-to-APB bridge. It validates the AHB address/control phase, decodes one-hot `Pselx`, generates `Pstrb`/`Pprot`, holds APB setup/access payload stable through `PREADY` wait states, maps local decode/alignment failures and `PSLVERR` to two-cycle AHB `ERROR`, and returns read data through a registered response path.

Address map:

| AHB address range | APB select |
| --- | --- |
| `0x8000_0000` to `0x83FF_FFFF` | `Pselx[0]` |
| `0x8400_0000` to `0x87FF_FFFF` | `Pselx[1]` |
| `0x8800_0000` to `0x8BFF_FFFF` | `Pselx[2]` |
| Other addresses | local AHB `ERROR`, no APB transfer |

See `docs/architecture_overview.md` for the state machine, request buffering, error mapping, and scope limits.

The generated state-machine diagram is `docs/state.png`.

## Simulation

Local compile:

```sh
make -C sim compile
```

Local run:

```sh
make -C sim run TEST=bridge_ahb_apb4_random_test NUM_ITEMS=100 SEED=random
```

EDA/Questa bundled run:

```sh
cd edaplayground
MODE=single TEST=bridge_ahb_apb4_random_test SEEDS=1 bash run.bash
```

The current host can compile the local Questa flow, but `vsim` runtime depends on a valid Questa license environment.

## Timing

The active timing project is `quartus_fmax/bridge_core_fmax.qpf` for Cyclone V `5CSEMA5F31C6`.

Current post-fit TimeQuest evidence passes the 100 MHz target:

| Check | Worst Slack | TNS |
| --- | ---: | ---: |
| Setup | +0.174 ns | 0.000 ns |
| Hold | +0.162 ns | 0.000 ns |

Focused STA artifact:

```text
quartus_fmax/output_files_core/bridge_core_fmax.postfit_sta.short.summary
```

Use the focused STA script for the reliable local report path:

```sh
cd quartus_fmax
quartus_sta -t postfit_sta_short.tcl
```

## Documentation

- `docs/dv_plan.md`
- `docs/architecture_overview.md`
- `docs/amba_rev2_compliance_matrix.md`
- `docs/eda_playground_notes.md`
- `docs/eda_playground_result.md`
- `docs/timing_signoff_status.md`
