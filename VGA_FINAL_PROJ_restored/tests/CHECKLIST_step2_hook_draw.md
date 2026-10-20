# Step 2 - hook_draw: what to check BY EYE

## Reading the wave window
* One frame = 640 x 480 pixels = 307,200 clocks = about 3.07 ms of sim time.
* One VGA line = 640 clocks = 6.4 us. pixelX is a fast sawtooth (one tooth per line),
  pixelY is a slow ramp 0 -> 479 (one ramp per frame).
* Outputs come 1 clock AFTER the pixel (registered), like the other drawing modules.
* Start every test with  zt <n> , then zoom in (Ctrl + mouse wheel or the + button).

## Every test (T2..T7)
1. chk_fail (red) stays flat for the whole test; nFail stays 0.
2. meas_claw_far_px, meas_outside_box_px, meas_bad_color_px (red group) = 0 at the end of the test.
3. RGBout = FF whenever drawingRequest = 0; 49 on rope pixels; B6 on claw pixels.
4. tipDR is high only on the claw rows (table) and is always a SUBSET of drawingRequest
   (tipDR = 1 never happens when drawingRequest = 0).
5. clawPixel / ropePixel (inside DUT) go high exactly 1 clock before tipDR / drawingRequest.
6. nearLine vs ropePixel - the most instructive picture:
   nearLine is high along the WHOLE infinite line (also above the origin and past the tip,
   on other rows of the screen). ropePixel is high only where inBox is also high.
   -> you can see the bounding box cutting the line to the real rope.

## Per test (approx. times from the start of the run)
| Test | Hook | Time | What the drawingRequest pulses look like | Claw (tipDR) rows | Measured |
|---|---|---|---|---|---|
| T2 | 0 deg, R=200, tip (520,164) | 0-3.1 ms | Only on 3 lines (pixelY 163,164,165): one LONG pulse per line, ~200 clocks (x 319..521) | 158..169 near x 513..528 | rope ~601 px, width 3.0, max dist 1.00 |
| T3 | 45 deg, R=250, tip (496,340) | 3.1-6.1 ms | Lines 163..340: short pulse (1-3 clocks) that moves 1 pixel RIGHT every line (a diagonal) | 334..345 | ~530 px, 2.1, 0.71 |
| T4 | 90 deg, R=300, tip (320,464) | 6.1-9.2 ms | Lines 163..465: short 3-clock pulse at the SAME x (319..321) every line - a vertical "comb" | 458..469 | ~895 px, 3.0, 1.00 |
| T5 | 135 deg, R=250, tip (143,340) | 9.2-12.3 ms | Lines 163..341: short pulse moving 1 pixel LEFT every line | 334..345 | ~500 px, 2.0, 1.00 |
| T6 | 180 deg, R=200, tip (120,164) | 12.3-15.4 ms | Like T2 but to the left: 3 lines, long pulse x 119..321 | 158..169 near x 113..128 | ~601 px, 3.0, 1.00 |
| T7 | 90 deg, R=40, tip (320,204) | 15.4-18.4 ms | Like T4 but short: lines 163..205 only | 198..209 | ~115 px, 2.9, 1.00 |

Above the origin (pixelY < 163) and below the claw, drawingRequest must be completely flat.

## The images (tests/frames/*.bmp)
Compare with tests/expected_hook_draw_preview.png:
* brown background, dark-grey rope from the start point (320,164) to the tip,
* a light-grey anchor-shaped claw centred on the tip,
* rope continuous (no gaps), same thickness along its length, horizontal ropes (T2,T6) visible,
* nothing drawn anywhere else on the screen.
