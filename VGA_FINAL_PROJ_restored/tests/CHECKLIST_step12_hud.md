# Step 12 - HUD without dividers / functions: what to check BY EYE
ModelSim: cd tests -> do run_game_hud.do -> first line VERSION 12.0 -> expect 10 PASS, 0 FAIL.
Every number is kept twice: binary (dollars, level, target, secondsLeft - for the game rules) and as
decimal digits (dolH/T/O, lvlT/O, tgtH/T/O, minD secT secO - for the screen), counted in decimal.
The pictures are compared with the OLD drawing code (with / and %), copied into the testbench.

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | digits after reset: $000, level 01, target 048, clock 1:00 (defaults); picture 0 mismatches |
| 2 | collectValue, valT / valO | the value split into tens and ones: 9 -> 0,9 ; 10 -> 1,0 ; 63 -> 6,3 |
| 2 | dollars_i (gold curve) vs dolH dolT dolO | the curve climbs to 999 and stays; the three digits always read the same number (e.g. 1 2 7 = 127) |
| 2 | dig_bad, pix_bad | stay 0 |
| 3 | csecs_i (green curve), minD secT secO | 119 -> 0 in steps; digits 1:59 ... 1:00 -> 0:59 (minute drops, tens jump 0 -> 5), x0 -> (x-1)9 |
| 4 | nextLevelKey pulses, level_i, lvlT lvlO | level 1..99 then stays 99; 09 -> 10 carry; target digits step by 30 until 999 |
| 5 | gameOver | high; the GAME OVER band compared with 0 mismatches |

## Quartus (after a full compile)
Compilation report > Analysis & Synthesis > Resource Utilization by Entity:
* game_hud: no more lpm_divide entries under it (were Div0-Div4, Mod0-Mod4)
* ObjectsMatrixBitMap: no more lpm_divide (were Mod0-Mod7)
* total LUTs about 600 lower than before.

## Board
| Do | Expected |
|---|---|
| Collect objects | score counts exactly as before (e.g. 12 + 24 = 36), 3 digits after 100 |
| Wait for the clock | 1:00, 0:59 ... 0:10, 0:09 ... 0:00 |
| Keypad + several times | level 2, 3 ... 10 (two digits), target +30 each time |
| Keypad * | GAME OVER text as before |
