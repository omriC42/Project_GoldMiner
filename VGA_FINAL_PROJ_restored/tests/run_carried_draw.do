# run_carried_draw.do - the caught object hanging on the claw (carried_draw), GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_carried_draw.do        (expect VERSION 11.0)
# To run again after ANY file change: the full  do run_carried_draw.do  (it recompiles).
# 'restart -f ; run -all' does NOT recompile.
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_carried_draw
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv +incdir+../RTL/VGA ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv \
     ../RTL/VGA/carried_draw.sv tb_carried_draw.sv
vsim -voptargs=+acc $LIB.tb_carried_draw

quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_carried_draw/test_name
add wave -noupdate -radix ascii               /tb_carried_draw/chk_name
add wave -noupdate -color Green               /tb_carried_draw/chk_pass
add wave -noupdate -color Red                 /tb_carried_draw/chk_fail
add wave -noupdate -radix unsigned            /tb_carried_draw/nPass
add wave -noupdate -radix unsigned -color Red /tb_carried_draw/nFail
add wave -noupdate -divider {INPUTS}
add wave -noupdate                 /tb_carried_draw/clk
add wave -noupdate -color Cyan     /tb_carried_draw/show
add wave -noupdate -radix unsigned /tb_carried_draw/objType
add wave -noupdate -radix unsigned -color Cyan /tb_carried_draw/angle_now
add wave -noupdate -radix decimal  /tb_carried_draw/dirCos
add wave -noupdate -radix decimal  /tb_carried_draw/dirSin
add wave -noupdate -radix decimal  /tb_carried_draw/Xend
add wave -noupdate -radix decimal  /tb_carried_draw/Yend
add wave -noupdate -radix unsigned /tb_carried_draw/pixelX
add wave -noupdate -radix unsigned /tb_carried_draw/pixelY
add wave -noupdate -divider {INSIDE carried_draw}
add wave -noupdate -radix decimal  /tb_carried_draw/dut/boxX
add wave -noupdate -radix decimal  /tb_carried_draw/dut/boxY
add wave -noupdate -radix decimal  /tb_carried_draw/ref_left
add wave -noupdate -radix decimal  /tb_carried_draw/ref_top
add wave -noupdate -radix unsigned /tb_carried_draw/dut/boxSize
add wave -noupdate                 /tb_carried_draw/dut/boxOn
add wave -noupdate                 /tb_carried_draw/dut/inBox
add wave -noupdate -divider {OUTPUTS vs MODEL}
add wave -noupdate -color Orange   /tb_carried_draw/drawingRequest
add wave -noupdate -radix hex      /tb_carried_draw/RGBout
add wave -noupdate -radix hex      /tb_carried_draw/expected
add wave -noupdate -radix unsigned /tb_carried_draw/drawn
add wave -noupdate -radix unsigned -color Red /tb_carried_draw/mismatches
configure wave -namecolwidth 230 -valuecolwidth 100 -timelineunits us
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
echo "    Images: frames/carry_*.bmp   Checklist: CHECKLIST_carry.md   zt 1..5 / zt 0"
