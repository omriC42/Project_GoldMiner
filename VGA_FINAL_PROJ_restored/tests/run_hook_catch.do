# run_hook_catch.do - Step 7: catching gold with the claw, GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_hook_catch.do        (expect VERSION 7.4.2)
# To run again after ANY file change: the full  do run_hook_catch.do  (it recompiles).
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_hook_catch
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv +incdir+../RTL/VGA ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv ../RTL/VGA/hook_draw.sv \
     ../RTL/VGA/carried_draw.sv ../RTL/VGA/hook_block.sv ../RTL/VGA/objects_mux.sv ../RTL/VGA/square_object.sv \
     ../RTL/VGA/ObjectsMatrixBitMap.sv tb_hook_catch.sv
vsim -voptargs=+acc $LIB.tb_hook_catch
radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_hook_catch/test_name
add wave -noupdate -radix ascii               /tb_hook_catch/chk_name
add wave -noupdate -color Green               /tb_hook_catch/chk_pass
add wave -noupdate -color Red                 /tb_hook_catch/chk_fail
add wave -noupdate -radix unsigned            /tb_hook_catch/nPass
add wave -noupdate -radix unsigned -color Red /tb_hook_catch/nFail
add wave -noupdate -divider {SCAN}
add wave -noupdate                 /tb_hook_catch/clk
add wave -noupdate -color Yellow   /tb_hook_catch/sof
add wave -noupdate -radix unsigned /tb_hook_catch/frame_no
add wave -noupdate -radix ascii    /tb_hook_catch/scan_kind
add wave -noupdate -radix unsigned /tb_hook_catch/pixelX
add wave -noupdate -radix unsigned /tb_hook_catch/pixelY
add wave -noupdate -divider {THE CATCH (pixel alignment)}
add wave -noupdate -color Cyan     /tb_hook_catch/tipDR
add wave -noupdate -color Cyan     /tb_hook_catch/hb/tipDR_d
add wave -noupdate -color Gold     /tb_hook_catch/goldDR
add wave -noupdate -radix hex      /tb_hook_catch/goldRGB
add wave -noupdate -color Red      /tb_hook_catch/hookCatch
add wave -noupdate -color Orange   /tb_hook_catch/collectPulse
add wave -noupdate -radix unsigned /tb_hook_catch/collectValue
add wave -noupdate -radix unsigned /tb_hook_catch/n_hookCatch
add wave -noupdate -color Green    /tb_hook_catch/deliverPulse
add wave -noupdate -radix unsigned /tb_hook_catch/deliverValue
add wave -noupdate                 /tb_hook_catch/hb/carryDR
add wave -noupdate -radix unsigned /tb_hook_catch/n_collect
add wave -noupdate -radix unsigned /tb_hook_catch/lat_gold
add wave -noupdate -radix unsigned /tb_hook_catch/lat_tip
add wave -noupdate -divider {HOOK}
add wave -noupdate -color Cyan     /tb_hook_catch/shoot_key
add wave -noupdate -color Magenta  /tb_hook_catch/force_angle
add wave -noupdate -radix HookState -color Yellow /tb_hook_catch/hookState
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 450 -color Orange /tb_hook_catch/hb/R
add wave -noupdate -radix decimal /tb_hook_catch/hb/Xend
add wave -noupdate -radix decimal /tb_hook_catch/hb/Yend
add wave -noupdate -radix decimal /tb_hook_catch/minerX
add wave -noupdate -divider {TARGET}
add wave -noupdate -radix unsigned /tb_hook_catch/tgt_row
add wave -noupdate -radix unsigned /tb_hook_catch/tgt_col
add wave -noupdate -radix unsigned /tb_hook_catch/tgt_type
add wave -noupdate -radix unsigned /tb_hook_catch/tgt_value
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Images: frames/catch_*.bmp   zt 1..4 / zt 0"
