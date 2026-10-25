# run_game_hud.do - Step 12: game_hud without dividers / functions, GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_game_hud.do        (expect VERSION 12.1)
# To run again after ANY file change: the full  do run_game_hud.do  (it recompiles).
onbreak {resume}
catch {quit -sim}
set LIB lib_game_hud
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hud_digit.sv \
     ../RTL/VGA/game_hud.sv tb_game_hud.sv
vsim -voptargs=+acc $LIB.tb_game_hud

quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_game_hud/test_name
add wave -noupdate -radix ascii               /tb_game_hud/chk_name
add wave -noupdate -color Green               /tb_game_hud/chk_pass
add wave -noupdate -color Red                 /tb_game_hud/chk_fail
add wave -noupdate -radix unsigned            /tb_game_hud/nPass
add wave -noupdate -radix unsigned -color Red /tb_game_hud/nFail
add wave -noupdate -divider {SCORE: binary and digits}
add wave -noupdate -color Gold     /tb_game_hud/collectPulse
add wave -noupdate -radix unsigned /tb_game_hud/collectValue
add wave -noupdate -radix unsigned /tb_game_hud/hud/valT
add wave -noupdate -radix unsigned /tb_game_hud/hud/valO
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 1000 -color Gold /tb_game_hud/dollars_i
add wave -noupdate -radix unsigned /tb_game_hud/hud/dolH
add wave -noupdate -radix unsigned /tb_game_hud/hud/dolT
add wave -noupdate -radix unsigned /tb_game_hud/hud/dolO
add wave -noupdate -radix unsigned /tb_game_hud/model
add wave -noupdate -divider {LEVEL + TARGET}
add wave -noupdate -color Orange   /tb_game_hud/nextLevelKey
add wave -noupdate -radix unsigned /tb_game_hud/level_i
add wave -noupdate -radix unsigned /tb_game_hud/hud/lvlT
add wave -noupdate -radix unsigned /tb_game_hud/hud/lvlO
add wave -noupdate -radix unsigned /tb_game_hud/target_i
add wave -noupdate -radix unsigned /tb_game_hud/hud/tgtH
add wave -noupdate -radix unsigned /tb_game_hud/hud/tgtT
add wave -noupdate -radix unsigned /tb_game_hud/hud/tgtO
add wave -noupdate -divider {SETTINGS (T6/T7)}
add wave -noupdate -radix unsigned /tb_game_hud/hDiff
add wave -noupdate -radix unsigned /tb_game_hud/hTime
add wave -noupdate                 /tb_game_hud/hCheats
add wave -noupdate                 /tb_game_hud/hud/loadStart
add wave -noupdate -divider {CLOCK (T3: 90 s HUD)}
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 100 -color Green /tb_game_hud/csecs_i
add wave -noupdate -radix unsigned /tb_game_hud/hudC/minD
add wave -noupdate -radix unsigned /tb_game_hud/hudC/secT
add wave -noupdate -radix unsigned /tb_game_hud/hudC/secO
add wave -noupdate -divider {CHECKS}
add wave -noupdate -radix unsigned /tb_game_hud/dig_checks
add wave -noupdate -radix unsigned -color Red /tb_game_hud/dig_bad
add wave -noupdate -radix unsigned -color Red /tb_game_hud/pix_bad
add wave -noupdate -radix unsigned /tb_game_hud/pix_red
add wave -noupdate -radix unsigned /tb_game_hud/pixelX
add wave -noupdate -radix unsigned /tb_game_hud/pixelY
add wave -noupdate -radix hex      /tb_game_hud/hudRGB
add wave -noupdate -color Red      /tb_game_hud/gameOver
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Checklist: CHECKLIST_step12_hud.md   zt 1..7 / zt 0"
