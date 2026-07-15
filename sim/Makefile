TEST ?= bridge_random_test
NUM_ITEMS ?= 100
SEED ?= random

RTL_DIR := ../AHB-to-APB-Bridge
TB_DIR  := ../tb

RTL_FILES := \
  $(RTL_DIR)/AHB_Slave_Interface.v \
  $(RTL_DIR)/APB_Controller.v \
  $(RTL_DIR)/bridge_top.v

TB_FILES := \
  $(TB_DIR)/interfaces/ahb_if.sv \
  $(TB_DIR)/interfaces/apb_if.sv \
  $(TB_DIR)/bridge_uvm_pkg.sv \
  $(TB_DIR)/top/bridge_assertions.sv \
  $(TB_DIR)/top/tb_top.sv

INCDIRS := \
  +incdir+$(TB_DIR) \
  +incdir+$(TB_DIR)/ahb_agent \
  +incdir+$(TB_DIR)/apb_agent \
  +incdir+$(TB_DIR)/env \
  +incdir+$(TB_DIR)/seq \
  +incdir+$(TB_DIR)/tests \
  +incdir+$(TB_DIR)/top \
  +incdir+$(TB_DIR)/interfaces

.PHONY: compile run clean

compile:
	@if [ ! -d work ]; then vlib work; fi
	vlog -sv $(INCDIRS) $(RTL_FILES) $(TB_FILES)

run: compile
	vsim -c work.tb_top +UVM_TESTNAME=$(TEST) +NUM_ITEMS=$(NUM_ITEMS) -sv_seed $(SEED) -do "run -all; quit -f"

clean:
	rm -rf work transcript vsim.wlf *.log
