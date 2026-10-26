# run_game_hud_equiv.do - B10: new game_hud (decimal digits only) = old game_hud, clock by clock
# Usage:  cd <project>/tests   then   do run_game_hud_equiv.do        (expect VERSION 1.1)
# To run again after ANY file change: the full  do run_game_hud_equiv.do  (it recompiles).
onbreak {resume}
catch {quit -sim}
set LIB lib_game_hud_equiv
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/game_params.sv ../RTL/VGA/hud_digit.sv ../RTL/VGA/bcd_add3.sv ../RTL/VGA/hud_number.sv \
     ../RTL/VGA/game_hud.sv ref/game_hud_old.sv tb_game_hud_equiv.sv
vsim -voptargs=+acc $LIB.tb_game_hud_equiv

quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_game_hud_equiv/test_name
add wave -noupdate -radix ascii               /tb_game_hud_equiv/chk_name
add wave -noupdate -color Green               /tb_game_hud_equiv/chk_pass
add wave -noupdate -color Red                 /tb_game_hud_equiv/chk_fail
add wave -noupdate -radix unsigned            /tb_game_hud_equiv/nPass
add wave -noupdate -radix unsigned -color Red /tb_game_hud_equiv/nFail
add wave -noupdate -divider {COMPARISON}
add wave -noupdate -color Red      /tb_game_hud_equiv/diff_now
add wave -noupdate -radix unsigned /tb_game_hud_equiv/compared
add wave -noupdate -radix unsigned -color Red /tb_game_hud_equiv/diffs
add wave -noupdate -divider {INPUTS (the same for both)}
add wave -noupdate                 /tb_game_hud_equiv/resetN
add wave -noupdate -radix unsigned /tb_game_hud_equiv/difficulty
add wave -noupdate -radix unsigned /tb_game_hud_equiv/timeSel
add wave -noupdate                 /tb_game_hud_equiv/cheatsOn
add wave -noupdate -color Gold     /tb_game_hud_equiv/collectPulse
add wave -noupdate -radix unsigned /tb_game_hud_equiv/collectValue
add wave -noupdate -color Orange   /tb_game_hud_equiv/nextLevelKey
add wave -noupdate -color Orange   /tb_game_hud_equiv/gameOverKey
add wave -noupdate -divider {OLD vs NEW numbers}
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 1000 -color Gold /tb_game_hud_equiv/oDol
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 1000 -color Gold /tb_game_hud_equiv/nDol
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 1000 /tb_game_hud_equiv/oTgt
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 1000 /tb_game_hud_equiv/nTgt
add wave -noupdate -radix unsigned /tb_game_hud_equiv/oLvl
add wave -noupdate -radix unsigned /tb_game_hud_equiv/nLvl
add wave -noupdate -radix unsigned /tb_game_hud_equiv/oSec
add wave -noupdate -radix unsigned /tb_game_hud_equiv/nSec
add wave -noupdate -divider {OLD vs NEW outputs}
add wave -noupdate -color Red /tb_game_hud_equiv/oGameOver
add wave -noupdate -color Red /tb_game_hud_equiv/nGameOver
add wave -noupdate            /tb_game_hud_equiv/oLevelWon
add wave -noupdate            /tb_game_hud_equiv/nLevelWon
add wave -noupdate            /tb_game_hud_equiv/oNewLevel
add wave -noupdate            /tb_game_hud_equiv/nNewLevel
add wave -noupdate -radix hex /tb_game_hud_equiv/oRGB
add wave -noupdate -radix hex /tb_game_hud_equiv/nRGB
configure wave -namecolwidth 230 -valuecolwidth 100 -timelineunits us
update
run -all
if {[file exists test_windows.do]} {source test_windows.do}
proc zt {n} {
    global TW
    if {![info exists TW($n)]} {echo "no test $n"; return}
    wave zoom range "[lindex $TW($n) 0]ns" "[lindex $TW($n) 1]ns"
}
wave zoom range 0ns 200us
echo ""
echo "=== Simulation is PAUSED, nothing was closed. ===   Checklist: CHECKLIST_b10_hud.md   zt 1..2 / zt 0"
