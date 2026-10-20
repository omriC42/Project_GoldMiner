# run_hook_draw.do - Step 2: hook_draw testbench, GUI mode (nothing closes by itself)
# Usage (ModelSim/Questa Transcript):
#     cd <project>/tests
#     do run_hook_draw.do
# Results: waves + images in tests/frames/*.bmp (one per test).
# After it pauses:  zt 4  -> zoom on test T4 (zt 0 = whole run)

# To run again after ANY file change: the full  do <this file>  (it recompiles).
# 'restart -f ; run -all' does NOT recompile - it reruns the OLD compiled code.
onbreak {resume}
file mkdir frames
# Unload the design that is still open from the previous test (it locks the files in work/).
# This only unloads the old simulation - ModelSim itself stays open.
catch {quit -sim}
# Each test has its OWN library folder (lib_hook_draw); it is never deleted (Windows file locks),
# vlog simply recompiles into it. The old shared "work" folder is no longer used.
set LIB lib_hook_draw
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/hook_draw.sv tb_hook_draw.sv
vsim -voptargs=+acc $LIB.tb_hook_draw

quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii    -color Yellow /tb_hook_draw/test_name
add wave -noupdate -radix ascii                  /tb_hook_draw/chk_name
add wave -noupdate                 -color Green  /tb_hook_draw/chk_pass
add wave -noupdate                 -color Red    /tb_hook_draw/chk_fail
add wave -noupdate -radix unsigned               /tb_hook_draw/nPass
add wave -noupdate -radix unsigned -color Red    /tb_hook_draw/nFail

add wave -noupdate -divider {HOOK POSITION (inputs)}
add wave -noupdate -radix unsigned /tb_hook_draw/angle_deg
add wave -noupdate -radix decimal  /tb_hook_draw/X0
add wave -noupdate -radix decimal  /tb_hook_draw/Y0
add wave -noupdate -radix decimal  /tb_hook_draw/Xend
add wave -noupdate -radix decimal  /tb_hook_draw/Yend
add wave -noupdate -radix unsigned /tb_hook_draw/R

add wave -noupdate -divider {VGA SCAN}
add wave -noupdate /tb_hook_draw/clk
add wave -noupdate /tb_hook_draw/resetN
add wave -noupdate -radix unsigned -format Analog-Step -height 40 -min 0 -max 639 /tb_hook_draw/pixelX
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 479 /tb_hook_draw/pixelY

add wave -noupdate -divider {DUT - rope math}
add wave -noupdate -radix decimal /tb_hook_draw/dut/crossProd
add wave -noupdate -radix decimal -format Analog-Step -height 80 -min -120000 -max 120000 -color Orange /tb_hook_draw/dut/crossProd
add wave -noupdate -radix decimal /tb_hook_draw/crossProd_ref
add wave -noupdate -radix unsigned -color Red /tb_hook_draw/cross_mismatch
add wave -noupdate -radix unsigned /tb_hook_draw/cross_pos_cnt
add wave -noupdate -radix unsigned /tb_hook_draw/cross_neg_cnt
add wave -noupdate -radix decimal /tb_hook_draw/dut/dxp
add wave -noupdate -radix decimal /tb_hook_draw/dut/dyp
add wave -noupdate -radix decimal /tb_hook_draw/dut/Lx
add wave -noupdate -radix decimal /tb_hook_draw/dut/Ly
add wave -noupdate -radix decimal /tb_hook_draw/dut/prod1
add wave -noupdate -radix decimal /tb_hook_draw/dut/prod2
add wave -noupdate -radix unsigned /tb_hook_draw/dut/limit
add wave -noupdate                 /tb_hook_draw/dut/inBox
add wave -noupdate                 /tb_hook_draw/dut/nearLine
add wave -noupdate -color Orange   /tb_hook_draw/dut/ropePixel
add wave -noupdate -color Cyan     /tb_hook_draw/dut/inClawBox
add wave -noupdate -color Cyan     /tb_hook_draw/dut/clawPixel

add wave -noupdate -divider {DUT OUTPUTS}
add wave -noupdate -color Orange   /tb_hook_draw/drawingRequest
add wave -noupdate -color Cyan     /tb_hook_draw/tipDR
add wave -noupdate -radix hex      /tb_hook_draw/RGBout

add wave -noupdate -divider {MEASURED per frame}
add wave -noupdate -radix unsigned /tb_hook_draw/meas_rope_px
add wave -noupdate                 /tb_hook_draw/meas_rope_width_px
add wave -noupdate                 /tb_hook_draw/meas_max_dist_px
add wave -noupdate -radix unsigned /tb_hook_draw/meas_claw_px
add wave -noupdate -radix unsigned -color Red /tb_hook_draw/meas_claw_far_px
add wave -noupdate -radix unsigned -color Red /tb_hook_draw/meas_outside_box_px
add wave -noupdate -radix unsigned -color Red /tb_hook_draw/meas_bad_color_px

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
echo "    Images of every frame: tests/frames/*.bmp"
echo "    zt 1..7 = zoom on a test, zt 0 = whole run."
