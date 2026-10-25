# Step 7 - catching: what to check BY EYE
ModelSim: cd tests -> do run_hook_catch.do -> first line VERSION 7.4 -> expect 16 PASS, 0 FAIL.
The gold layout is random (built at reset); T1 prints it in the Transcript and picks a target.
7.4: deliverPulse (green) = ONE pulse when the hook gets home WITH the object (deliverValue = its value); none after T4's empty shot. hb/carryDR is active during the pull-back (object drawn on the rope, see catch_2_caught.bmp).

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | list of the 8 objects (row, col, type, value) and the chosen target (biggest gold) |
| 2 | scan_kind = LATENCY GOLD | pixelX counts up along the target's middle row; goldDR rises; lat_gold = 2 |
| 2 | scan_kind = LATENCY CLAW | tipDR rises one clock after its pixel; tipDR_d one clock later; lat_tip = 1 |
| 3 | force_angle pulse, shoot_key pulse | hookState SWING -> SHOOT; R ramps up |
| 3 | top of the R ramp (zoom on the last CLAW WINDOW scan of SHOOT) | tipDR_d and goldDR high on the SAME clock -> hookCatch (red) one clock later -> collectPulse (orange) ONE single pulse, collectValue = target value -> hookState RETRACT. n_collect = 1 |
| 3 | R | falls back to 40, hookState SWING |
| 4 | minerX = 568 (rope at x 600, outside the gold field) | R ramps all the way to the floor (~313); hookCatch and collectPulse stay flat |

Images (tests/frames):
* catch_1_before.bmp - gold field with the objects; short rope above the target
* catch_2_caught.bmp - long straight rope down to where the target WAS; the target is gone
* catch_3_after.bmp  - rope short again; the target cell is empty, all other objects unchanged
Never: two collectPulses for one catch; hookCatch while hookState is not SHOOT; an object vanishing in T4.

## Board (after a full compile of Lab1Demo)
| Check | Expected |
|---|---|
| Shoot at gold | claw stops on the gold, the gold disappears, the score (HUD) goes up, the hook comes back |
| Shoot at a rock | same, but smaller value (rock = 1/3 of gold of the same size) |
| Small objects | can be caught when the claw touches them (claw is 16 px wide) |
| Miss (shoot between objects) | the hook goes to the floor/wall and comes back, nothing removed |
| Miner walking over the gold field area | nothing is collected (only the claw catches) |
| Swinging hook | never catches anything (it only catches while shooting) |
| Level won / new layout | catching still works in the new layout |
