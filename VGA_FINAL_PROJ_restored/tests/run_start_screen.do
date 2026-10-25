# run_start_screen.do - Step 14: drawing of the opening + settings screens (start_screen.sv), GUI mode
# Usage:  cd <project>/tests   then   do run_start_screen.do        (expect VERSION 11.0)
# To run again after ANY file change (also new pictures from make_menu_pictures.py): the full  do run_start_screen.do
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_start_screen
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv +incdir+../RTL/VGA ../RTL/VGA/start_screen.sv tb_start_screen.sv
vsim -voptargs=+acc $LIB.tb_start_screen
radix define Screen {2'd0 "OPENING", 2'd1 "SETTINGS", 2'd2 "PLAYING", -default unsigned}
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
add wave -noupdate -radix Screen -color Yellow /tb_start_screen/screen
add wave -noupdate -radix unsigned /tb_start_screen/cursor
add wave -noupdate -radix unsigned /tb_start_screen/difficulty
add wave -noupdate -radix unsigned /tb_start_screen/timeSel
add wave -noupdate                 /tb_start_screen/soundOn
add wave -noupdate                 /tb_start_screen/cheatsOn
add wave -noupdate -radix unsigned /tb_start_screen/pixelX
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 480 /tb_start_screen/pixelY
add wave -noupdate -divider {DRAWING}
add wave -noupdate -radix unsigned /tb_start_screen/dut/imgAddr
add wave -noupdate -radix unsigned /tb_start_screen/dut/setAddr
add wave -noupdate -radix hex      /tb_start_screen/dut/imagePixel
add wave -noupdate -radix hex      /tb_start_screen/dut/setPixel
add wave -noupdate -color Yellow   /tb_start_screen/dut/onArrow
add wave -noupdate -color Green    /tb_start_screen/dut/onFrame
add wave -noupdate                 /tb_start_screen/dut/overlayOn
add wave -noupdate -radix hex      /tb_start_screen/RGBOut
add wave -noupdate -radix hex      /tb_start_screen/expected
add wave -noupdate -radix unsigned -color Red /tb_start_screen/mismatches
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Images: frames/menu_*.bmp   Checklist: CHECKLIST_start_screen.md   zt 1..5 / zt 0"
