// tb_game_settings.sv - Step 14: the screens and the settings (game_settings.sv)
//
// Run:  ModelSim -> cd <project>/tests -> do run_game_settings.do        (expect VERSION 14.0)
// Checklist: tests/CHECKLIST_step14_settings.md
//
// T1 after KEY0: OPENING, game held in reset, the defaults of game_params.sv; keys held through
//    the reset do nothing until pressed again
// T2 OPENING + ENTER -> PLAYING (gameResetN = 1); in PLAYING the keys change nothing, ENTER without
//    GAME OVER does nothing
// T3 GAME OVER + ENTER -> OPENING, game held in reset again, settings unchanged
// T4 OPENING + + -> SETTINGS, cursor on row 0; 8/2 move it, it stops at row 0 and row 3
// T5 4/6 change the value of the selected row, stopping at the ends, for all 4 rows
// T6 a key HELD for 1000 clocks = one step only; + does nothing on the settings screen
// T7 SETTINGS + ENTER -> PLAYING with the chosen settings; opening the settings again starts on row 0
// T8 KEY0 -> back to the defaults
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_game_settings;
import game_params::*;

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

logic enterKey = 0, plusKey = 0, upKey = 0, downKey = 0, leftKey = 0, rightKey = 0, gameOver = 0;
logic [1:0] screen, cursor, difficulty, timeSel;
logic       soundOn, cheatsOn, gameResetN;

game_settings dut (.clk, .resetN, .enterKey, .plusKey, .upKey, .downKey, .leftKey, .rightKey, .gameOver,
                   .screen, .cursor, .difficulty, .timeSel, .soundOn, .cheatsOn, .gameResetN);

localparam int OPENING = 0, SETTINGS = 1, PLAYING = 2;
localparam logic [1:0] D_DIFF = 2'(DIFFICULTY), D_TIME = 2'(DEFAULT_TIME_SEL);

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
realtime t_start [0:15];
realtime t_end   [0:15];
task automatic begin_test(input int n, input string name);
    if (test_no > 0) t_end[test_no] = $realtime;
    test_no = n; $sformat(test_name, "%s", name); t_start[n] = $realtime;
    $display("\n[%0t] ---- T%0d %s ----", $time, n, name);
endtask
task automatic check(input bit ok, input string what);
    $sformat(chk_name, "%s", what);
    if (ok) begin nPass++; chk_pass = 1; $display("[%0t]   PASS  %s", $time, what); end
    else    begin nFail++; chk_fail = 1; $display("[%0t]   FAIL  %s   <-----", $time, what); end
    #20; chk_pass = 0; chk_fail = 0;
endtask
task automatic write_windows_file(input int last);
    int fd;
    fd = $fopen("test_windows.do", "w");
    $fdisplay(fd, "set TW(0) {0 %0d}", longint'($realtime));
    for (int i = 1; i <= last; i++) begin
        $fdisplay(fd, "set TW(%0d) {%0d %0d}", i, longint'(t_start[i]), longint'(t_end[i]));
        $fdisplay(fd, "catch {wave cursor add -time %0dns -name T%0d}", longint'(t_start[i]), i);
    end
    $fclose(fd);
endtask

// a short key press (5 clocks), then 5 clocks released
task automatic press(ref logic k);
    @(negedge clk) k = 1; repeat (5) @(negedge clk); k = 0; repeat (5) @(negedge clk);
endtask
task automatic key0();                         // the reset button
    @(negedge clk) resetN = 0; repeat (3) @(negedge clk); resetN = 1; repeat (3) @(negedge clk);
endtask
function automatic bit defaults();
    return difficulty == D_DIFF && timeSel == D_TIME && soundOn == SOUND_ON && cheatsOn == CHEATS_ON;
endfunction
function automatic string scr(input int s);
    case (s) 0: return "OPENING"; 1: return "SETTINGS"; 2: return "PLAYING"; default: return "?"; endcase
endfunction

int  d0, t0, c0;
bit  s0, h0, ok;

initial begin
    $display("\n##### tb_game_settings VERSION 14.0 (2026-10-25, screens + settings) - if not the version Claude announced, run the full  do run_game_settings.do  #####");
    $display("   game_params defaults: difficulty %0d, time %0d, sound %0d, cheats %0d", D_DIFF, D_TIME, SOUND_ON, CHEATS_ON);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 after KEY0");
    @(negedge clk) begin enterKey = 1; plusKey = 1; end          // held while KEY0 is released
    repeat (3) @(negedge clk); resetN = 1;
    repeat (20) @(negedge clk);
    check(screen == OPENING && !gameResetN && defaults(),
          $sformatf("OPENING, game in reset, defaults (difficulty %0d time %0d sound %0d cheats %0d)", difficulty, timeSel, soundOn, cheatsOn));
    @(negedge clk) begin enterKey = 0; plusKey = 0; end
    repeat (10) @(negedge clk);
    check(screen == OPENING && !gameResetN, "ENTER and + held through KEY0 and released: still OPENING (they must be pressed again)");

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 ENTER -> game");
    @(negedge clk) enterKey = 1; repeat (3) @(negedge clk);
    check(screen == PLAYING && gameResetN, "ENTER on the opening screen -> PLAYING, gameResetN = 1 within 2 clocks");
    @(negedge clk) enterKey = 0; repeat (5) @(negedge clk);
    press(plusKey); press(upKey); press(downKey); press(leftKey); press(rightKey); press(enterKey);
    check(screen == PLAYING && gameResetN && cursor == 0 && defaults(),
          "in the game: +, 8, 2, 4, 6 and ENTER (no game over) change nothing");

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 GAME OVER + ENTER -> opening");
    @(negedge clk) gameOver = 1;
    repeat (20) @(negedge clk);
    check(screen == PLAYING, "game over alone: still in the game (frozen) until ENTER");
    @(negedge clk) enterKey = 1; repeat (3) @(negedge clk);
    check(screen == OPENING && !gameResetN && defaults(), "GAME OVER + ENTER -> OPENING, game held in reset, settings kept");
    @(negedge clk) begin enterKey = 0; gameOver = 0; end              // the reset clears game over
    repeat (5) @(negedge clk);
    check(screen == OPENING, "the same ENTER press did NOT start a new game straight away");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 + -> settings, cursor");
    press(plusKey);
    check(screen == SETTINGS && cursor == 0 && !gameResetN, "+ on the opening screen -> SETTINGS, cursor on row 0, game still in reset");
    press(upKey);
    check(cursor == 0, "8 on the first row: stays on row 0");
    press(downKey); c0 = cursor; press(downKey); press(downKey);
    check(c0 == 1 && cursor == 3, $sformatf("2, 2, 2 -> row 1 ... row 3 (cursor %0d)", cursor));
    press(downKey);
    check(cursor == 3, "2 on the last row: stays on row 3");
    press(upKey); press(upKey); press(upKey);
    check(cursor == 0, "8, 8, 8 -> back to row 0");

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 values of every row");
    // row 0 DIFFICULTY
    press(leftKey); press(leftKey); press(leftKey);
    ok = (difficulty == 0);
    press(rightKey); d0 = difficulty; press(rightKey); press(rightKey); press(rightKey);
    check(ok && d0 == 1 && difficulty == 2 && timeSel == D_TIME,
          $sformatf("DIFFICULTY: 4 x3 -> EASY (stops), 6 -> NORMAL, 6 x3 -> HARD (stops) (%0d); other rows unchanged", difficulty));
    // row 1 TIME
    press(downKey);
    press(leftKey); press(leftKey); press(leftKey);
    ok = (timeSel == 0);
    press(rightKey); t0 = timeSel; press(rightKey); press(rightKey);
    check(cursor == 1 && ok && t0 == 1 && timeSel == 2 && difficulty == 2,
          $sformatf("TIME: 4 x3 -> 30 S (stops), 6 -> 60 S, 6 x2 -> 90 S (stops) (%0d)", timeSel));
    // row 2 SOUND
    press(downKey);
    press(rightKey); s0 = soundOn; press(rightKey);
    ok = (!s0 && !soundOn);
    press(leftKey); press(leftKey);
    check(cursor == 2 && ok && soundOn && cheatsOn == CHEATS_ON, "SOUND: 6 -> OFF (twice stays OFF), 4 -> ON (twice stays ON); CHEATS unchanged");
    // row 3 CHEATS
    press(downKey);
    press(rightKey);
    h0 = cheatsOn;
    press(leftKey);
    check(cursor == 3 && !h0 && cheatsOn && soundOn, "CHEATS: 6 -> OFF, 4 -> ON; SOUND unchanged");
    press(rightKey);                                               // leave cheats OFF for T7

    // ------------------------------------------------------------ T6
    begin_test(6, "T6 held key, + in settings");
    press(upKey); press(upKey); press(upKey);                      // row 0, difficulty is HARD (2)
    press(leftKey);                                                // -> NORMAL (1)
    @(negedge clk) leftKey = 1; repeat (1000) @(negedge clk); leftKey = 0; repeat (5) @(negedge clk);
    check(difficulty == 0, $sformatf("4 held for 1000 clocks: ONE step (NORMAL -> EASY), difficulty %0d", difficulty));
    @(negedge clk) downKey = 1; repeat (1000) @(negedge clk); downKey = 0; repeat (5) @(negedge clk);
    check(cursor == 1, $sformatf("2 held for 1000 clocks: ONE row down (cursor %0d)", cursor));
    press(plusKey);
    check(screen == SETTINGS, "+ on the settings screen does nothing (still SETTINGS)");

    // ------------------------------------------------------------ T7
    begin_test(7, "T7 ENTER -> game with the choice");
    // now: difficulty EASY (0), time 90 S (2), sound ON, cheats OFF
    @(negedge clk) enterKey = 1; repeat (3) @(negedge clk);
    check(screen == PLAYING && gameResetN && difficulty == 0 && timeSel == 2 && soundOn && !cheatsOn,
          $sformatf("ENTER on the settings screen -> PLAYING with EASY, 90 S, sound ON, cheats OFF (%0d %0d %0d %0d)", difficulty, timeSel, soundOn, cheatsOn));
    @(negedge clk) enterKey = 0;
    @(negedge clk) gameOver = 1; press(enterKey); @(negedge clk) gameOver = 0;   // game over -> opening
    press(plusKey);
    check(screen == SETTINGS && cursor == 0 && difficulty == 0 && timeSel == 2 && !cheatsOn,
          "after game over + ENTER, + again: SETTINGS, cursor back on row 0, the choices are still there");

    // ------------------------------------------------------------ T8
    begin_test(8, "T8 KEY0 -> defaults");
    key0();
    check(screen == OPENING && !gameResetN && cursor == 0 && defaults(), "KEY0: OPENING with the defaults of game_params.sv");

    // ------------------------------------------------------------ end
    t_end[8] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(8);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #5_000_000;
    $display("WATCHDOG: not finished after 5 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
