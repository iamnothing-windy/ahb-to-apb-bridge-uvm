if {[file exists work]} {
  vdel -lib work -all
}
vlib work

set RTL_DIR ../edaplayground
set TB_DIR  ../tb

vlog -sv \
  +define+BRIDGE_RTL_ASSERTIONS \
  +incdir+$TB_DIR \
  +incdir+$TB_DIR/ahb_agent \
  +incdir+$TB_DIR/apb_agent \
  +incdir+$TB_DIR/env \
  +incdir+$TB_DIR/seq \
  +incdir+$TB_DIR/tests \
  +incdir+$TB_DIR/top \
  +incdir+$TB_DIR/interfaces \
  $RTL_DIR/design.sv \
  $TB_DIR/interfaces/ahb_if.sv \
  $TB_DIR/interfaces/apb_if.sv \
  $TB_DIR/bridge_uvm_pkg.sv \
  $TB_DIR/top/bridge_assertions.sv \
  $TB_DIR/top/tb_top.sv

vsim -c work.tb_top +UVM_TESTNAME=bridge_ahb_apb4_random_test +NUM_ITEMS=100 -sv_seed random -do "run -all; quit -f"
