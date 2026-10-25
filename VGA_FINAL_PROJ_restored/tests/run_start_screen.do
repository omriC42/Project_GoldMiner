# run_start_screen.do - opening screen as a picture (start_screen.hex), GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_start_screen.do        (expect VERSION 10.0)
# To run again after ANY file change (also a new start_screen.hex): the full  do run_start_screen.do
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_start_screen
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/start_screen.sv tb_start_screen.sv
vsim -voptargs=+acc $LIB.tb_start_screen
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_start_screen/test_name
add wave -noupdate -radix ascii               /tb_start_screen/chk_name
add wave -noupdate -color Green               /tb_start_screen/chk_pass
add wave -noupdate -color Red                 /tb_start_screen/chk_fail
add wave -noupdate -radix unsigned            /tb_start_screen/nPass
add wave -noupdate -radix unsigned -color Red /tb_start_screen/nFail
add wave -noupdate -divider {INPUTS}
add wave -noupdate                 /tb_start_screen/clk
add wave -noupdate                 /tb_start_screen/resetN
add wave -noupdate -color Cyan     /tb_start_screen/enterKey
add wave -noupdate -radix unsigned /tb_start_screen/pixelX
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 480 /tb_start_screen/pixelY
add wave -noupdate -divider {START SCREEN}
add wave -noupdate -color Yellow   /tb_start_screen/dut/state
add wave -noupdate -color Orange   /tb_start_screen/gameResetN
add wave -noupdate -radix unsigned /tb_start_screen/dut/imgAddr
add wave -noupdate -radix hex      /tb_start_screen/dut/imagePixel
add wave -noupdate -radix hex      /tb_start_screen/RGBOut
add wave -noupdate -radix hex      /tb_start_screen/expected
add wave -noupdate -radix unsigned -color Red /tb_start_screen/mismatches
add wave -noupdate -radix unsigned /tb_start_screen/yellow_px
configure wave -namecolwidth 220 -valuecolwidth 100 -timelineunits us
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Checklist: CHECKLIST_start_screen.md   zt 1..5 / zt 0"
