#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

# Single EDA Playground entry point. Use this instead of combining run.do with
# another shell script. It compiles with RTL assertions, runs the requested test
# or regression list, saves UCDBs, and emits readable vcover text reports.

MODE="${MODE:-single}"
TEST="${TEST:-bridge_ahb_apb4_random_test}"
SEEDS="${SEEDS:-1}"
LOGDIR="${LOGDIR:-regression_logs}"
NUM_ITEMS="${NUM_ITEMS:-500}"
MAX_ITEMS="${MAX_ITEMS:-10000}"
APB_MAX_WAIT="${APB_MAX_WAIT:-3}"
APB_ERR_PERCENT="${APB_ERR_PERCENT:-15}"
COVERAGE_ARGS="${COVERAGE_ARGS:--coverage}"

mkdir -p "$LOGDIR"

QUESTA_DO='transcript on
onbreak {quit -f}
onerror {quit -code 1 -f}
onfinish stop
puts "RUN_BASH_DO_VERSION: single_entry_rtl_assertions_vcover"
if {[catch {coverage save -onexit bridge.ucdb} cov_save_err]} {
  puts "COVERAGE_SAVE_ONEXIT_WARNING: $cov_save_err"
}
run 2000000ns
if {[catch {coverage save bridge.ucdb} cov_save_now_err]} {
  puts "COVERAGE_SAVE_NOW_WARNING: $cov_save_now_err"
}
if {[catch {coverage report -details -cvg -file bridge_cvg_detail.rpt} cov_err]} {
  puts "COVERGROUP_COVERAGE_REPORT_WARNING: $cov_err"
}
if {[catch {coverage report -details -assert -file bridge_assert_detail.rpt} assert_cov_err]} {
  puts "ASSERTION_COVERAGE_REPORT_WARNING: $assert_cov_err"
}
if {[catch {coverage report -details -codeAll -assert -file bridge_code_assert_detail.rpt} code_cov_err]} {
  puts "CODE_ASSERTION_COVERAGE_REPORT_WARNING: $code_cov_err"
}
puts "RUN_BASH_DO_DONE"
quit -f'

read_coverage_args() {
  # shellcheck disable=SC2206
  coverage_args_array=($COVERAGE_ARGS)
}

emit_vcover_report() {
  local ucdb="$1"
  local out="$2"

  if [[ ! -f "$ucdb" ]]; then
    return 0
  fi

  if command -v vcover >/dev/null 2>&1; then
    vcover report -details -assert -codeAll "$ucdb" > "$out"
  else
    printf 'VCOVER_REPORT_WARNING: vcover not found\n' >&2
  fi
}

run_one() {
  local test_name="$1"
  local seed="$2"
  shift 2

  local log_file="${LOGDIR}/${test_name}_seed${seed}.log"
  local ucdb_file="${LOGDIR}/${test_name}_seed${seed}.ucdb"
  local vcover_file="${LOGDIR}/${test_name}_seed${seed}_vcover_detail.rpt"

  rm -f bridge.ucdb bridge_cvg_detail.rpt bridge_assert_detail.rpt bridge_code_assert_detail.rpt bridge_vcover_detail.rpt
  read_coverage_args

  qrun \
    "${clean_args[@]}" \
    -batch \
    -access=rw+/. \
    -uvmhome uvm-1.2 \
    -timescale 1ns/1ns \
    -mfcu \
    +define+BRIDGE_RTL_ASSERTIONS \
    "${coverage_args_array[@]}" \
    -sv_seed "$seed" \
    design.sv testbench.sv \
    -voptargs="+acc=npr" \
    -do "$QUESTA_DO" \
    +UVM_TESTNAME="$test_name" \
    +UVM_NO_RELNOTES \
    +NO_COLOR_MISMATCH \
    "$@" 2>&1 | tee "$log_file"

  local status=${PIPESTATUS[0]}
  clean_args=()

  if [[ -f bridge.ucdb ]]; then
    cp bridge.ucdb "$ucdb_file"
    emit_vcover_report "$ucdb_file" "$vcover_file"
  fi

  return "$status"
}

run_regression() {
  local failures=0
  local seed

  clean_args=(-clean)

  for seed in $(seq 1 "$SEEDS"); do
    run_one bridge_sanity_test "$seed" +NUM_ITEMS=20 || failures=$((failures + 1))
    run_one bridge_ahb_apb4_random_test "$seed" +NUM_ITEMS="$NUM_ITEMS" +MAX_ITEMS="$MAX_ITEMS" +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" +STRICT_SPEC_COVERAGE || failures=$((failures + 1))
    run_one bridge_invalid_random_test "$seed" +NUM_ITEMS=100 +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" || failures=$((failures + 1))
    run_one bridge_boundary_random_test "$seed" +NUM_ITEMS=100 +MAX_ITEMS=5000 +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" || failures=$((failures + 1))
    run_one bridge_back_to_back_random_test "$seed" +NUM_ITEMS=100 +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" || failures=$((failures + 1))
    run_one bridge_pipeline_random_test "$seed" +NUM_ITEMS=100 +PIPELINE_BURST_LEN=8 +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE || failures=$((failures + 1))
    run_one bridge_error_boundary_test "$seed" +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE || failures=$((failures + 1))
    run_one bridge_reset_random_test "$seed" +NUM_ITEMS=100 +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" || failures=$((failures + 1))
    run_one bridge_stress_random_test "$seed" +NUM_ITEMS=1000 +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" || failures=$((failures + 1))
  done

  shopt -s nullglob
  local ucdbs=("$LOGDIR"/*.ucdb)
  if (( ${#ucdbs[@]} > 0 )) && command -v vcover >/dev/null 2>&1; then
    vcover merge "${LOGDIR}/bridge_regression.ucdb" "${ucdbs[@]}"
    emit_vcover_report "${LOGDIR}/bridge_regression.ucdb" "${LOGDIR}/bridge_regression_vcover_detail.rpt"
  fi

  return "$failures"
}

if [[ "$MODE" == "regression" ]]; then
  run_regression
else
  clean_args=(-clean)
  run_one "$TEST" 1 +NUM_ITEMS="$NUM_ITEMS" +MAX_ITEMS="$MAX_ITEMS" +APB_MAX_WAIT="$APB_MAX_WAIT" +APB_ERR_PERCENT="$APB_ERR_PERCENT" +STRICT_SPEC_COVERAGE
fi
