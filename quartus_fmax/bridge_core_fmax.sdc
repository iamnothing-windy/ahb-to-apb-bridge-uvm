create_clock -name clk -period 10.000 [get_ports {clk}]
set_clock_uncertainty -from [get_clocks {clk}] -to [get_clocks {clk}] 0.000

# The wrapper reset is asynchronous to clk and is excluded from data timing.
set_false_path -from [get_ports {reset_n}]

# Board-level placeholder constraints for the wrapper status outputs.
set_output_delay -clock [get_clocks {clk}] -max 2.000 [get_ports {led[*]}]
set_output_delay -clock [get_clocks {clk}] -min 0.000 [get_ports {led[*]}]
