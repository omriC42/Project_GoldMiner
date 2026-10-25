# run_game_settings.do - Step 14: screens + settings (game_settings.sv), GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_game_settings.do        (expect VERSION 14.0)
# To run again after ANY file change: the full  do run_game_settings.do  (it recompiles).
onbreak {resume}
catch {quit -sim}
set LIB lib_game_settings
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/game_settings.sv tb_game_settings.sv
vsim -voptargs=+acc $LIB.tb_game_settings

radix define Screen {2'd0 "OPENING", 2'd1 "SETTINGS", 2'd2 "PLAYING", -default unsigned}
radix define Row    {2'd0 "DIFFICULTY", 2'd1 "TIME", 2'd2 "SOUND", 2'd3 "CHEATS", -default unsigned}
radix define Diff   {2'd0 "EASY", 2'd1 "NORMAL", 2'd2 "HARD", -default unsigned}
radix define Time   {2'd0 "30 S", 2'd1 "60 S", 2'd2 "90 S", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_game_settings/test_name
add wave -noupdate -radix ascii               /tb_game_settings/chk_name
add wave -noupdate -color Green               /tb_game_settings/chk_pass
add wave -noupdate -color Red                 /tb_game_settings/chk_fail
add wave -noupdate -radix unsigned            /tb_game_settings/nPass
add wave -noupdate -radix unsigned -color Red /tb_game_settings/nFail
add wave -noupdate -divider {KEYS}
add wave -noupdate                 /tb_game_settings/resetN
add wave -noupdate -color Cyan     /tb_game_settings/enterKey
add wave -noupdate -color Orange   /tb_game_settings/plusKey
add wave -noupdate                 /tb_game_settings/upKey
add wave -noupdate                 /tb_game_settings/downKey
add wave -noupdate                 /tb_game_settings/leftKey
add wave -noupdate                 /tb_game_settings/rightKey
add wave -noupdate -color Red      /tb_game_settings/gameOver
add wave -noupdate -divider {SCREENS + SETTINGS}
add wave -noupdate -radix Screen -color Yellow /tb_game_settings/screen
add wave -noupdate -color Orange   /tb_game_settings/gameResetN
add wave -noupdate -radix Row      /tb_game_settings/cursor
add wave -noupdate -radix Diff     /tb_game_settings/difficulty
add wave -noupdate -radix Time     /tb_game_settings/timeSel
add wave -noupdate                 /tb_game_settings/soundOn
add wave -noupdate                 /tb_game_settings/cheatsOn
add wave -noupdate -divider {ONE PRESS = ONE PULSE}
add wave -noupdate                 /tb_game_settings/dut/enterP
add wave -noupdate                 /tb_game_settings/dut/plusP
add wave -noupdate                 /tb_game_settings/dut/upP
add wave -noupdate                 /tb_game_settings/dut/downP
add wave -noupdate                 /tb_game_settings/dut/leftP
add wave -noupdate                 /tb_game_settings/dut/rightP
add wave -noupdate                 /tb_game_settings/clk
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Checklist: CHECKLIST_step14_settings.md   zt 1..8 / zt 0"
