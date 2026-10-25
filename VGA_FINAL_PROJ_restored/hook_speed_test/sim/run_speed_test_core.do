# run_speed_test_core.do - Step 3.5: speed-test core in ModelSim, GUI mode (nothing closes by itself)
# Usage:   cd <project>/hook_speed_test/sim    then    do run_speed_test_core.do
# To run again after ANY file change: the full  do run_speed_test_core.do  (it recompiles).
# 'restart -f ; run -all' does NOT recompile.
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_speed_test_core
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../../RTL/VGA/hook_params.sv ../../RTL/VGA/hook_move.sv ../../RTL/VGA/hook_draw.sv \
     ../../RTL/VGA/VGA_Controller.sv ../hook_speed_test_core.sv tb_hook_speed_test_core.sv
vsim -voptargs=+acc $LIB.tb_hook_speed_test_core

radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_hook_speed_test_core/test_name
add wave -noupdate -radix ascii               /tb_hook_speed_test_core/chk_name
add wave -noupdate -color Green               /tb_hook_speed_test_core/chk_pass
add wave -noupdate -color Red                 /tb_hook_speed_test_core/chk_fail
add wave -noupdate -radix unsigned            /tb_hook_speed_test_core/nPass
add wave -noupdate -radix unsigned -color Red /tb_hook_speed_test_core/nFail
add wave -noupdate -divider {KEYS (keypad)}
add wave -noupdate -color Cyan    /tb_hook_speed_test_core/key_shoot
add wave -noupdate -color Orange  /tb_hook_speed_test_core/key_catch
add wave -noupdate -color Magenta /tb_hook_speed_test_core/key_pause
add wave -noupdate -color White   /tb_hook_speed_test_core/key_reset
add wave -noupdate -divider {LIGHTS + STATE}
add wave -noupdate -color Green   /tb_hook_speed_test_core/greenLight
add wave -noupdate -color Yellow  /tb_hook_speed_test_core/yellowLight
add wave -noupdate -color Red     /tb_hook_speed_test_core/redLight
add wave -noupdate -radix HookState /tb_hook_speed_test_core/hookState
add wave -noupdate                /tb_hook_speed_test_core/paused
add wave -noupdate                /tb_hook_speed_test_core/dut/hookResetN
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 180 -color Cyan /tb_hook_speed_test_core/angle_deg
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 450 -color Orange /tb_hook_speed_test_core/dut/R
add wave -noupdate -divider {FRAME / VGA}
add wave -noupdate                /tb_hook_speed_test_core/clk
add wave -noupdate                /tb_hook_speed_test_core/use_fast_sof
add wave -noupdate -color Yellow  /tb_hook_speed_test_core/sof
add wave -noupdate                /tb_hook_speed_test_core/vgaSof
add wave -noupdate                /tb_hook_speed_test_core/capturing
add wave -noupdate -radix unsigned /tb_hook_speed_test_core/vgaX
add wave -noupdate -radix unsigned /tb_hook_speed_test_core/vgaY
add wave -noupdate                /tb_hook_speed_test_core/vgaActive
add wave -noupdate                /tb_hook_speed_test_core/dut/hookDR
add wave -noupdate -radix hex     /tb_hook_speed_test_core/dut/bgRGB
add wave -noupdate -radix hex -color Yellow /tb_hook_speed_test_core/RGB
configure wave -namecolwidth 240 -valuecolwidth 100 -timelineunits ms
update
run -all
if {[file exists test_windows.do]} {source test_windows.do}
proc zt {n} {
    global TW
    if {![info exists TW($n)]} {echo "no test $n"; return}
    wave zoom range "[lindex $TW($n) 0]ns" "[lindex $TW($n) 1]ns"
}
wave zoom full
echo ""
echo "=== Simulation is PAUSED, nothing was closed. ==="
echo "    Screen images: frames/screen_*.bmp   Checklist: CHECKLIST_step35_speed_test.md"
echo "    zt 1..5 = zoom on a test, zt 0 = whole run."
