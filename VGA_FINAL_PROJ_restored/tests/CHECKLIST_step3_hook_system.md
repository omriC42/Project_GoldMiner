# Step 3 - hook_move + hook_draw together: what to check BY EYE

Expected numbers come from the Python model (tests/model_system.py).
Expected pictures: tests/expected_hook_system_sequence.png (27 small images, in order).
Frame numbers: watch frame_no in the FRAMES group (the sim does not run at real speed:
a normal frame is ~400 clocks, a frame with an image is ~307,000 clocks - so on the time
axis image frames look long; use frame_no, not time, to compare with this table).

## Key moments (frame_no)
| frame_no | what happens | hookState | values |
|---|---|---|---|
| 1 | T1: first frame after reset | SWING | angle 87..90, R 40 |
| 29 | T2: swing reaches 0 deg | SWING | angle 0 |
| ~90 | T2: swing reaches 180 deg | SWING | angle 180 |
| ~149 | T2 ends (full swing = 120 frames = 1.65 s) | SWING | meas_swing_period_s = 1.65 |
| ~169 | T3: key 2 pressed at 57 deg | SWING -> SHOOT | shoot_key pulse |
| ~291 | T3: tip hits the FLOOR | SHOOT -> RETRACT | tip (523, 478), R 375, hitBorder pulse |
| ~373 | T3: back | RETRACT -> SWING | R 40, angle still 57 |
| ~383 | T4: key 2 at 87 deg, gold block at x 300..340, y 330..360 | SWING -> SHOOT | gold_on = 1 |
| ~427 | T4: CLAW TOUCHES GOLD | SHOOT -> RETRACT | tipCollision pulse, tip (328, 325), R 161 |
| ~457 | T4: back | RETRACT -> SWING | |
| 457..587 | T5: small gold under the origin, rope sweeps over it | SWING all the time | rope_gold_frames ~28, tip_gold_px 0, collisions 0 |

## Shapes to see in the waves (zt n)
* T2 (zt 2): angle_deg = one triangle 0 -> 180 -> 0. R = flat line at 40. Xend/Yend follow a half circle.
* T3 (zt 3): angle_deg FLAT (57) for the whole test. R = rising straight ramp up to ~375,
  then falling ramp (faster, steeper) back to 40. Yend rises to 478 then falls. hitBorder
  pulses exactly at the top of the R ramp, at the same moment hookState goes SHOOT -> RETRACT.
* T4 (zt 4): R ramp up to ~161 only (much lower than T3 - stopped by gold, not the floor).
  Zoom on the top of the ramp: inside the CLAW WINDOW scan, goldDR and tipDR are both high
  on the same clock -> tipCollision (red) one-clock pulse -> on the next clock hookState = RETRACT.
* T5 (zt 5): during ORIGIN AREA scans, goldDR and drawingRequest are high together on some
  clocks (the rope crossing the gold) but tipDR is never high together with goldDR,
  tipCollision stays FLAT, hookState stays SWING.
* Whole run: chk_fail flat, nFail 0, scan_extra 0 after every image (snap pulses).

## The images: tests/frames/seq_001_... to seq_027_...
Open seq_001 in Windows Photos and press the right arrow key to flip through them in order.
Compare with expected_hook_system_sequence.png:
* T1/T2 (seq 1-9): short rope (40 px) under the origin, claw moving around a half circle.
* T3: rope getting longer along ONE straight line at ~57 deg down-right, tip reaching the
  bottom edge, then getting shorter along the SAME line.
* T4: yellow gold block below; rope going straight down; the image taken at the catch shows
  the claw's prongs sitting on the top edge of the gold; then the rope shortens.
* T5: short rope crossing the small yellow square right under the origin (rope drawn over
  the gold) - and the hook keeps swinging.
* Never: a bent or broken rope, a claw away from the rope end, pixels drawn elsewhere.
