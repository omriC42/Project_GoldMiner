# Step 4 - hook_block wrapper: what to check BY EYE
ModelSim: cd tests -> do run_hook_block.do -> first line must be VERSION 4.5.1 -> expect 46 PASS, 0 FAIL.

| Test (zt n) | Look at | Expected |
|---|---|---|
| T1 | origin_x / origin_y | 312 / 164 right after reset (miner 280,100 + 32,64). hookState SWING, hookBusy 0 |
| T2 | minerX jumps 280 -> 100 -> 500 | origin_x follows on the next clock: 132 ... 532. tip_dx/tip_dy do NOT jump when the miner jumps (the hook moves WITH the miner, same angle and length) |
| T2 images | frames/block_1_miner_left.bmp, block_2_miner_right.bmp | yellow square = where the miner is (drawn by the testbench only); the short rope hangs from the middle of its bottom edge; claw at the end |
| T3 | minerMoving high, shoot_key pulse | shoot_req stays 0, hookState stays SWING |
| T3 | shoot_key held high while minerMoving falls | still no shoot_req pulse, SWING |
| T3 | shoot_key released then pressed | ONE shoot_req pulse (1 clock) -> hookState SHOOT, hookBusy 1 |
| T4 | hookBusy | high for the whole SHOOT + RETRACT, low again exactly when hookState returns to SWING |
| T5 | freeze high | angle curve flat; resumes when freeze goes low |
| T6 | two shots ended by tipCollision (no gold), catchType 0 then 6 | both pull-backs take the same number of frames (catchType alone does not make the hook heavy); n_deliver stays 0 |
| T7 | 6 catches (catchType 1..6, goldDR on the claw pixel) | each: hookCatch -> caught = 1, caughtType = t, RETRACT; carryShow high for the whole pull-back |
| T7 | n_carry / n_claw / n_order_bad / n_or_bad | n_carry > 0 (object drawn), n_order_bad = 0 (claw always on top of the object), n_or_bad = 0 (hookDR = rope OR claw OR object) |
| T7 | deliverPulse (green) / deliverValue | ONE pulse when hookState returns to SWING, value = 12, 24, 36, 4, 8, 12 (game_params.sv) |
| T8 | empty pull-back (tipCollision) | carryShow stays 0, n_carry 0, no deliverPulse |
| T9 | during SHOOT | n_claw > 0, n_carry = 0 (nothing hangs on the claw on the way down) |
| T10 | freeze (magenta) high in the middle of a shot, goldDR pulses on the claw | hookCatch stays 0 (n_hookCatch does not move), R (orange) and angle flat for 20 frames, the key-2 pulse does nothing; after freeze drops R climbs again |
| T11 | newLevel (orange) pulse while R falls slowly with large gold | on the next clock: hookState SWING, R = 40, caught 0, carryShow 0, hookBusy 0; NO deliverPulse afterwards; then a new catch (small gold) delivers 12 normally |
Never: a hookCatch while freeze = 1; a deliverPulse after newLevel dropped the object; hookBusy = 1 while SWING; a shoot_req pulse while minerMoving = 1; a deliverPulse without a catch; two deliverPulses for one catch; chk_fail pulses.

## Quartus check of the MAIN project (Lab1Demo)
Open Lab1Demo.qpf -> Processing -> Start -> Start Analysis & Synthesis (about 1-3 min).
Expected: 0 errors. hook_block is inst41 in TOP_VGA_DEMO_KBD; since Oct 2026 it also holds
carried_draw (the object on the claw) and sends deliverPulse/deliverValue to game_hud (score at the top).
carried_draw includes RTL/VGA/object_sprites.svh - the qsf has SEARCH_PATH RTL/VGA for it.
Then tell Claude - it will read output_files/Lab1Demo.map.rpt directly.
