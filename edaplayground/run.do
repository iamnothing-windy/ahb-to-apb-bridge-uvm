# Questa run script for EDA Playground qrun/vsim.
#
# EDA Playground simulator command should include:
#   -do run.do
#   +define+BRIDGE_RTL_ASSERTIONS
# Enable simulator coverage in the EDA Playground compile/run options when
# UCDB/code/assertion coverage is required; otherwise only UVM covergroups that
# the simulator records by default will be reported.
#
# Put plusargs in EDA Playground run options, not in this Tcl file:
#   +UVM_TESTNAME=bridge_ahb_apb4_random_test +NUM_ITEMS=500 +MAX_ITEMS=10000 +APB_MAX_WAIT=3 +APB_ERR_PERCENT=15 +STRICT_SPEC_COVERAGE +UVM_NO_RELNOTES
#   +UVM_TESTNAME=bridge_error_boundary_test +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE +UVM_NO_RELNOTES
#   +UVM_TESTNAME=bridge_pipeline_random_test +NUM_ITEMS=100 +PIPELINE_BURST_LEN=8 +APB_MAX_WAIT=3 +APB_ERR_PERCENT=15 +STRICT_SPEC_COVERAGE +STRICT_PIPELINE_COVERAGE +UVM_NO_RELNOTES
#   +UVM_TESTNAME=bridge_reset_random_test +NUM_ITEMS=100 +APB_MAX_WAIT=3 +APB_ERR_PERCENT=15 +STRICT_SPEC_COVERAGE +UVM_NO_RELNOTES
#   +NO_COLOR_MISMATCH

transcript on
onbreak {quit -f}
onerror {quit -code 1 -f}
onfinish stop

# Do not use plain "run" in Questa batch. Use explicit ns duration.
# TB timeout is 1 ms; 2,000,000 ns lets normal UVM finish or timeout fire.
puts "RUN_DO_VERSION: questa_amba_rev2_apb4_wait_error_2000000ns"
puts "MISMATCH_COLOR: ANSI red enabled unless +NO_COLOR_MISMATCH is used"
puts "APB_RESPONSE_DEFAULTS: +APB_MAX_WAIT=3 +APB_ERR_PERCENT=15 unless overridden"
if {[catch {coverage save -onexit bridge.ucdb} cov_save_err]} {
  puts "COVERAGE_SAVE_WARNING: $cov_save_err"
}
run 2000000ns
if {[catch {coverage save bridge.ucdb} cov_save_now_err]} {
  puts "COVERAGE_SAVE_NOW_WARNING: $cov_save_now_err"
}
if {[catch {coverage report -details -cvg -file bridge_cvg_detail.rpt} cov_err]} {
  puts "COVERAGE_REPORT_WARNING: $cov_err"
}
if {[catch {coverage report -details -assert -file bridge_assert_detail.rpt} assert_cov_err]} {
  puts "ASSERTION_COVERAGE_REPORT_WARNING: $assert_cov_err"
}
if {[catch {coverage report -details -codeAll -assert -file bridge_code_assert_detail.rpt} code_cov_err]} {
  puts "CODE_ASSERTION_COVERAGE_REPORT_WARNING: $code_cov_err"
}
if {[file exists bridge.ucdb]} {
  if {[catch {exec vcover report -details -assert -codeAll bridge.ucdb > bridge_vcover_detail.rpt} vcover_err]} {
    puts "VCOVER_REPORT_WARNING: $vcover_err"
  }
}
puts "RUN_DO_DONE"
quit -f
