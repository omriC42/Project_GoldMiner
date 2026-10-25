# Step 6+8 - hook in the top level and on the screen: what to check BY EYE

## A. ModelSim: cd tests -> do run_mux_hook.do -> VERSION 6.4 -> expect 8 PASS, 0 FAIL
* zt 1: combo counts 0..63; on every step RGBOut (yellow) equals expected one clock later;
  mismatches stays 0. Whenever smileyDR is high, RGBOut = 03 (miner) no matter what else is high;
  when only lower requests are high and mux_hookDR is high, RGBOut = 49 (hook).
* frames/top_mux_frame.bmp: brown background; BLUE box = test miner (280..343, 100..163);
  grey rope hanging from the middle of its bottom edge, passing OVER a yellow gold strip,
  light-grey claw at the end (~312,204). The rope's first row is hidden by the miner.

## B. Quartus (Lab1Demo): full compilation (Processing > Start Compilation)
Tell Claude when done - it reads the reports (map, fit, sta) from output_files itself.
Expected: 0 errors; hook_block appears in the hierarchy as hook_block:inst41; timing positive.

## C. Board (program output_files/Lab1Demo.sof)
| Check | Expected |
|---|---|
| Start of game | short grey rope + claw hanging from the middle of the miner's bottom edge, swinging left-right (~1.65 s per full swing) |
| Keys 4 / 6 | miner moves, rope and claw move WITH it and keep swinging |
| Key 2 (not moving) | rope shoots out in a straight line at the current angle, comes back at the floor / wall |
| While the hook is out | keys 4 / 6 do nothing (miner locked) until the hook is back and swinging |
| Hold 4 or 6 and press 2 | nothing happens (no shot while moving); release 4/6, press 2 again -> shot |
| Rope over gold / rocks | rope and claw are drawn ON TOP of gold, behind the miner; gold is NOT caught yet (Step 7) |
| Rest of the game | timer, HUD, dust, levels, game over: exactly as before |
| Old behaviour | the miner touching gold still collects it - this is removed in Step 7 |
