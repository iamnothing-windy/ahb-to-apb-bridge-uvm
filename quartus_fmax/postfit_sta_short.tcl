load_package report

set opened_project 0
set created_netlist 0

if {![is_project_open]} {
  project_open bridge_core_fmax -revision bridge_core_fmax
  set opened_project 1
}

if {![timing_netlist_exist]} {
  create_timing_netlist -cmp_report -show_combined_on_summary_panel
  read_sdc
  update_timing_netlist
  set created_netlist 1
}

load_report

set output_dir [get_global_assignment -name PROJECT_OUTPUT_DIRECTORY]
set summary_path [file join $output_dir "bridge_core_fmax.postfit_sta.short.summary"]
set summary_file [open $summary_path w]

puts $summary_file "Post-fit TimeQuest short summary"
puts $summary_file "Project: bridge_core_fmax"
puts $summary_file ""

set analyses [list \
  [list Setup -setup] \
  [list Hold -hold] \
  [list Recovery -recovery] \
  [list Removal -removal] \
  [list {Minimum Pulse Width} -mpw] \
]

set operating_conditions [get_available_operating_conditions]

foreach_in_collection operating_condition $operating_conditions {
  set corner_name [get_operating_conditions_info -display_name $operating_condition]
  post_message -type info "Short STA: analyzing $corner_name"

  set_operating_conditions $operating_condition
  update_timing_netlist

  puts $summary_file "Corner: $corner_name"

  foreach analysis $analyses {
    set label [lindex $analysis 0]
    set option [lindex $analysis 1]
    set panel_name "Short $corner_name $label Summary"

    create_timing_summary $option -panel_name $panel_name

    set panel_id [get_report_panel_id "*TimeQuest*$panel_name"]
    if {$panel_id == -1} {
      puts $summary_file "$label: panel unavailable"
      continue
    }

    set row_count [get_number_of_rows -id $panel_id]
    for {set row_index 1} {$row_index < $row_count} {incr row_index} {
      set row [get_report_panel_row -row $row_index -id $panel_id]
      puts $summary_file "$label [lindex $row 0] slack=[lindex $row 1] tns=[lindex $row 2]"
    }
  }

  puts $summary_file ""
  flush $summary_file
}

close $summary_file

if {[catch {report_ucp -append -file $summary_path} ucp_error]} {
  set summary_file [open $summary_path a]
  puts $summary_file "Unconstrained path report failed: $ucp_error"
  close $summary_file
}

post_message -type info "Short STA summary written to $summary_path"

if {$created_netlist} {
  delete_timing_netlist
}

if {$opened_project} {
  project_close
}
