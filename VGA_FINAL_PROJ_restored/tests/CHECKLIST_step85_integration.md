# Step 8.5 - the hook inside the game: what to check BY EYE
ModelSim: cd tests -> do run_game_integration.do -> first line VERSION 8.5.6 -> expect 28 PASS, 0 FAIL.
Real modules: smiley_move + miner sprite + dust, hook_block, gold field (square_object + GoldsMatrixBitMap),
game_hud (score), objects_mux. The testbench only presses keys 2/4/6 - nothing is forced.
The gold layout is printed in the Transcript at T1 (same every run in simulation).

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | miner (280,100), rope origin (312,164), 8 objects listed, score 0 |
| 2 | key6, minerX, minerXspeed | key6 high -> minerXspeed ramps 0 -> 60 in steps of 4, minerX (purple curve) rises |
| 2 | key2 high while key6 high | hookState stays SWING. key6 drops while key2 is still high -> still SWING (old press) |
| 2 | ropeX0 | always minerX + 32 (moves together with minerX) |
| 3 | Transcript "target: ..." | best reachable object (gold first, biggest first, the TOP object of its column) |
| 3 | key4/key6, minerX | walks toward the target, key released EARLY, minerXspeed falls 56, 52 ... 0 (glide), ropeX0 ends on tgt_cx (+-4) |
| 4 | angle_deg (cyan triangle) | key2 pulse exactly where the triangle crosses 90 -> hookState SHOOT, hookBusy high |
| 5 | key4 | goes high right after the shot and STAYS high through SHOOT and RETRACT |
| 5 | minerX, minerXspeed | flat / 0 the whole time hookBusy is high (miner locked) |
| 5 | R (orange) | ramps up, stops at the object; at that moment tipDR_d and goldDR on the same clock -> hookCatch -> ONE goldCollected pulse |
| 5 | goldValue, goldType, score | goldValue = target value, goldType = target type (hook latches it: hb/caughtType), score (green curve) steps up by that value |
| 5 | R falling after the catch | slope = the object's pull-back speed from game_params.sv (Transcript: measured vs game_params, +-3%) |
| 5 | R | ramps down to 40, hookState SWING, hookBusy drops |
| 6 | minerX | key4 still high: as soon as hookBusy drops, minerX starts falling (miner walks left) |
| 7 | as T3-T5 | second target: walk, aim at 90, catch; score steps up again (sum of both values); its pull-back speed is checked too |
| 7 | key2 pulse during RETRACT | hookState stays RETRACT, R keeps going down - nothing restarts |

Images (tests/frames):
* game_1_start.bmp  - miner on the rail, short rope hanging below it, 8 objects, HUD score 0
* game_2_shot.bmp   - miner above the target, rope straight down, still short
* game_3_caught.bmp - long straight rope down to where the target WAS; target gone, score up
* game_4_after.bmp  - rope short again, miner moved a bit LEFT (T6), dust behind the cart
* game_5_second.bmp - second object gone, rope on its way back
* game_6_end.bmp    - 6 objects left, score = both values
Background is plain brown here (the real background picture ROM is not in the simulation).

Never: a shot while key 4/6 is held; minerX changing while hookBusy = 1; two goldCollected for one catch;
an object disappearing that the claw did not touch; key 2 doing anything while the hook is out.

## Board (Lab1Demo after a full compile)
| Do | Expected |
|---|---|
| Hold 6, press 2 | no shot while walking; release 6 - still no shot until you press 2 AGAIN |
| Stop, press 2 at the right moment | rope goes out at the swing angle (15..165 deg, never flat) |
| Hold 4 while the hook is out | miner does not move; when the hook is back it starts walking |
| Catch gold / rock | object vanishes, score goes up by its value (gold 12/24/36, rock 4/8/12), hook comes back |
| Press 2 while the hook is out | nothing happens |
| Several catches in a row | score adds up correctly |
