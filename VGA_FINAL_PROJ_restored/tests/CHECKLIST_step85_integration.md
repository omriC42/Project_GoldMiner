# Step 8.5 - the hook inside the game: what to check BY EYE
ModelSim: cd tests -> do run_game_integration.do -> first line VERSION 8.7.1 -> expect 47 PASS, 0 FAIL.
Real modules: miner_move + miner sprite + dust (6 pictures, driven by the real motion movingLeft/movingRight), hook_block, gold field (square_object + GoldsMatrixBitMap),
game_hud (score, fed by hook_block deliverPulse/deliverValue = score at the top, like the TOP), objects_mux. The testbench only presses keys 2/4/6 - nothing is forced.
The gold layout is printed in the Transcript at T1 (same every run in simulation).

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | miner (280,100), rope origin (312,164), 8 objects listed, score 0 |
| 2 | key6, minerX, minerXspeed | key6 high -> minerXspeed ramps 0 -> 60 in steps of 4, minerX (purple curve) rises |
| 2 | key2 high while key6 high | hookState stays SWING. key6 drops while key2 is still high -> still SWING (old press) |
| 2 | ropeX0 | always minerX + 32 (moves together with minerX) |
| 2 | DUST group: dustRightKey, dustOn, dustOnLeftSide, pictureNum | key6 -> dustOn = 1, dustOnLeftSide = 1, pictureNum counts 0..5 (6 frames each) and repeats; after key6 is released it finishes the round at 5 and dustOn drops |
| 3 | Transcript "target: ..." | best reachable object (gold first, biggest first, the TOP object of its column) |
| 3 | key4/key6, minerX | walks toward the target, key released EARLY, minerXspeed falls 56, 52 ... 0 (glide), ropeX0 ends on tgt_cx (+-4) |
| 4 | angle_deg (cyan triangle) | key2 pulse exactly where the triangle crosses 90 -> hookState SHOOT, hookBusy high |
| 5 | key4 | goes high right after the shot and STAYS high through SHOOT and RETRACT |
| 5 | minerX, minerXspeed | flat / 0 the whole time hookBusy is high (miner locked) |
| 5 | dustLeftKey, dustOn, n_dust_start_busy | key4 high but dustLeftKey stays 0 while hookBusy = 1 (miner speed 0); dustOn stays 0 (no new round); n_dust_start_busy stays 0 |
| 8 | key6, minerX, dustRightKey, dustOn | minerX climbs to 573 and stays; dustRightKey drops to 0 although key6 is still high; dust finishes its round and dustOn stays 0 |
| 5 | R (orange) | ramps up, stops at the object; at that moment tipDR_d and goldDR on the same clock -> hookCatch -> ONE goldCollected pulse |
| 5 | goldValue, goldType, score | goldValue = target value, goldType = target type (hook latches it: hb/caughtType); score (green curve) does NOT move at the catch |
| 5 | hb/carryShow, hb/carryDR | carryShow high for the whole RETRACT with the object; carryDR pulses during the scans (object drawn on the rope); n_carry_seen = n_carry_px after game_3_caught (every carried pixel reached the screen) |
| 5 | hookDeliver (green) at the end of RETRACT | ONE pulse exactly when hookState goes back to SWING, hookDeliverValue = target value -> score steps up by that value THERE |
| 5 | R falling after the catch | slope = the object's pull-back speed from game_params.sv (Transcript: measured vs game_params, +-3%) |
| 5 | R | ramps down to 40, hookState SWING, hookBusy drops |
| 6 | minerX | key4 still high: as soon as hookBusy drops, minerX starts falling (miner walks left) |
| 6 | dustLeftKey, dustOn, dustOnLeftSide | dustLeftKey rises with hookBusy falling, dustOn = 1, dustOnLeftSide = 0 (dust on the RIGHT of the cart) |
| 7 | as T3-T5 | second target: walk, aim at 90, catch; score unchanged at the catch, steps up again when the hook is home (sum of both values); its pull-back speed is checked too |
| 7 | key2 pulse during RETRACT | hookState stays RETRACT, R keeps going down - nothing restarts |
| 9 | keyPlus (orange) while R falls with an object | ONE newLevel pulse -> on the next clock hookState SWING, R = 40, caught 0, hookBusy 0; NO hookDeliver afterwards; score 0, hud/level 2; the gold field shows a new layout; minerX does not change |
| 10 | keyStar (red) in the middle of a shot | gameOver goes high and STAYS; R and angle_deg flat from then on, hookState stays SHOOT; minerLock = 1 |
| 5 | soundStart / soundSelect (Step 11) | at the catch: soundStart with soundSelect 1 (CATCH); when the hook is home: soundStart with 2 (MONEY) |
| 9 | soundStart / soundSelect | after keypad +: ONE soundStart with 3 (LEVEL), no 2 (MONEY) afterwards |
| 10 | soundStart / soundSelect | after keypad *: ONE soundStart with 4 (GAMEOVER), nothing more while gameOver stays high |
| 10 | key4 held + a key2 pulse while gameOver = 1 | minerX flat, minerXspeed 0, no dust; hookState unchanged; score unchanged; no hookCatch |

Images (tests/frames):
* game_1_start.bmp  - miner on the rail, short rope hanging below it, 8 objects, HUD score 0
* game_2_shot.bmp   - miner above the target, rope straight down, still short
* game_3_caught.bmp - long straight rope; the caught object now HANGS below the claw (upright, centred on the rope); score NOT up yet
* game_4_after.bmp  - rope short again, miner moved a bit LEFT (T6), gray dust picture on the RIGHT of the cart (behind it)
* game_5_second.bmp - second object hanging on the rope on its way back up
* game_6_end.bmp    - 6 objects left, score = both values
* game_7_newlevel.bmp - after keypad +: new layout (8 objects), short empty rope, score 0, level 2, miner where it was
* game_8_gameover.bmp - GAME OVER text; the rope frozen half way down; nothing else moved
Background is plain brown here (the real background picture ROM is not in the simulation).

Never: anything moving after gameOver; a score added after a new level dropped the object; a shot while key 4/6 is held; minerX changing while hookBusy = 1; two goldCollected for one catch; the score going up before the hook is home; the carried object leaving the rope;
an object disappearing that the claw did not touch; key 2 doing anything while the hook is out.

## Board (Lab1Demo after a full compile)
| Do | Expected |
|---|---|
| Hold 6, press 2 | no shot while walking; release 6 - still no shot until you press 2 AGAIN |
| Stop, press 2 at the right moment | rope goes out at the swing angle (15..165 deg, never flat) |
| Hold 4 while the hook is out | miner does not move and NO dust; when the hook is back it starts walking and the dust starts |
| Hold 6 / hold 4 | dust cloud on the LEFT / RIGHT of the cart, animating through 6 pictures; release - dust continues while the cart glides, then finishes the round and disappears |
| Hold 6 against the right edge (or 4 against the left) | the cart stands still and there is NO dust |
| Catch gold / rock | object vanishes, score goes up by its value (gold 12/24/36, rock 4/8/12), hook comes back |
| Press 2 while the hook is out | nothing happens |
| Several catches in a row | score adds up correctly |
