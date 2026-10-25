# Step 9 - weight + game_params.sv: what to check BY EYE
ModelSim: cd tests -> do run_hook_weight.do -> first line VERSION 9.6 -> expect 65 PASS, 0 FAIL.
All expected numbers are read from game_params.sv / hook_params.sv: after you change a number,
run this test again - it checks the new number and that it still fits.

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | 5 PASS: values 1..63, seconds 1..119, every TARGET_START/STEP 0..999, steps 1..1023, difficulty EASY/NORMAL/HARD |
| 2 | Transcript | each object's value = the number in game_params.sv |
| 3 | Transcript | hook_block's STEP_* constants printed for EASY (0), NORMAL (1), HARD (2); with the default numbers NORMAL is gS 212, gM 150, gL 97, rS 176, rM 115, rL 62, empty 265 |
| 4 | cur_type 1..6 then 0 | 7 shots straight down (key 2 pulse where angle_deg crosses 90) |
| 4 | R (orange) | ramps up the SAME way every shot (shooting speed does not depend on weight), stops at the band (~130) |
| 4 | hookCatch -> caught -> caughtType | caught goes high a few clocks after hookCatch, caughtType = cur_type |
| 4 | retractStep (purple) | jumps from 265 (empty) to the object's step when caught, back to 265 when the hook is home |
| 4 | R falling edges | different slopes: rock large is the flattest (slowest), gold small the steepest; the last shot (type 0, no gold) goes to the floor (~313) and comes back at the empty speed |
| 4 | meas_pull_px_s vs exp_pull_px_s | equal within 3% for every shot |
| 4 | top_score (gold, 9.5) | does NOT move at hookCatch; jumps up by the object's value (12, 24, 36, 4, 8, 12 by default) only when R is back at the top and hookState = SWING -> a staircase 12, 36, 72, 76, 84, 96 |
| 4 | dPulse (green) / dValue | ONE short pulse per gold shot, exactly when the hook gets home; dValue = the value; NO pulse after the last (empty) shot |
| 4 | hb/carryDR | only while R falls (object drawn on the rope during the pull-back), never while shooting. Few pulses here: this test scans only 21x21 px around the tip; the full picture check is in tb_carried_draw / tb_hook_block |
| 5 | Transcript first line | the game's HUD uses DIFFICULTY from game_params.sv (start/step printed) |
| 5 | cur_diff 0, 1, 2 | the same game played 3 times: EASY, NORMAL, HARD HUD |
| 5 | seconds (green) | counts down from START_SECONDS to 0 four times per difficulty (1 s = 100 clocks here) |
| 5 | target (red curve) | a staircase: TARGET_START, then +TARGET_STEP at every level won. Defaults: EASY 40-60-80-100, NORMAL 48-78-108-138, HARD 60-100-140-180 |
| 5 | score (gold curve) | climbs to EXACTLY the target before each level end (score >= target wins), drops to 0 at the new level; at level 4 it stops one below the target -> cur_gameOver goes high |
| 6 | ck (magenta) = keypad + | first press: level +1, target +step, seconds jump back to 60, score 0, ONE cur_newLevel pulse |
| 6 | ck held high for a long time | nothing more happens (one jump per press) |
| 6 | second short press | level +1 again |
| 6 | seconds run down to 0 -> cur_gameOver, then a press | still GAME OVER, level unchanged |
| 5 | target_digits | always equal to target (the screen digits); hudE/tgtH, tgtT, tgtO show the digits counting in decimal (e.g. 0 8 0 -> 1 0 0) |

## Board (after a full compile)
| Do | Expected |
|---|---|
| Catch a small gold | comes back quickly |
| Catch a large rock | comes back clearly slowly (the slowest) |
| Miss (floor/wall) | comes back at the old empty speed |
| Score | values as in game_params.sv, added only when the hook is back at the top (not at the catch) |
| Win level 1 | the target on the HUD goes up by TARGET_STEP (NORMAL: 48 -> 78 -> 108) |
| Press keypad + | next level at once: level +1, target +step, clock 1:00, score 0, new gold layout |
| Hold keypad + | only ONE level per press |
| + after GAME OVER | nothing (reset button needed) |
| Change one number in game_params.sv (e.g. RETRACT_ROCK_LARGE 70 -> 40), recompile | only that object changes |
