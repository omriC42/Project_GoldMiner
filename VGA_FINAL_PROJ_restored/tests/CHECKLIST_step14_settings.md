# Step 14 - screens + settings (game_settings.sv): what to check BY EYE
ModelSim: cd tests -> do run_game_settings.do -> first line VERSION 14.0 -> expect 22 PASS, 0 FAIL.

| zt | Look at | Expected |
|---|---|---|
| 1 | screen, gameResetN | OPENING, gameResetN 0; ENTER and + held through KEY0 do nothing (no enterP / plusP pulse) |
| 2 | enterKey, screen | ENTER -> PLAYING, gameResetN 1 one clock later; the key pulses after it change nothing |
| 3 | gameOver, enterKey | gameOver high: still PLAYING until ENTER; ENTER -> OPENING and gameResetN 0 (the game resets) |
| 4 | plusKey, cursor (Row radix) | + -> SETTINGS on DIFFICULTY; 2 -> TIME, SOUND, CHEATS and stops; 8 back to DIFFICULTY and stops |
| 5 | difficulty / timeSel / soundOn / cheatsOn | each changes only while the cursor is on its row; 4 = left value, 6 = right value, stopping at the ends |
| 6 | leftKey / downKey held long | ONE leftP / downP pulse each -> one step only; + does nothing on SETTINGS |
| 7 | enterKey on SETTINGS | PLAYING with EASY / 90 S / sound ON / cheats OFF; after game over + ENTER and + again: cursor back on DIFFICULTY, choices kept |
| 8 | resetN pulse (KEY0) | OPENING, the defaults of game_params.sv |

Never: two steps for one press; a setting changing outside the SETTINGS screen; gameResetN = 1 outside PLAYING.

## Board (after Part C)
| Do | Expected |
|---|---|
| Power up / KEY0 | opening picture; ENTER starts with the defaults (NORMAL, 60 s, sound on, cheats on) |
| + on the opening screen | settings screen, arrow on DIFFICULTY |
| 8 / 2 / 4 / 6 | arrow moves; the green frame moves to the chosen word |
| ENTER on settings | the game starts with those choices (e.g. 30 s on the clock, HARD target 60, no sounds, + and * do nothing) |
| GAME OVER, then ENTER | back to the opening picture; + shows the SAME choices |
| KEY0 | defaults again |
