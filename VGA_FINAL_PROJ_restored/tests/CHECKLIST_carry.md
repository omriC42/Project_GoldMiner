# Carry - the caught object hanging on the claw (carried_draw): what to check BY EYE
ModelSim: cd tests -> do run_carried_draw.do -> first line VERSION 11.0 -> expect 38 PASS, 0 FAIL.
The position rule (hook_params.sv CARRY_OFFSET_PX = 4): sprite centre = tip + D along the rope,
D = 4 + half the size -> small 12 px, medium 20 px, large 36 px. The sprite stays upright.

| zt | Look at | Expected |
|---|---|---|
| 1 | Transcript | 30 PASS lines: 6 objects x 5 angles, 0 mismatches each, a few hundred..few thousand px drawn |
| 1 | angle_now / dirCos / dirSin | 15 -> 45 -> 90 -> 135 -> 165 for each object; dirSin always positive (the rope points down), dirCos > 0 left half, 0 at 90, < 0 right half |
| 1 | dut/boxX, dut/boxY vs ref_left, ref_top | equal (the hardware corner = the model corner) |
| 1 | drawingRequest vs expected | drawingRequest high exactly where expected is not FF; mismatches stays 0 |
| 1 image | frames/carry_types_90deg.bmp | 6 tips (small light-purple cross) in a row, each with its object hanging straight down below it: gold S, M, L then rock S, M, L, a few px gap between the mark and the object |
| 1 image | frames/carry_angles_gold_large.bmp | 5 large gold nuggets around their tips, each pushed AWAY from the tip along the rope direction (15 deg = to the lower right ... 165 deg = to the lower left), all upright |
| 2 | show = 0 | drawingRequest flat 0 for all 6 objects |
| 3 | objType 0 and 7, show = 1 | drawingRequest flat 0 |
| 4 | tip at (610,455) | object drawn only up to the screen edge; nothing appears at the top-left (no wrap) |
| 5 | pixelX/pixelY step into the object | drawingRequest rises ONE clock later (registered, like hook_draw) |

Never: an object while show = 0; a sprite that is rotated or mirrored; anything drawn across the screen edge on the other side.

## In the game (board, after a full compile)
| Do | Expected |
|---|---|
| Catch a gold / rock | it hangs on the claw all the way up, following the rope angle; the score does NOT change yet |
| The hook reaches the top | object disappears from the claw, score goes up by its value at that moment |
| Catch at a steep angle | object stays on the rope line, centred a few px past the claw |
| Miss | nothing hangs on the claw; no score |
