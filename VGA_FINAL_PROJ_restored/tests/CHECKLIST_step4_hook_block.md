# Step 4 - hook_block wrapper: what to check BY EYE
ModelSim: cd tests -> do run_hook_block.do -> first line must be VERSION 4.2 -> expect 18 PASS, 0 FAIL.

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
| T6 | two shots, catchWeight 0 then 63 | both pull-backs take the same number of frames (weights come in Step 9) |
Never: hookBusy = 1 while SWING; a shoot_req pulse while minerMoving = 1; chk_fail pulses.

## Quartus check of the MAIN project (Lab1Demo)
Open Lab1Demo.qpf -> Processing -> Start -> Start Analysis & Synthesis (about 1-3 min).
Expected: 0 errors. hook_block is not used in the top level yet, so Quartus may say it is
not part of the design hierarchy - that is fine. The game itself is unchanged.
Then tell Claude - it will read output_files/Lab1Demo.map.rpt directly.
