package bridge_uvm_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_ahb)
  `uvm_analysis_imp_decl(_apb)

  typedef enum int {
    ADDR_PSEL0,
    ADDR_PSEL1,
    ADDR_PSEL2,
    ADDR_INVALID_LOW,
    ADDR_INVALID_HIGH,
    ADDR_BOUNDARY
  } addr_kind_e;

  typedef enum int {
    APB_SETUP,
    APB_ENABLE
  } apb_phase_e;

  `include "ahb_item.sv"
  `include "apb_item.sv"

  `include "ahb_sequencer.sv"
  `include "ahb_driver.sv"
  `include "ahb_monitor.sv"
  `include "ahb_agent.sv"

  `include "apb_monitor.sv"
  `include "apb_slave_model.sv"
  `include "apb_agent.sv"

  `include "bridge_scoreboard.sv"
  `include "bridge_coverage.sv"
  `include "bridge_env.sv"

  `include "ahb_base_seq.sv"
  `include "ahb_random_seq.sv"
  `include "ahb_invalid_random_seq.sv"
  `include "ahb_boundary_random_seq.sv"
  `include "ahb_back_to_back_random_seq.sv"
  `include "ahb_reset_random_seq.sv"
  `include "ahb_stress_random_seq.sv"

  `include "bridge_base_test.sv"
  `include "bridge_sanity_test.sv"
  `include "bridge_reset_test.sv"
  `include "bridge_random_test.sv"
  `include "bridge_invalid_random_test.sv"
  `include "bridge_boundary_random_test.sv"
  `include "bridge_back_to_back_random_test.sv"
  `include "bridge_reset_random_test.sv"
  `include "bridge_stress_random_test.sv"
endpackage
