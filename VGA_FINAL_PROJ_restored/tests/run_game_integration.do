# run_game_integration.do - Step 8.5: the hook inside the game (GUI mode, nothing closes by itself)
# Usage:  cd <project>/tests   then   do run_game_integration.do        (expect VERSION 8.5.6)
# To run again after ANY file change: the full  do run_game_integration.do  (it recompiles).
onbreak {resume}
file mkdir frames
catch {quit -sim}
set LIB lib_game_integration
if {![file exists $LIB/_info]} {catch {file delete -force $LIB}; vlib $LIB}
vlog -work $LIB -sv ../RTL/VGA/hook_params.sv ../RTL/VGA/game_params.sv ../RTL/VGA/hook_move.sv ../RTL/VGA/hook_draw.sv \
     ../RTL/VGA/hook_block.sv ../RTL/VGA/miner_move.sv ../RTL/VGA/square_object.sv \
     ../RTL/VGA/minerBitMap.sv ../RTL/VGA/dust_draw.sv ../RTL/VGA/ObjectsMatrixBitMap.sv \
     ../RTL/VGA/game_hud.sv ../RTL/VGA/objects_mux.sv tb_game_integration.sv
vsim -voptargs=+acc $LIB.tb_game_integration
radix define HookState {2'd0 "SWING", 2'd1 "SHOOT", 2'd2 "RETRACT", -default unsigned}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {TEST PROGRESS}
add wave -noupdate -radix ascii -color Yellow /tb_game_integration/test_name
add wave -noupdate -radix ascii               /tb_game_integration/chk_name
add wave -noupdate -color Green               /tb_game_integration/chk_pass
add wave -noupdate -color Red                 /tb_game_integration/chk_fail
add wave -noupdate -radix unsigned            /tb_game_integration/nPass
add wave -noupdate -radix unsigned -color Red /tb_game_integration/nFail
add wave -noupdate -divider {KEYS (player)}
add wave -noupdate -color Cyan    /tb_game_integration/key2
add wave -noupdate -color Cyan    /tb_game_integration/key4
add wave -noupdate -color Cyan    /tb_game_integration/key6
add wave -noupdate -divider {MINER}
add wave -noupdate -radix decimal -format Analog-Step -height 60 -min 0 -max 640 -color Magenta /tb_game_integration/minerX
add wave -noupdate -radix decimal -format Analog-Step -height 40 -min -60 -max 60 /tb_game_integration/minerXspeed
add wave -noupdate                 /tb_game_integration/minerMoving
add wave -noupdate -color Orange   /tb_game_integration/hookBusy
add wave -noupdate -divider {HOOK}
add wave -noupdate -radix HookState -color Yellow /tb_game_integration/hookState
add wave -noupdate -radix decimal -format Analog-Step -height 60 -min 0 -max 180 -color Cyan /tb_game_integration/angle_deg
add wave -noupdate -radix unsigned -format Analog-Step -height 60 -min 0 -max 350 -color Orange /tb_game_integration/hb/R
add wave -noupdate -radix decimal /tb_game_integration/ropeX0
add wave -noupdate -radix decimal /tb_game_integration/ropeY0
add wave -noupdate -radix decimal /tb_game_integration/hb/Xend
add wave -noupdate -radix decimal /tb_game_integration/hb/Yend
add wave -noupdate -divider {CATCH + SCORE}
add wave -noupdate -color Cyan     /tb_game_integration/hb/tipDR_d
add wave -noupdate -color Gold     /tb_game_integration/goldDR
add wave -noupdate -color Red      /tb_game_integration/hookCatch
add wave -noupdate -color Orange   /tb_game_integration/goldCollected
add wave -noupdate -radix unsigned /tb_game_integration/goldValue
add wave -noupdate -radix unsigned /tb_game_integration/goldType
add wave -noupdate -radix unsigned /tb_game_integration/hb/caughtType
add wave -noupdate -radix unsigned /tb_game_integration/hb/retractStep
add wave -noupdate -radix unsigned -format Analog-Step -height 50 -min 0 -max 100 -color Green /tb_game_integration/score
add wave -noupdate -radix unsigned /tb_game_integration/n_collect
add wave -noupdate -divider {TARGET}
add wave -noupdate -radix unsigned /tb_game_integration/tgt_row
add wave -noupdate -radix unsigned /tb_game_integration/tgt_col
add wave -noupdate -radix unsigned /tb_game_integration/tgt_value
add wave -noupdate -radix unsigned /tb_game_integration/tgt_cx
add wave -noupdate -divider {SCAN}
add wave -noupdate                 /tb_game_integration/clk
add wave -noupdate -color Yellow   /tb_game_integration/sof
add wave -noupdate -radix unsigned /tb_game_integration/frame_no
add wave -noupdate -radix ascii    /tb_game_integration/scan_kind
add wave -noupdate -radix unsigned /tb_game_integration/pixelX
add wave -noupdate -radix unsigned /tb_game_integration/pixelY
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
echo "=== Simulation is PAUSED, nothing was closed. ===   Images: frames/game_*.bmp   zt 1..7 / zt 0"
