# Carry - the caught object hanging on the claw (carried_draw): what to check BY EYE
ModelSim: cd tests -> do run_carried_draw.do -> first line VERSION 12.0 -> expect 38 PASS, 0 FAIL.
The position rule (Oct 25 fix, hook_params.sv CARRY_OFFSET_PX = 4): the object hangs straight down
under the claw, centred on the tip in x; its first VISIBLE row is 4 px below the tip (under the
claw's bottom bar, the claw is drawn on top). The rope angle does not move it. Upright, never rotated.

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | 30 PASS lines: 6 objects x 5 angles, 0 mismatches each, a few hundred..few thousand px drawn |
| 1 | angle_now / dirCos / dirSin | 15 -> 45 -> 90 -> 135 -> 165 for each object; dirSin always positive (the rope points down), dirCos > 0 left half, 0 at 90, < 0 right half |
| 1 | dut/boxX, dut/boxY vs ref_left, ref_top | equal (the hardware corner = the model corner); same value at all 5 angles |
| 1 | drawingRequest vs expected | drawingRequest high exactly where expected is not FF; mismatches stays 0 |
| 1 image | frames/carry_types_90deg.bmp | 6 tips (small light-purple cross) in a row, each with its object directly under it, touching: gold S, M, L then rock S, M, L, NO gap between the mark and the object |
| 1 image | frames/carry_angles_gold_large.bmp | 5 large gold nuggets, each directly under its tip, all in the same place relative to the tip (the angle does not move it), all upright |
| 2 | show = 0 | drawingRequest flat 0 for all 6 objects |
| 3 | objType 0 and 7, show = 1 | drawingRequest flat 0 |
| 4 | tip at (610,455) | object drawn only up to the screen edge; nothing appears at the top-left (no wrap) |
| 5 | pixelX/pixelY step into the object | drawingRequest rises ONE clock later (registered, like hook_draw) |

Never: an object while show = 0; a sprite that is rotated or mirrored; anything drawn across the screen edge on the other side.

## In the game (board, after a full compile)
| Do | Expected |
|---|---|
| Catch a gold / rock | it hangs in the claw all the way up, moving with the claw tip; the score does NOT change yet |
| The hook reaches the top | object disappears from the claw, score goes up by its value at that moment |
| Catch at a steep angle | object hangs straight down IN the claw (not beside it), no gap between claw and object |
| Miss | nothing hangs on the claw; no score |
