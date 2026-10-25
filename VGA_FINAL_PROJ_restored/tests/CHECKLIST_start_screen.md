# Opening + settings screens (start_screen.sv): what to check BY EYE
ModelSim: cd tests -> do run_start_screen.do -> first line VERSION 11.0 -> expect 5 PASS, 0 FAIL.
Pictures: RTL/VGA/make_menu_pictures.py draws them (start_screen.png 320x240, settings_screen.png 160x120)
and writes start_screen.hex, settings_screen.hex and settings_layout.svh (where the words are).
The testbench builds every expected frame itself (picture + frames + arrow painted as shapes).

| zt | Look at | Expected |
|---|---|---|
| 1 | frames/menu_1_opening.bmp | GOLD MINER title, rocks + gold, brown line, PRESS ENTER TO PLAY, PRESS + FOR SETTINGS |
| 2 | frames/menu_2_settings_default.bmp | SETTINGS; yellow arrow at DIFFICULTY; green frames on NORMAL, 60 S, ON, ON |
| 3 | frames/menu_3_settings_changed.bmp | arrow at SOUND; frames on HARD, 30 S, OFF, OFF |
| 4 | frames/menu_4_settings_row1.bmp / row3.bmp | arrow at TIME PER LEVEL / at CHEATS; frames on EASY, 90 S, ON, OFF |
| 1-4 | mismatches | stays 0 through every frame; onArrow / onFrame pulse only on the settings screen |
| 5 | screen = PLAYING | RGBOut follows gameRGB on the same clock |
