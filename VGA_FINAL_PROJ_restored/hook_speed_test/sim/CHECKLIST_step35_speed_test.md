# Step 3.5 - speed test: what to check BY EYE

## A. ModelSim (hook_speed_test/sim, do run_speed_test_core.do) - expect VERSION 3.5.2, 23 PASS
* First Transcript line: ##### tb_hook_speed_test_core VERSION 3.5.2
* zt 1: greenLight goes high right after resetN; yellow/red low.
* zt 2: use_fast_sof = 0, capturing high for one whole VGA frame (~13.8 ms at 31.5 MHz).
  vgaX/vgaY count the screen; RGB changes to AC on grid columns, E0 on x=2/637, FF at the
  origin square, 49/B6 where the hook is. Image frames/screen_1_swing.bmp must look like
  expected_screen_1_swing.png (brown, grid, red walls+floor, white square, short rope + claw).
* zt 3: key_shoot pulse -> yellowLight on (green off); R ramps up; key_catch pulse -> redLight
  on the very next clock; R ramps down; greenLight again when R = 40.
* zt 4: key_pause pulse -> paused = 1 and the angle curve goes FLAT; key_shoot while paused
  changes nothing; second key_pause -> curve moves again; key_reset pulse -> hookResetN low
  for ~10 clocks, R jumps back to 40, angle back to 90, greenLight.
* zt 5: frames/screen_2_shoot.bmp: a LONG rope (R > 150) from the white square to the claw.
* Never: two lights on at the same time, RGB = 00 after reset, chk_fail pulses.

## B. Quartus compile (hook_speed_test.qpf)
Send Claude: the Flow Summary, the list of ERRORS (if any) and CRITICAL WARNINGS, and the
TimeQuest "Slow 1100mV 85C Model" Setup Summary.
* Expected: 0 errors. Normal warnings: unused TOP_KBD outputs, unused vgaAddress, I/O pins
  without output delays, PLL / qip version notes.
* Timing: the 31.5 MHz clock (name contains "u_pll" / "outclk") must have POSITIVE setup slack.
* Resources: a few hundred ALMs, about 4 DSP blocks (2 multipliers in hook_move, 2 in hook_draw), 0 memory bits.

## C. On the board (program output_files/hook_speed_test.sof)
Screen right after programming: brown background, faint grid every 100 px, thin red lines at
the left and right edge and near the bottom, small white square in the upper middle, the rope
hanging from it with the claw, swinging left and right. GREEN light on.
| What | How | Expected |
|---|---|---|
| Swing speed | stopwatch: 10 full swings (left->right->left = 1) | 16.5 s (15.5 - 17.5 ok) |
| Swing smoothness | watch the claw | smooth, no visible jumps; reaches horizontal on both sides |
| Shot straight down (shoot when the rope is vertical) | stopwatch from key 2 to the floor line | ~1.4 s, YELLOW light |
| Pull-back from the floor | stopwatch until the hook swings again | ~0.9 s, RED light, then GREEN |
| Shot to a corner (~60 deg) | | ~1.7 s down, ~1.1 s back, stays on ONE straight line |
| Key 2 held down | | one shot only; no second shot until you release and press again |
| Key 8 during a shot | | turns back immediately (RED) |
| Key 5 | | everything freezes (any state); 5 again continues |
| Key 0 | | hook back to hanging down, GREEN, rope short |
| Walls | shoot sideways near 0 / 180 deg | turns back at the red side lines |
If a speed feels wrong: change the number in ../RTL/VGA/hook_params.sv (SWING_DEG_PER_SEC,
SHOOT_PX_PER_SEC, RETRACT_EMPTY_PX_PER_SEC) and recompile only this small project.
