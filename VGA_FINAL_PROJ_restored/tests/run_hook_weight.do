# run_hook_weight.do - Step 9: weight + game_params.sv, GUI mode (nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_hook_weight.do        (expect VERSION 9.9)
# Run it again after you change game_params.sv: it checks your NEW numbers.
onbreak {resume}
catch {quit -sim}
set LIB lib_hook_weight
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv +incdir+../RTL/VGA ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv \
     ../RTL/VGA/hook_draw.sv ../RTL/VGA/carried_draw.sv ../RTL/VGA/hook_block.sv ../RTL/VGA/ObjectsMatrixBitMap.sv \
     ../RTL/VGA/hud_digit.sv ../RTL/VGA/bcd_add3.sv ../RTL/VGA/hud_number.sv ../RTL/VGA/game_hud.sv tb_hook_weight.sv
vsim -voptargs=+acc $LIB.tb_hook_weight
radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}
radix define ObjType {3'd0 "nothing", 3'd1 "gold S", 3'd2 "gold M", 3'd3 "gold L", 3'd4 "rock S", 3'd5 "rock M", 3'd6 "rock L", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_hook_weight/test_name
add wave -noupdate -radix ascii               /tb_hook_weight/chk_name
add wave -noupdate -color Green               /tb_hook_weight/chk_pass
add wave -noupdate -color Red                 /tb_hook_weight/chk_fail
add wave -noupdate -radix unsigned            /tb_hook_weight/nPass
add wave -noupdate -radix unsigned -color Red /tb_hook_weight/nFail
add wave -noupdate -divider {HOOK + WEIGHT}
add wave -noupdate -radix unsigned -color Cyan  /tb_hook_weight/cur_type
add wave -noupdate -radix ObjType               /tb_hook_weight/catchType
add wave -noupdate -color Cyan                  /tb_hook_weight/shoot_key
add wave -noupdate -radix HookState -color Yellow /tb_hook_weight/hookState
add wave -noupdate -radix decimal -format Analog-Step -height 50 -min 0 -max 180 -color Cyan /tb_hook_weight/angle_deg
add wave -noupdate -radix unsigned -format Analog-Step -height 80 -min 0 -max 350 -color Orange /tb_hook_weight/R
add wave -noupdate -color Gold                  /tb_hook_weight/goldDR
add wave -noupdate -color Red                   /tb_hook_weight/hookCatch
add wave -noupdate                              /tb_hook_weight/hb/caught
add wave -noupdate -radix unsigned              /tb_hook_weight/caughtType
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 300 -color Magenta /tb_hook_weight/retractStep
add wave -noupdate -radix decimal               /tb_hook_weight/meas_pull_px_s
add wave -noupdate -radix decimal               /tb_hook_weight/exp_pull_px_s
add wave -noupdate -divider {SCORE AT THE TOP (9.5)}
add wave -noupdate -color Green                 /tb_hook_weight/dPulse
add wave -noupdate -radix unsigned              /tb_hook_weight/dValue
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 150 -color Gold /tb_hook_weight/top_score
add wave -noupdate -radix unsigned              /tb_hook_weight/n_deliver
add wave -noupdate                              /tb_hook_weight/hb/carryDR
add wave -noupdate -divider {GAME HUD (T5: the HUD of cur_diff)}
add wave -noupdate -radix unsigned -color Cyan /tb_hook_weight/cur_diff
add wave -noupdate                 /tb_hook_weight/cheatN
add wave -noupdate -radix unsigned -format Analog-Step -height 40 -min 0 -max 120 -color Green /tb_hook_weight/seconds
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 300 -color Gold /tb_hook_weight/score
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 300 -color Red /tb_hook_weight/target
add wave -noupdate -radix unsigned /tb_hook_weight/target_digits
add wave -noupdate -radix unsigned /tb_hook_weight/level
add wave -noupdate -radix unsigned /tb_hook_weight/hudE/tgtH
add wave -noupdate -radix unsigned /tb_hook_weight/hudE/tgtT
add wave -noupdate -radix unsigned /tb_hook_weight/hudE/tgtO
add wave -noupdate -color Orange   /tb_hook_weight/hp
add wave -noupdate -color Magenta  /tb_hook_weight/ck
add wave -noupdate -color Green    /tb_hook_weight/cur_newLevel
add wave -noupdate -color Red      /tb_hook_weight/cur_gameOver
add wave -noupdate -divider {SETTINGS INPUTS (T7, T8)}
add wave -noupdate -radix unsigned -color Cyan /tb_hook_weight/hbDiff
add wave -noupdate -radix unsigned -color Cyan /tb_hook_weight/gDiff
add wave -noupdate -radix unsigned /tb_hook_weight/n_gold
add wave -noupdate -radix unsigned /tb_hook_weight/n_obj
add wave -noupdate -divider {SCAN}
add wave -noupdate                 /tb_hook_weight/clk
add wave -noupdate -color Yellow   /tb_hook_weight/sof
add wave -noupdate -radix unsigned /tb_hook_weight/frame_no
add wave -noupdate -radix unsigned /tb_hook_weight/pixelX
add wave -noupdate -radix unsigned /tb_hook_weight/pixelY
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
echo "=== Simulation is PAUSED, nothing was closed. ===   zt 1..8 / zt 0"
