# run_mux_hook.do - Step 6+8: objects_mux with the hook + hook_block, GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_mux_hook.do        (expect VERSION 6.4)
# To run again after ANY file change: the full  do run_mux_hook.do  (it recompiles).
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_mux_hook
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv ../RTL/VGA/hook_draw.sv \
     ../RTL/VGA/hook_block.sv ../RTL/VGA/objects_mux.sv tb_mux_hook.sv
vsim -voptargs=+acc $LIB.tb_mux_hook
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_mux_hook/test_name
add wave -noupdate -radix ascii               /tb_mux_hook/chk_name
add wave -noupdate -color Green               /tb_mux_hook/chk_pass
add wave -noupdate -color Red                 /tb_mux_hook/chk_fail
add wave -noupdate -radix unsigned            /tb_mux_hook/nPass
add wave -noupdate -radix unsigned -color Red /tb_mux_hook/nFail
add wave -noupdate -divider {T1 PRIORITY}
add wave -noupdate -radix unsigned /tb_mux_hook/combo
add wave -noupdate -color Cyan   /tb_mux_hook/smileyDR
add wave -noupdate -color Orange /tb_mux_hook/mux_hookDR
add wave -noupdate               /tb_mux_hook/dustDR
add wave -noupdate               /tb_mux_hook/timerDR
add wave -noupdate -color Gold   /tb_mux_hook/goldDR
add wave -noupdate               /tb_mux_hook/bgDR
add wave -noupdate -radix hex    /tb_mux_hook/expected
add wave -noupdate -radix hex -color Yellow /tb_mux_hook/RGBOut
add wave -noupdate -radix unsigned -color Red /tb_mux_hook/mismatches
add wave -noupdate -divider {T2 FRAME}
add wave -noupdate -radix unsigned /tb_mux_hook/pixelX
add wave -noupdate -radix unsigned /tb_mux_hook/pixelY
add wave -noupdate -color Orange /tb_mux_hook/hb_DR
add wave -noupdate -radix hex    /tb_mux_hook/hb_RGB
add wave -noupdate               /tb_mux_hook/tipDR
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Image: frames/top_mux_frame.bmp   zt 1 / zt 2 / zt 0"
