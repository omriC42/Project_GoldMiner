# run_hook_move.do - Step 1: hook_move testbench, GUI mode (nothing closes by itself)
# Usage (ModelSim/Questa Transcript):
#     cd <project>/tests
#     do run_hook_move.do
# After it pauses at the end:  zt 3   -> zoom on test T3   (zt 0 = whole run)
#   To run again after ANY file change: the full  do <this file>  (it recompiles).
#   'restart -f ; run -all' does NOT recompile - it reruns the OLD compiled code.

onbreak {resume}           ;# $stop at the end must not freeze this script before the wave setup
# Unload the design that is still open from the previous test (it locks the files in work/).
# This only unloads the old simulation - ModelSim itself stays open.
catch {quit -sim}
# Each test has its OWN library folder (lib_hook_move); it is never deleted (Windows file locks),
# vlog simply recompiles into it. The old shared "work" folder is no longer used.
set LIB lib_hook_move
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv tb_hook_move.sv
vsim -voptargs=+acc $LIB.tb_hook_move

# readable names for hookState
radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}

quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii    -color Yellow  /tb_hook_move/test_name
add wave -noupdate -radix unsigned               /tb_hook_move/test_no
add wave -noupdate -radix ascii                  /tb_hook_move/chk_name
add wave -noupdate                 -color Green   /tb_hook_move/chk_pass
add wave -noupdate                 -color Red     /tb_hook_move/chk_fail
add wave -noupdate -radix unsigned               /tb_hook_move/nPass
add wave -noupdate -radix unsigned -color Red     /tb_hook_move/nFail

add wave -noupdate -divider {INPUTS}
add wave -noupdate /tb_hook_move/clk
add wave -noupdate /tb_hook_move/resetN
add wave -noupdate /tb_hook_move/sof
add wave -noupdate -radix unsigned /tb_hook_move/frame_no
add wave -noupdate -color Cyan /tb_hook_move/shoot_key
add wave -noupdate -color Orange /tb_hook_move/tipCollision
add wave -noupdate -color Magenta /tb_hook_move/freeze
add wave -noupdate -color Orange  /tb_hook_move/restart
add wave -noupdate -radix decimal /tb_hook_move/X0
add wave -noupdate -radix decimal /tb_hook_move/Y0

add wave -noupdate -divider {HOOK STATE (DUT)}
add wave -noupdate -radix HookState -color Yellow /tb_hook_move/hookState
add wave -noupdate /tb_hook_move/dut/shoot_pulse
add wave -noupdate /tb_hook_move/dut/swing_right
add wave -noupdate /tb_hook_move/dut/hitBorder
add wave -noupdate -radix unsigned /tb_hook_move/dut/angle_fp
add wave -noupdate -radix unsigned -format Analog-Step -height 80 -min 0 -max 180 -color Cyan /tb_hook_move/angle_deg
add wave -noupdate -radix unsigned /tb_hook_move/dut/R_fp
add wave -noupdate -radix unsigned -format Analog-Step -height 80 -min 0 -max 700 -color Orange /tb_hook_move/R
add wave -noupdate -radix decimal  -format Analog-Step -height 60 -min 0 -max 640 /tb_hook_move/Xend
add wave -noupdate -radix decimal  -format Analog-Step -height 60 -min 0 -max 480 /tb_hook_move/Yend

add wave -noupdate -divider {MEASURED (real units)}
add wave -noupdate /tb_hook_move/meas_swing_period_s
add wave -noupdate /tb_hook_move/meas_swing_deg_s
add wave -noupdate /tb_hook_move/meas_shoot_px_s
add wave -noupdate /tb_hook_move/meas_retract_px_s
add wave -noupdate -radix unsigned /tb_hook_move/meas_R_changes_3frames

add wave -noupdate -divider {ROPE DIRECTION (Oct 2026)}
add wave -noupdate -radix decimal -format Analog-Step -height 40 -min -256 -max 256 /tb_hook_move/dirCos
add wave -noupdate -radix decimal -format Analog-Step -height 40 -min -256 -max 256 /tb_hook_move/dirSin
add wave -noupdate -radix unsigned -color Red /tb_hook_move/dir_bad
configure wave -namecolwidth 230 -valuecolwidth 120 -timelineunits us
update

run -all

# ---- after the run: cursors T1..T8 and the zoom helper ----
if {[file exists test_windows.do]} {source test_windows.do}
proc zt {n} {
    global TW
    if {![info exists TW($n)]} {echo "no test $n"; return}
    set a [lindex $TW($n) 0]; set b [lindex $TW($n) 1]
    wave zoom range "${a}ns" "${b}ns"
}
wave zoom full
echo ""
echo "=== Simulation is PAUSED, nothing was closed. ==="
echo "    zt 1..9 = zoom on a test,  zt 0 = whole run.  Green chk_pass / red chk_fail mark every check."
