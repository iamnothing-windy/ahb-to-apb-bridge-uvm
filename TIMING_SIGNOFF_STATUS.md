# Timing Sign-Off Status

Date: 2026-07-15

## Conclusion

The current `bridge_core_fmax` Quartus flow now has completed post-fit timing evidence at the 100 MHz target for the low-I/O signoff wrapper.

Post-fit multicorner TimeQuest passes with worst setup slack `+0.174 ns`, worst hold slack `+0.162 ns`, and `0.000 ns` TNS at all reported corners.

The default `quartus_sta bridge_core_fmax` report generator still does not exit cleanly on this host within the local 20 minute limit and leaves `bridge_core_fmax.sta.summary` empty. The valid post-fit timing artifact for this run is the focused TimeQuest script output:

```text
quartus_fmax/output_files_core/bridge_core_fmax.postfit_sta.short.summary
```

## Active Timing Scope

```text
Project directory : quartus_fmax/
Quartus project   : bridge_core_fmax.qpf
Quartus settings  : bridge_core_fmax.qsf
Timing constraints: bridge_core_fmax.sdc
STA script        : postfit_sta_short.tcl
Top-level entity  : bridge_fmax_core_top
RTL source        : ../edaplayground/design.sv
Wrapper source    : bridge_fmax_core_top.sv
Device            : Cyclone V 5CSEMA5F31C6
Tool              : Quartus II 13.1.0 Build 162 SJ Web Edition
```

The wrapper intentionally reduces top-level I/O to `clk`, `reset_n`, and `led[7:0]` while instantiating `Bridge_Top`, so timing is closed on a low-I/O implementation of the active bridge RTL instead of the 228-pin raw bridge interface.

## Wrapper Timing Fix

The first post-fit STA attempt exposed a real wrapper timing failure on the combinational status output path:

```text
From: Bridge_Top:dut|bridge_7state_core:core|req.aligned_addr_word[4]
To  : led[6]
Slow 1100mV 85C setup slack: -3.174 ns
Slow 1100mV 0C setup slack : -2.963 ns
```

`quartus_fmax/bridge_fmax_core_top.sv` now registers `led[7:0]`. This keeps the status output observable while removing the long bridge-core-to-output-pin combinational path. The successful fitter run packed the 8 LED registers into I/O output buffers.

## Commands Used

The successful fit required the local Quartus 13.1 runtime workaround used during investigation:

```sh
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
LD_LIBRARY_PATH=/home/sinh/altera/13.1/quartus/compat-lib/cilkrts:/home/sinh/altera/13.1/quartus/compat-lib/libpng12:/home/sinh/altera/13.1/quartus/linux64:/home/sinh/altera/13.1/quartus/linux:$LD_LIBRARY_PATH \
/home/sinh/altera/13.1/quartus/bin/quartus_sh --clean bridge_core_fmax

LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
LD_LIBRARY_PATH=/home/sinh/altera/13.1/quartus/compat-lib/cilkrts:/home/sinh/altera/13.1/quartus/compat-lib/libpng12:/home/sinh/altera/13.1/quartus/linux64:/home/sinh/altera/13.1/quartus/linux:$LD_LIBRARY_PATH \
/home/sinh/altera/13.1/quartus/bin/quartus_map --64bit bridge_core_fmax

LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
LD_LIBRARY_PATH=/home/sinh/altera/13.1/quartus/compat-lib/cilkrts:/home/sinh/altera/13.1/quartus/compat-lib/libpng12:/home/sinh/altera/13.1/quartus/linux64:/home/sinh/altera/13.1/quartus/linux:$LD_LIBRARY_PATH \
/home/sinh/altera/13.1/quartus/bin/quartus_fit --64bit bridge_core_fmax --effort=fast --one_fit_attempt=on

LD_LIBRARY_PATH=/home/sinh/altera/13.1/quartus/compat-lib/cilkrts:/home/sinh/altera/13.1/quartus/compat-lib/libpng12:/home/sinh/altera/13.1/quartus/linux64:/home/sinh/altera/13.1/quartus/linux:$LD_LIBRARY_PATH \
/home/sinh/altera/13.1/quartus/bin/quartus_sta -t postfit_sta_short.tcl
```

## Applied Constraints

```tcl
create_clock -name clk -period 10.000 [get_ports {clk}]
set_clock_uncertainty -from [get_clocks {clk}] -to [get_clocks {clk}] 0.000
set_false_path -from [get_ports {reset_n}]
set_output_delay -clock [get_clocks {clk}] -max 2.000 [get_ports {led[*]}]
set_output_delay -clock [get_clocks {clk}] -min 0.000 [get_ports {led[*]}]
```

Physical pin, I/O standard, slew, and current-strength assignments are present for `clk`, `reset_n`, and `led[7:0]` in `bridge_core_fmax.qsf`.

## Post-Fit Reports

Report files:

```text
quartus_fmax/output_files_core/bridge_core_fmax.flow.rpt
quartus_fmax/output_files_core/bridge_core_fmax.fit.summary
quartus_fmax/output_files_core/bridge_core_fmax.fit.rpt
quartus_fmax/output_files_core/bridge_core_fmax.postfit_sta.short.summary
```

Flow summary:

| Item | Value |
| --- | --- |
| Flow status | Successful |
| Fit completed | Wed Jul 15 15:02:46 2026 |
| STA script completed | Wed Jul 15 15:26:42 2026 |
| Logic utilization | 37 / 32,070 ALMs, < 1% |
| Total registers | 85 |
| Total pins | 10 / 457, 2% |

Post-fit slack summary:

| Corner | Setup Slack | Hold Slack | Recovery | Removal | Min Pulse Width | TNS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Slow 1100mV 85C | +0.174 ns | +0.308 ns | +8.724 ns | +0.870 ns | +4.292 ns | 0.000 ns |
| Slow 1100mV 0C | +0.222 ns | +0.286 ns | +8.751 ns | +0.838 ns | +4.238 ns | 0.000 ns |
| Fast 1100mV 85C | +3.220 ns | +0.176 ns | +9.331 ns | +0.502 ns | +4.381 ns | 0.000 ns |
| Fast 1100mV 0C | +3.488 ns | +0.162 ns | +9.386 ns | +0.461 ns | +4.374 ns | 0.000 ns |

Multicorner worst-case slack:

| Check | Worst Slack | Design-Wide TNS |
| --- | ---: | ---: |
| Setup | +0.174 ns | 0.000 ns |
| Hold | +0.162 ns | 0.000 ns |
| Recovery | +8.724 ns | 0.000 ns |
| Removal | +0.461 ns | 0.000 ns |
| Minimum pulse width | +4.238 ns | 0.000 ns |

Unconstrained-path status from the successful short STA run:

| Property | Setup | Hold |
| --- | ---: | ---: |
| Illegal clocks | 0 | 0 |
| Unconstrained clocks | 0 | 0 |
| Unconstrained input ports | 0 | 0 |
| Unconstrained input port paths | 0 | 0 |
| Unconstrained output ports | 0 | 0 |
| Unconstrained output port paths | 0 | 0 |

Clock status:

| Target | Clock | Type | Status |
| --- | --- | --- | --- |
| clk | clk | Base | Constrained |

## Host Notes

Without the local runtime workaround, `quartus_fit` still hangs in the Quartus 13.1 `libtbbmalloc.so.2` path on this host. The working fit environment uses `LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2` and the Quartus compatibility libraries under `/home/sinh/altera/13.1/quartus/compat-lib/`.

The standard TimeQuest default report path is still unreliable on this host. Use `postfit_sta_short.tcl` for reproducible post-fit summary timing evidence unless a newer or supported Quartus environment is available.
