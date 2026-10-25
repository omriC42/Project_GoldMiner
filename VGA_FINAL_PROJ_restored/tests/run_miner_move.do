# run_miner_move.do - Step 5: miner movement + hook lock, GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_miner_move.do        (expect VERSION 5.3)
# To run again after ANY file change: the full  do run_miner_move.do  (it recompiles).
onbreak {resume}
catch {quit -sim}
set LIB lib_miner_move
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/miner_move.sv tb_miner_move.sv
vsim -voptargs=+acc $LIB.tb_miner_move
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_miner_move/test_name
add wave -noupdate -radix ascii               /tb_miner_move/chk_name
add wave -noupdate -color Green               /tb_miner_move/chk_pass
add wave -noupdate -color Red                 /tb_miner_move/chk_fail
add wave -noupdate -radix unsigned            /tb_miner_move/nPass
add wave -noupdate -radix unsigned -color Red /tb_miner_move/nFail
add wave -noupdate -divider {INPUTS}
add wave -noupdate                /tb_miner_move/clk
add wave -noupdate -color Yellow  /tb_miner_move/sof
add wave -noupdate -color Cyan    /tb_miner_move/key4
add wave -noupdate -color Cyan    /tb_miner_move/key6
add wave -noupdate -color Red     /tb_miner_move/hookBusy
add wave -noupdate -divider {MINER}
add wave -noupdate -color Orange  /tb_miner_move/minerMoving
add wave -noupdate -color Gray70  /tb_miner_move/movingLeft
add wave -noupdate -color Gray70  /tb_miner_move/movingRight
add wave -noupdate                /tb_miner_move/dut/SM_Motion
add wave -noupdate -radix decimal -format Analog-Step -height 60 -min -64 -max 64 -color Magenta /tb_miner_move/xspeed
add wave -noupdate -radix decimal -format Analog-Step -height 80 -min 0 -max 640 -color Cyan /tb_miner_move/minerX
add wave -noupdate -radix decimal /tb_miner_move/topLeftX
add wave -noupdate -radix decimal /tb_miner_move/topLeftY
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Checklist: CHECKLIST_step5_miner.md   zt 1..6 / zt 0"
