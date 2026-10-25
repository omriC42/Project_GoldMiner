# run_game_sound.do - Step 11: game sounds (game_sound + melody_player_1 + GameJukeBox), GUI mode
# Usage:  cd <project>/tests   then   do run_game_sound.do        (expect VERSION 11.1)
# To run again after ANY file change: the full  do run_game_sound.do  (it recompiles).
onbreak {resume}
catch {quit -sim}
set LIB lib_game_sound
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/AUDIO/Mili_sec_counter.sv \
     ../RTL/AUDIO/GameJukeBox.sv ../RTL/AUDIO/melody_player_1.sv ../RTL/AUDIO/game_sound.sv tb_game_sound.sv
vsim -voptargs=+acc $LIB.tb_game_sound

radix define Sound  {4'd0 "none", 4'd1 "CATCH", 4'd2 "MONEY", 4'd3 "LEVEL", 4'd4 "GAMEOVER", -default unsigned}
radix define Note   {4'd0 "do", 4'd1 "do#", 4'd2 "re", 4'd3 "re#", 4'd4 "mi", 4'd5 "fa", 4'd6 "fa#", 4'd7 "sol", 4'd8 "sol#", 4'd9 "la", 4'd10 "la#", 4'd11 "si", 4'd12 "DO", 4'd13 "DO#", 4'd14 "RE", 4'd15 "rest", -default unsigned}
radix define Player {3'd0 "idle", 3'd1 "load", 3'd2 "PLAY", 3'd3 "gap", 3'd4 "ended", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_game_sound/test_name
add wave -noupdate -radix ascii               /tb_game_sound/chk_name
add wave -noupdate -color Green               /tb_game_sound/chk_pass
add wave -noupdate -color Red                 /tb_game_sound/chk_fail
add wave -noupdate -radix unsigned            /tb_game_sound/nPass
add wave -noupdate -radix unsigned -color Red /tb_game_sound/nFail
add wave -noupdate -divider {GAME EVENTS (inputs of game_sound)}
add wave -noupdate                 /tb_game_sound/gameResetN
add wave -noupdate -color Gold     /tb_game_sound/objectCollected
add wave -noupdate -color Green    /tb_game_sound/deliverPulse
add wave -noupdate -color Cyan     /tb_game_sound/newLevel
add wave -noupdate -color Red      /tb_game_sound/gameOver
add wave -noupdate -color Magenta  /tb_game_sound/soundOn
add wave -noupdate -divider {game_sound -> melody_player_1}
add wave -noupdate -color Orange   /tb_game_sound/soundStart
add wave -noupdate -radix Sound -color Orange /tb_game_sound/soundSelect
add wave -noupdate -color Magenta  /tb_game_sound/offStart
add wave -noupdate -divider {PLAYER (what you hear)}
add wave -noupdate -radix Player   /tb_game_sound/player/SM_Maestro
add wave -noupdate -radix unsigned /tb_game_sound/player/noteIndex
add wave -noupdate -radix Note -color Cyan /tb_game_sound/tone
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 15 -color Cyan /tb_game_sound/cur_pitch
add wave -noupdate -color Green    /tb_game_sound/EnableSound
add wave -noupdate -radix unsigned /tb_game_sound/player/beat_duration
add wave -noupdate -radix unsigned /tb_game_sound/player/note_length
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 70 /tb_game_sound/player/noteTimeCounter
add wave -noupdate                 /tb_game_sound/tick
add wave -noupdate -color Yellow   /tb_game_sound/melodyEnded
add wave -noupdate -divider {LOG}
add wave -noupdate -radix unsigned /tb_game_sound/log_n
add wave -noupdate -radix unsigned /tb_game_sound/gap_n
add wave -noupdate -radix unsigned /tb_game_sound/n_start
add wave -noupdate -radix unsigned /tb_game_sound/n_off_start
add wave -noupdate                 /tb_game_sound/clk
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Checklist: CHECKLIST_step11_sound.md   zt 1..6 / zt 0"
