# Testing conventions for the hook integration (agreed 2026-10-19)

Every ModelSim testbench and .do script in this project follows these rules:

1. **Never exit by itself.** No `$finish`, no `quit`, no `vsim -c` batch mode.
   The testbench ends with `$stop` (pause). The GUI and wave window stay open.
   Watchdogs also use `$stop`, so a hang pauses at the place it got stuck.
2. **Waveforms are the main result.** The .do script opens the GUI and builds a
   grouped wave window: TEST PROGRESS / INPUTS / DUT STATE / MEASURED.
3. **Every check is visible.** `chk_pass` (green) and `chk_fail` (red) pulse at the
   exact moment of each check; `chk_name` (ASCII) says what was checked;
   `test_name` (ASCII) shows which test is running.
4. **Motion is drawn.** Positions/angles/lengths are shown as analog curves.
5. **Speeds in real units.** `meas_*` signals show deg/s, px/s and seconds,
   converted from frames using the measured 72.58 Hz frame rate.
6. **Navigation.** Cursors T1..Tn mark each test start; `zt <n>` zooms on test n,
   `zt 0` shows the whole run.
7. Readable state names via `radix define`.
8. Stimulus is driven on the falling clock edge (no simulation races).
9. **Every loop and wait is bounded** (frame/clock limit) -> a broken design gives a red FAIL, never a hang.
10. DUT signals are unsigned: copy them into an `int` before comparing with signed values (lesson from Step 1, T2 hang).
11. No SystemVerilog keywords as names (e.g. `cross`, `bins`, `table`, `final`) - checked by script before delivery (Step 2 lesson).
12. .do scripts start with `catch {quit -sim}` (unload previous test) and use their own library folder `lib_<test>` and never delete it (Windows file locks, Step 2 lesson).
13. Every testbench prints a VERSION banner first; Claude states the expected version with each delivery. Re-runs after a change use the full `do run_*.do` (`restart` does not recompile - Step 3 lesson).
14. **Every test comes with a human checklist** (tests/CHECKLIST_stepN_*.md and in the chat): what each wave/image should look like, where (time/zt), and expected values - for checking by eye, not only by the script.
15. Never use the `.name` port shorthand for a constant (localparam) - Quartus error 10897. Constants get their own names and explicit `.port(CONST)`; checked by script (Step 3.5 lesson).
16. Each step stops after the work is explained; the next step starts only after approval.
