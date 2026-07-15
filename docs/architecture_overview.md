# Architecture Overview

The active AHB-to-APB bridge RTL is `edaplayground/design.sv`. The old split Verilog demo tree is not the implementation source of truth.

## Top Level

`Bridge_Top` contains two RTL blocks:

```text
AHB address/control/data inputs
  -> ahb_request_validator
  -> bridge_7state_core
  -> APB address/control/data outputs and AHB response outputs
```

Release profile:

| Item | Value |
| --- | --- |
| Address width | 32 bits |
| Data width | 32 bits |
| APB slaves | 3 one-hot selects |
| Clocking | Single `Hclk`; optional synchronous `Pclken` enable |
| APB profile | APB setup/access with `PREADY`, `PSLVERR`, `PSTRB`, and `PPROT` |

## AHB Request Validation

`ahb_request_validator` treats an AHB transfer as active when:

```text
Hsel && Hreadyin && Htrans[1]
```

It checks the selected request before any APB transfer is created:

| Check | Accepted values |
| --- | --- |
| Address map | `Haddr[31:28] == 4'h8` and `Haddr[27:26] != 2'b11` |
| Size | byte, halfword, or word |
| Alignment | byte: any byte; halfword: `Haddr[0] == 0`; word: `Haddr[1:0] == 0` |

Address decode:

| AHB address range | APB select |
| --- | --- |
| `0x8000_0000` to `0x83FF_FFFF` | `Pselx = 3'b001` |
| `0x8400_0000` to `0x87FF_FFFF` | `Pselx = 3'b010` |
| `0x8800_0000` to `0x8BFF_FFFF` | `Pselx = 3'b100` |
| Anything else | local AHB `ERROR`, no APB select |

The validator also derives APB metadata:

| Output | Source |
| --- | --- |
| `PSTRB` | `HWRITE`, `HSIZE`, and `HADDR[1:0]` for 32-bit little-endian byte lanes |
| `PPROT` | `{~HPROT[0], 1'b0, HPROT[1]}` |

## Core State Machine

`bridge_7state_core` owns request buffering, APB sequencing, and AHB response timing.

| State | Purpose |
| --- | --- |
| `ST_IDLE` | Accept a new valid request or reject a bad selected request |
| `ST_WAIT_WDATA` | Capture AHB write data one cycle after the write address/control phase |
| `ST_APB_SETUP` | Drive APB setup phase with `PSEL` active and `PENABLE=0` |
| `ST_APB_ACCESS` | Drive APB access phase with `PENABLE=1`; hold payload stable until `PREADY` |
| `ST_RESP_OK` | Return successful registered AHB response and read data |
| `ST_ERROR_1` | First cycle of AHB two-cycle `ERROR`; `HREADYOUT=0` |
| `ST_ERROR_2` | Second cycle of AHB two-cycle `ERROR`; `HREADYOUT=1` and a new request can be accepted |

Acceptance windows are `ST_IDLE`, `ST_RESP_OK`, and `ST_ERROR_2`.

`HREADYOUT` is asserted only in `ST_IDLE`, `ST_RESP_OK`, and `ST_ERROR_2`. It is deasserted while the bridge is waiting for write data, driving APB setup/access, or in `ST_ERROR_1`.

The generated state diagram is kept in `docs/state.png`.

## Read And Write Flow

Write flow:

```text
AHB write address/control accepted
ST_WAIT_WDATA captures HWDATA
ST_APB_SETUP drives PADDR/PWRITE/PWDATA/PSTRB/PPROT/PSEL
ST_APB_ACCESS holds payload until PREADY
ST_RESP_OK or ST_ERROR_1/ST_ERROR_2 completes the AHB response
```

Read flow:

```text
AHB read address/control accepted
ST_APB_SETUP drives PADDR/PWRITE=0/PSTRB=0/PPROT/PSEL
ST_APB_ACCESS holds payload until PREADY
On successful completion, PRDATA is registered into HRDATA
ST_RESP_OK returns the registered read response
```

## Error Mapping

Local validation failures never create APB traffic. They generate a two-cycle AHB `ERROR` response.

APB `PSLVERR` at a completing access also maps to the same two-cycle AHB `ERROR` response.

`HRESP` values are:

| Condition | `HRESP` |
| --- | --- |
| Normal idle, wait, APB access, successful response | `OKAY` |
| `ST_ERROR_1` or `ST_ERROR_2` | `ERROR` |

`HRDATA` is zero during error responses.

## Scope Limits

The current release does not claim full AMBA Rev 2.0 module compliance.

Known limits:

| Area | Current scope |
| --- | --- |
| `HBURST` | Port is present and covered as sideband metadata; exact burst sequencing is not implemented |
| `HMASTLOCK` | Port is present and covered as sideband metadata; lock semantics are not implemented |
| `HRESP` | `OKAY` and `ERROR` are implemented; `RETRY` and `SPLIT` are not implemented |
| `PPROT[1]` | Hardwired secure because there is no AHB-side security input |
| AMBA TIC/test interface | Not implemented |
| `USE_PCLKEN=1` | RTL supports a synchronous enable profile; archived verification is still for the default same-clock profile |

## Quartus Timing Wrapper

`quartus_fmax/bridge_fmax_core_top.sv` is not the SoC integration top. It is a low-I/O timing wrapper that instantiates `Bridge_Top`, drives deterministic LFSR-based AHB/APB activity, and registers `led[7:0]` status outputs so Quartus can close timing on Cyclone V without exposing the full raw bridge interface at top level.
