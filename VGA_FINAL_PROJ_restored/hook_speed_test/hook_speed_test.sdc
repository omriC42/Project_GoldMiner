# hook_speed_test.sdc - clocks for the speed test
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_pll_clocks
derive_clock_uncertainty
# asynchronous / slow inputs and LEDs: not timed
set_false_path -from [get_ports {resetN_pin PS2_CLK PS2_DAT}]
set_false_path -to   [get_ports {redLight yellowLight greenLight}]
