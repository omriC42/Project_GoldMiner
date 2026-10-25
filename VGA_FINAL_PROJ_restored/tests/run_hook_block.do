# run_hook_block.do - Step 4: hook_block wrapper, GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_hook_block.do        (expect VERSION 4.5.1)
# To run again after ANY file change: the full  do run_hook_block.do  (it recompiles).
# 'restart -f ; run -all' does NOT recompile.
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_hook_block
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv +incdir+../RTL/VGA ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv ../RTL/VGA/hook_draw.sv \
     ../RTL/VGA/carried_draw.sv ../RTL/VGA/hook_block.sv tb_hook_block.sv
vsim -voptargs=+acc $LIB.tb_hook_block

radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_hook_block/test_name
add wave -noupdate -radix ascii               /tb_hook_block/chk_name
add wave -noupdate -color Green               /tb_hook_block/chk_pass
add wave -noupdate -color Red                 /tb_hook_block/chk_fail
add wave -noupdate -radix unsigned            /tb_hook_block/nPass
add wave -noupdate -radix unsigned -color Red /tb_hook_block/nFail
add wave -noupdate -divider {INPUTS}
add wave -noupdate                 /tb_hook_block/clk
add wave -noupdate                 /tb_hook_block/resetN
add wave -noupdate -color Yellow   /tb_hook_block/sof
add wave -noupdate -radix decimal  /tb_hook_block/minerX
add wave -noupdate -radix decimal  /tb_hook_block/minerY
add wave -noupdate -color Orange   /tb_hook_block/minerMoving
add wave -noupdate -color Cyan     /tb_hook_block/shoot_key
add wave -noupdate                 /tb_hook_block/tipCollision
add wave -noupdate -color Magenta  /tb_hook_block/freeze
add wave -noupdate -color Orange   /tb_hook_block/newLevel
add wave -noupdate -color Red      /tb_hook_block/hookCatch
add wave -noupdate -radix unsigned /tb_hook_block/n_hookCatch
add wave -noupdate -radix unsigned /tb_hook_block/catchType
add wave -noupdate -divider {INSIDE hook_block}
add wave -noupdate -radix decimal  /tb_hook_block/origin_x
add wave -noupdate -radix decimal  /tb_hook_block/origin_y
add wave -noupdate                 /tb_hook_block/dut/shoot_key_d
add wave -noupdate -color Cyan     /tb_hook_block/dut/shoot_req
add wave -noupdate -divider {OUTPUTS}
add wave -noupdate -radix HookState -color Yellow /tb_hook_block/hookState
add wave -noupdate -color Red      /tb_hook_block/hookBusy
add wave -noupdate                 /tb_hook_block/hookDR
add wave -noupdate                 /tb_hook_block/tipDR
add wave -noupdate -radix hex      /tb_hook_block/hookRGB
add wave -noupdate -divider {CARRY + SCORE AT THE TOP (4.4)}
add wave -noupdate -color Gold     /tb_hook_block/goldDR_tb
add wave -noupdate -color Red      /tb_hook_block/hookCatch
add wave -noupdate                 /tb_hook_block/dut/caught
add wave -noupdate -radix unsigned /tb_hook_block/dut/caughtType
add wave -noupdate                 /tb_hook_block/dut/carryShow
add wave -noupdate -color Gold     /tb_hook_block/dut/carryDR
add wave -noupdate -color Green    /tb_hook_block/deliverPulse
add wave -noupdate -radix unsigned /tb_hook_block/deliverValue
add wave -noupdate -radix unsigned /tb_hook_block/n_deliver
add wave -noupdate -radix unsigned /tb_hook_block/n_carry
add wave -noupdate -radix unsigned -color Red /tb_hook_block/n_order_bad
add wave -noupdate -divider {HOOK MOTION}
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 180 -color Cyan /tb_hook_block/angle_deg
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 300 -color Orange /tb_hook_block/dut/R
add wave -noupdate -radix decimal /tb_hook_block/tip_dx
add wave -noupdate -radix decimal /tb_hook_block/tip_dy
add wave -noupdate -radix decimal /tb_hook_block/scan_extra
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
echo "    Images: frames/block_*.bmp   Checklist: CHECKLIST_step4_hook_block.md   zt 1..11 / zt 0"
