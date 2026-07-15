#!/usr/bin/env bash
set -euo pipefail

ucdb="${1:-bridge.ucdb}"
out="${2:-bridge_vcover_detail.rpt}"

vcover report -details -assert -codeAll "$ucdb" > "$out"
