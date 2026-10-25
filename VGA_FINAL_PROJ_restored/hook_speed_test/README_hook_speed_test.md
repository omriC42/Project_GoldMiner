# hook_speed_test - Step 3.5 standalone speed test
Small Quartus project that shows ONLY the hook on the screen, using the game's own hook files
(../RTL/VGA/hook_params.sv, hook_move.sv, hook_draw.sv). The main project is not touched.

1. Simulate first (optional but recommended): ModelSim -> cd hook_speed_test/sim -> do run_speed_test_core.do
2. Quartus 17.0: File > Open Project > hook_speed_test.qpf ; Processing > Start Compilation
3. Tools > Programmer > add output_files/hook_speed_test.sof > Start
4. Follow sim/CHECKLIST_step35_speed_test.md part C with a stopwatch.

Keypad: 2 shoot | 8 pretend catch | 5 pause/resume | 0 reset hook.  Lights: green SWING, yellow SHOOT, red RETRACT.
Board reset button (resetN_pin) resets everything, like in the game.
