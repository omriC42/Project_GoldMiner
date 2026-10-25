# run_hook_system.do - Step 3: hook_move + hook_draw together, GUI mode (nothing closes by itself)
# Usage (ModelSim/Questa Transcript):
#     cd <project>/tests
#     do run_hook_system.do
# Takes a few minutes (it draws ~26 full frames as images). For a fast run without images
# set SAVE_IMAGES = 0 at the top of tb_hook_system.sv.
# Results: waves + image sequence tests/frames/seq_*.bmp. Checklist: CHECKLIST_step3_hook_system.md
# After it pauses:  zt 4  -> zoom on test T4 (zt 0 = whole run)

# To run again after ANY file change: the full  do <this file>  (it recompiles).
# 'restart -f ; run -all' does NOT recompile - it reruns the OLD compiled code.
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_hook_system
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv ../RTL/VGA/hook_draw.sv tb_hook_system.sv
vsim -voptargs=+acc $LIB.tb_hook_system

radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}

quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii    -color Yellow /tb_hook_system/test_name
add wave -noupdate -radix ascii                  /tb_hook_system/chk_name
add wave -noupdate                 -color Green  /tb_hook_system/chk_pass
add wave -noupdate                 -color Red    /tb_hook_system/chk_fail
add wave -noupdate -radix unsigned               /tb_hook_system/nPass
add wave -noupdate -radix unsigned -color Red    /tb_hook_system/nFail

add wave -noupdate -divider {FRAMES}
add wave -noupdate                 /tb_hook_system/clk
add wave -noupdate                 /tb_hook_system/resetN
add wave -noupdate -color Yellow   /tb_hook_system/sof
add wave -noupdate -radix unsigned /tb_hook_system/frame_no
add wave -noupdate -radix ascii    /tb_hook_system/scan_kind
add wave -noupdate -color Magenta  /tb_hook_system/snap
add wave -noupdate -radix unsigned /tb_hook_system/image_no

add wave -noupdate -divider {HOOK MOTION (hook_move)}
add wave -noupdate -color Cyan     /tb_hook_system/shoot_key
add wave -noupdate -radix HookState -color Yellow /tb_hook_system/hookState
add wave -noupdate -radix unsigned -format Analog-Step -height 70 -min 0 -max 180 -color Cyan   /tb_hook_system/angle_deg
add wave -noupdate -radix unsigned -format Analog-Step -height 70 -min 0 -max 450 -color Orange /tb_hook_system/R
add wave -noupdate -radix decimal  -format Analog-Step -height 50 -min 0 -max 640 /tb_hook_system/Xend
add wave -noupdate -radix decimal  -format Analog-Step -height 50 -min 0 -max 480 /tb_hook_system/Yend
add wave -noupdate                 /tb_hook_system/mv/hitBorder

add wave -noupdate -divider {DRAWING (hook_draw)}
add wave -noupdate -radix unsigned /tb_hook_system/pixelX
add wave -noupdate -radix unsigned /tb_hook_system/pixelY
add wave -noupdate -color Orange   /tb_hook_system/drawingRequest
add wave -noupdate -color Cyan     /tb_hook_system/tipDR
add wave -noupdate -radix hex      /tb_hook_system/RGBout

add wave -noupdate -divider {COLLISION = tipDR AND goldDR}
add wave -noupdate                 /tb_hook_system/gold_on
add wave -noupdate -color Gold     /tb_hook_system/goldDR
add wave -noupdate -color Red      /tb_hook_system/tipCollision
add wave -noupdate -radix unsigned /tb_hook_system/collisions
add wave -noupdate -radix unsigned /tb_hook_system/tip_gold_px
add wave -noupdate -radix unsigned /tb_hook_system/rope_gold_px
add wave -noupdate -radix unsigned /tb_hook_system/rope_gold_frames

add wave -noupdate -divider {MEASURED}
add wave -noupdate                 /tb_hook_system/meas_swing_period_s
add wave -noupdate                 /tb_hook_system/meas_ray_dev_px
add wave -noupdate                 /tb_hook_system/meas_len_err_px
add wave -noupdate -radix decimal  /tb_hook_system/meas_hit_x
add wave -noupdate -radix decimal  /tb_hook_system/meas_hit_y
add wave -noupdate -radix unsigned -color Red /tb_hook_system/scan_extra

add wave -noupdate -divider {ROPE DIRECTION (Oct 2026)}
add wave -noupdate -radix decimal -format Analog-Step -height 40 -min -256 -max 256 /tb_hook_system/dirCos
add wave -noupdate -radix decimal -format Analog-Step -height 40 -min -256 -max 256 /tb_hook_system/dirSin
add wave -noupdate -radix unsigned -color Red /tb_hook_system/dir_bad
configure wave -namecolwidth 230 -valuecolwidth 110 -timelineunits ms
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
echo "    Image sequence: tests/frames/seq_*.bmp   Checklist: CHECKLIST_step3_hook_system.md"
echo "    zt 1..5 = zoom on a test, zt 0 = whole run."
