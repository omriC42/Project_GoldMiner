# Step 5 - miner position + lock: what to check BY EYE
ModelSim: cd tests -> do run_miner_move.do -> first line VERSION 5.2 -> expect 14 PASS, 0 FAIL.

| zt | Look at | Expected |
|---|---|---|
| 1 | minerX | 280 after the first frames, topLeftY 100 |
| 2 | key6 high | minerMoving goes high at once; xspeed ramps up 0 -> 60 (staircase, +4 per frame); minerX curve rises, getting steeper. key6 low: minerMoving low at once; xspeed ramps DOWN to 0 (glide ~15 frames); minerX keeps rising a little then flat |
| 3 | hookBusy rises while key6 is held | xspeed drops to 0 at the very next frame (a vertical cliff, NOT a ramp); minerX FLAT for 30 frames although key6 stays high |
| 4 | key4 released, xspeed still negative (gliding), then hookBusy rises | xspeed jumps to 0 at once, minerX flat |
| 5 | hookBusy low, key4 high | xspeed ramps negative again, minerX falls |
| 6 | key4 held long | minerX falls to 2 and stays there (left border) |
Never: minerX changing while hookBusy = 1; xspeed ramp (instead of a jump) when hookBusy rises.

## Quartus (main project Lab1Demo) - Analysis & Synthesis
Changed: smiley_move.sv, Smiley_Block_T.bdf (new pins hookBusy, minerX, minerY, minerMoving),
TOP_VGA_DEMO_KBD.bdf (Smiley_Block_T symbol has the new ports; hookBusy tied to GND for now).
Expected 0 errors. The game must play EXACTLY as before (hookBusy = 0 -> miner never locked).
Optional board check: compile fully, the miner moves with 4/6 as before.
If you open the top-level .bdf in the Block Editor: the Smiley_Block_T box has 4 new ports;
3 outputs on the right are not connected yet (Step 6), hookBusy goes to a small GND symbol.
