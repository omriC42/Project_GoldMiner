# Opening screen as a picture - what to check BY EYE
ModelSim: cd tests -> do run_start_screen.do -> first line VERSION 10.0 -> expect 8 PASS, 0 FAIL.
The picture is RTL/VGA/start_screen.hex (made from start_screen.png by make_start_screen_hex.py).

| zt | Look at | Expected |
|---|---|---|
| 1 | pixelY (ramp 0..479), RGBOut | one full frame; RGBOut is 00 (black) almost everywhere, FC (yellow) in short bursts on rows 226..253 |
| 1 | mismatches | stays 0 the whole frame (picture = the old drawn screen, pixel for pixel) |
| 1 | yellow_px | ends at 4208 |
| 2 | gameResetN | 0 (game held in reset while the picture is shown) |
| 3 | enterKey, state | enterKey already high when resetN rises -> state stays OPENING_ST, gameResetN stays 0 |
| 4 | enterKey, state, gameResetN | new press -> state PLAYING_ST next clock, gameResetN high one clock later; RGBOut = 1C (gameRGB) |
| 5 | enterKey pulses | nothing changes, still PLAYING_ST |

Image: tests/frames/start_screen.bmp - black screen, "PRESS ENTER TO START" in yellow in the middle
(the same as before the change).

## Board (after a full compile)
| Do | Expected |
|---|---|
| Program / press KEY0 | the same opening screen as before; nothing moves, the clock does not count |
| Press ENTER | the game starts |
| Compile report | Total block memory bits about +614,400 (76,800 x 8) compared with before; start_screen uses ~75 RAM blocks |
