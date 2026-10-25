# Step 11 - game sounds: what to check BY EYE
ModelSim: cd tests -> do run_game_sound.do -> first line VERSION 11.1 -> expect 18 PASS, 0 FAIL.
Time here is in "ticks": melody_player_1 runs in simulation mode, 1 tick (= 1/100 s on the board) every 21 clocks.
Tunes (GameJukeBox.sv), tempo + gap + on/off (game_params.sv):

| sound | notes (pitch x beats) | beat |
|---|---|---|
| CATCH | sol x2, do x3 | fast (SOUND_BEAT_FAST_CS = 3) |
| MONEY | do x1, mi x1, sol x1, DO x4 | fast |
| LEVEL | do x2, mi x2, sol x2, DO x2, rest x1, sol x2, DO x6 | slow (SOUND_BEAT_SLOW_CS = 6) |
| GAMEOVER | sol x4, fa# x4, fa x4, mi x10 | slow |

| zt | Look at | Expected |
|---|---|---|
| 1 | event pulse -> soundStart (orange) | ONE soundStart pulse 1 clock after each event; soundSelect shows CATCH, MONEY, LEVEL, GAMEOVER |
| 1 | tone (Note radix) + cur_pitch (cyan curve) | the notes of the table above, in order: catch = a step DOWN, money = a staircase UP, level = up, a gap, up again, game over = steps DOWN |
| 1 | EnableSound (green) | high during every note, low in the short gaps; LOW during the rest of the fanfare |
| 1 | noteTimeCounter (curve) | a saw tooth per note: starts at beats x beat (e.g. 6, 9 for catch), counts down once per tick |
| 1 | melodyEnded | one pulse at the end of each sound |
| 2 | offStart (magenta) | never high (the all-OFF block); Transcript: normal block started 4 sounds |
| 3 | gameOver high -> GAMEOVER plays; objectCollected pulse in its 2nd note | soundSelect jumps to CATCH, SM_Maestro goes load -> PLAY, noteIndex back to 0; the catch plays to its end; NO melodyEnded for the cut game over |
| 3 | gameOver kept high after that | nothing more starts |
| 4 | two events on one clock | soundSelect: LEVEL (level+money), MONEY (money+catch), GAMEOVER (game over+level) |
| 5 | gameResetN low, all four events | soundStart stays 0, the player stays idle, EnableSound 0 |
| 6 | soundOn (magenta) low, all four events | soundStart stays 0; soundOn high again -> the next deliverPulse starts MONEY |

Never: two sounds at once; a sound while SM_Maestro is idle; a sound on the opening screen; offStart.

## Board (after a full compile) - headphones / speaker in the green LINE-OUT jack, KEY[3] = volume
| Do | Hear |
|---|---|
| Opening screen, press keys | nothing |
| Shoot (2), walk (4/6) | no beeps (keypad melodies are gone) |
| Catch gold or rock | short "clunk" |
| The object reaches the top | quick rising "cha-ching" (cuts the clunk if it is still playing) |
| Keypad + | fanfare |
| Keypad * | the sad tune, once (everything frozen, the tune does not repeat) |
| Change SOUND_MONEY_ON to 0 in game_params.sv, recompile | money is silent, the rest unchanged |
