# CHECKLIST – B10: game_hud keeps decimal digits only

## What changed (logic must be IDENTICAL)
- `game_hud.sv`: the binary copies `secondsLeft`, `dollars`, `level`, `target` (and `tStart`, `tStep`, `startSeconds`) are gone. Every number is kept only as decimal digits:
  - clock `minD secT secO`
  - dollars `dolH dolT dolO`
  - target `tgtH tgtT tgtO`
  - level `lvlT lvlO`
- Comparisons are made on the digits:
  - "time is up" = all clock digits 0
  - "enough dollars" = `{dolH,dolT,dolO} >= {tgtH,tgtT,tgtO}`
  - level 99 = `8'h99`
  - `levelWon` = clock ≥ "start − 2 s" (a constant per time setting)
- New `bcd_add3.sv`: adds two 3-digit decimal numbers column by column and stops at 999. Used for dollars + value and for target + step.
- New `hud_number.sv`: one left-aligned number of up to 3 digits (no leading zeros), using 3 `hud_digit` inside. Used for dollars, target and level.
- Start values are ready-made decimal-digit constants (`TSTART_*`, `TSTEP_*`, `TIME_*`, `WON_*`).
- Ports unchanged → the top level, `game_hud.bsf` and SignalTap are unchanged.

## Run 1 – equivalence: `do run_game_hud_equiv.do` → VERSION 1.1
- [ ] T1: `diffs` stays **0** for the whole run (no red `diff_now` pulse). The summary line says "the SAME outputs and digits on every clock".
- [ ] T2: coverage PASS: 999 dollars, target 999, level 99, GAME OVER by clock and by `*`, level won by clock and by `+`, `levelWon` high, all 9 settings.
- [ ] Waves: `oDol`/`nDol`, `oTgt`/`nTgt` (analog) lie exactly on top of each other. `oRGB` = `nRGB`.

## Run 2 – the existing tests (same checks, now reading the digits)
- [ ] `do run_game_hud.do` → **12.3**, ALL PASSED (same number of PASS as 12.2)
- [ ] `do run_game_integration.do` → **8.11**, ALL PASSED (47)
- [ ] `do run_hook_weight.do` → **9.9**, ALL PASSED (same number as 9.8)

## Compile + board
- [ ] Compile: 0 errors. Registers a bit lower than 2,353 (the binary copies are gone). Memory bits 3,299,840, RAM 405, DSP 4, pins 45 unchanged.
- [ ] Board, the HUD:
  - [ ] the score goes up when an object reaches the top
  - [ ] the target shows (EASY 40 / NORMAL 48 / HARD 60)
  - [ ] the clock counts 1:00 → 0:59 …
  - [ ] when the clock runs out with enough dollars → level 2, new target, clock restarts
  - [ ] otherwise GAME OVER
  - [ ] cheats `+` / `*` work when ON
