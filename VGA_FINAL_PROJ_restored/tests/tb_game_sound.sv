// tb_game_sound.sv - Step 11: the game sounds (game_sound -> melody_player_1 -> GameJukeBox)
//
// Run:  ModelSim -> cd <project>/tests -> do run_game_sound.do        (expect VERSION 11.0)
// Checklist: tests/CHECKLIST_step11_sound.md
//
// melody_player_1 runs with SIMULATION_MODE = 1: its "1/100 s" tick comes every 21 clocks, so a
// whole sound takes a few thousand clocks. All lengths are checked in TICKS (= 1/100 s on the board).
// Every note that is played is logged (pitch, ticks, heard or rest) and compared with an
// INDEPENDENT copy of the 4 tunes written below (pitch index, beats); the tempo and the gap come
// from game_params.sv.
//
// T1 each event alone -> its sound: right notes in the right order, each note = beats x beat ticks,
//    every gap = SOUND_GAP_CS ticks, the rest of the fanfare is silent, ONE melodyEnded at the end
// T2 the on/off switches: a second game_sound with all sounds OFF never starts anything;
//    the normal one started exactly the 4 sounds of T1
// T3 newest wins: game over playing, a catch comes -> the catch sound starts at once from its
//    first note and plays completely; the cut game over never ends. gameOver staying 1 -> no repeat
// T4 two events on the SAME clock -> the more important sound (game over > level > money > catch)
// T5 game held in reset (opening screen): events -> no sound at all
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_game_sound;
import game_params::*;

logic clk = 0, resetN = 0, gameResetN = 0;
always #5 clk = ~clk;

// events (like the TOP nets)
logic objectCollected = 0, deliverPulse = 0, newLevel = 0, gameOver = 0;
logic soundStart;  logic [3:0] soundSelect;
logic offStart;    logic [3:0] offSelect;
logic [3:0] tone;  logic EnableSound, melodyEnded;

game_sound gs (.clk, .resetN(gameResetN), .catchPulse(objectCollected), .moneyPulse(deliverPulse),
               .newLevel, .gameOver, .startSound(soundStart), .soundSelect);
// T2: the same block with every sound switched off
game_sound #(.CATCH_ON(1'b0), .MONEY_ON(1'b0), .LEVEL_ON(1'b0), .GAMEOVER_ON(1'b0)) gsOff (
               .clk, .resetN(gameResetN), .catchPulse(objectCollected), .moneyPulse(deliverPulse),
               .newLevel, .gameOver, .startSound(offStart), .soundSelect(offSelect));
melody_player_1 #(.SIMULATION_MODE(1'b1)) player (
               .resetN, .CLOCK_31p5(clk), .startMelodyKey(soundStart), .melodySelect(soundSelect),
               .tone, .EnableSoundOut(EnableSound), .melodyEnded);

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

// ---------------- the 4 tunes, written again here (independent of GameJukeBox) ----------------
// pitch index: 0 do, 4 mi, 5 fa, 6 fa#, 7 sol, 12 DO (next octave), 15 = rest
localparam int REST = 15;
int exp_pitch [1:4][0:7];
int exp_beats [1:4][0:7];
int exp_n     [1:4];
int exp_beat  [1:4];
initial begin
    exp_n[1] = 2; exp_beat[1] = SOUND_BEAT_FAST_CS;                    // catch
    exp_pitch[1][0] = 7;  exp_beats[1][0] = 2;   exp_pitch[1][1] = 0;  exp_beats[1][1] = 3;
    exp_n[2] = 4; exp_beat[2] = SOUND_BEAT_FAST_CS;                    // money
    exp_pitch[2][0] = 0;  exp_beats[2][0] = 1;   exp_pitch[2][1] = 4;  exp_beats[2][1] = 1;
    exp_pitch[2][2] = 7;  exp_beats[2][2] = 1;   exp_pitch[2][3] = 12; exp_beats[2][3] = 4;
    exp_n[3] = 7; exp_beat[3] = SOUND_BEAT_SLOW_CS;                    // level won
    exp_pitch[3][0] = 0;  exp_beats[3][0] = 2;   exp_pitch[3][1] = 4;  exp_beats[3][1] = 2;
    exp_pitch[3][2] = 7;  exp_beats[3][2] = 2;   exp_pitch[3][3] = 12; exp_beats[3][3] = 2;
    exp_pitch[3][4] = REST; exp_beats[3][4] = 1; exp_pitch[3][5] = 7;  exp_beats[3][5] = 2;
    exp_pitch[3][6] = 12; exp_beats[3][6] = 6;
    exp_n[4] = 4; exp_beat[4] = SOUND_BEAT_SLOW_CS;                    // game over
    exp_pitch[4][0] = 7;  exp_beats[4][0] = 4;   exp_pitch[4][1] = 6;  exp_beats[4][1] = 4;
    exp_pitch[4][2] = 5;  exp_beats[4][2] = 4;   exp_pitch[4][3] = 4;  exp_beats[4][3] = 10;
end
function automatic string snd_name(input int s);
    case (s) 1: return "catch"; 2: return "money"; 3: return "level won"; 4: return "game over"; default: return "none"; endcase
endfunction

// ---------------- note log (what the player really played) ----------------
// sampled at the clock edge = the values BEFORE the edge
int  log_pitch [0:31], log_ticks [0:31], log_heard [0:31], log_gap [0:31];
int  log_n = 0, gap_n = 0;
int  ticks = 0, heard = 0, gticks = 0;
int  n_start = 0, n_off_start = 0, n_ended = 0, n_sound_idle = 0;
int  cur_pitch, cur_ticks;                       // for the waves
logic tick;  assign tick = player.hundredthSecPulse;
// player state (melody_player_1 SM_Maestro): 0 idle, 1 load, 2 playNote, 3 gap, 4 ended
localparam int ST_IDLE = 0, ST_LOAD = 1, ST_PLAY = 2, ST_GAP = 3, ST_ENDED = 4;
int st;  assign st = int'(player.SM_Maestro);
always @(posedge clk) begin
    if (soundStart)  n_start++;
    if (offStart)    n_off_start++;
    if (melodyEnded) n_ended++;
    if (EnableSound && st == ST_IDLE && !melodyEnded) n_sound_idle++;   // sound while idle
    if (st == ST_PLAY) begin
        if (tick) ticks++;
        if (EnableSound) heard = 1;
        if (player.noteTimeCounter == 0 && player.note_length != 0 && !soundStart) begin   // note ends now
            log_pitch[log_n] = tone; log_ticks[log_n] = ticks; log_heard[log_n] = heard;
            if (log_n < 31) log_n++;
            ticks = 0; heard = 0;
        end
    end
    else if (st == ST_GAP) begin
        if (tick) gticks++;
        if (player.noteTimeCounter == 0 && !soundStart) begin
            log_gap[gap_n] = gticks; if (gap_n < 31) gap_n++; gticks = 0;
        end
    end
    else begin ticks = 0; heard = 0; gticks = 0; end
    cur_pitch = tone; cur_ticks = ticks;
end
task automatic clear_log();
    log_n = 0; gap_n = 0; ticks = 0; heard = 0; gticks = 0;
endtask
// compare the log with tune s; returns problems in two strings
task automatic compare(input int s, output bit notes_ok, output bit time_ok, output string why);
    notes_ok = (log_n == exp_n[s]); time_ok = (gap_n == exp_n[s]); why = "";
    for (int i = 0; i < exp_n[s] && i < log_n; i++) begin
        if (log_pitch[i] != exp_pitch[s][i] || log_heard[i] != (exp_pitch[s][i] != REST)) begin
            notes_ok = 0; why = {why, $sformatf(" note%0d pitch %0d heard %0d (exp %0d);", i, log_pitch[i], log_heard[i], exp_pitch[s][i])};
        end
        if (log_ticks[i] != exp_beats[s][i] * exp_beat[s]) begin
            time_ok = 0; why = {why, $sformatf(" note%0d %0d ticks (exp %0d);", i, log_ticks[i], exp_beats[s][i] * exp_beat[s])};
        end
    end
    for (int i = 0; i < gap_n; i++)
        if (log_gap[i] != SOUND_GAP_CS) begin time_ok = 0; why = {why, $sformatf(" gap%0d %0d ticks;", i, log_gap[i])}; end
endtask
// wait until the player is idle again (bounded)
task automatic wait_end(output int clocks);
    clocks = 0;
    while ((st != ST_IDLE || soundStart) && clocks < 20000) begin @(negedge clk); clocks++; end
    repeat (5) @(negedge clk);
endtask
task automatic pulse(ref logic sig);
    @(negedge clk) sig = 1; @(negedge clk) sig = 0;
endtask

int  clocks, e0, s0;
bit  nok, tok;
string why;
int  sel_after;

initial begin
    $display("\n##### tb_game_sound VERSION 11.0 (2026-10-25, game sounds: newest wins) - if not the version Claude announced, run the full  do run_game_sound.do  #####");
    $display("   game_params: beat fast %0d / slow %0d (1/100 s), gap %0d, switches catch %0d money %0d level %0d game over %0d",
             SOUND_BEAT_FAST_CS, SOUND_BEAT_SLOW_CS, SOUND_GAP_CS, SOUND_CATCH_ON, SOUND_MONEY_ON, SOUND_LEVEL_ON, SOUND_GAMEOVER_ON);
    repeat (3) @(negedge clk);
    resetN = 1; gameResetN = 1;
    repeat (50) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 each event -> its sound");
    for (int s = 1; s <= 4; s++) begin
        clear_log(); e0 = n_ended;
        case (s)
            1: pulse(objectCollected);
            2: pulse(deliverPulse);
            3: pulse(newLevel);
            4: begin @(negedge clk) gameOver = 1; end
        endcase
        @(negedge clk); sel_after = soundSelect;
        wait_end(clocks);
        compare(s, nok, tok, why);
        check(nok && sel_after == s && n_ended == e0 + 1,
              $sformatf("%s: sound %0d, %0d notes in the right order (rest silent), ONE melodyEnded%s", snd_name(s), sel_after, log_n, nok ? "" : why));
        check(tok, $sformatf("%s: every note = beats x %0d ticks, every gap = %0d ticks (%0d clocks long)%s",
                             snd_name(s), exp_beat[s], SOUND_GAP_CS, clocks, tok ? "" : why));
        if (s == 4) @(negedge clk) gameOver = 0;
        repeat (100) @(negedge clk);
    end

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 on/off switches");
    check(n_off_start == 0 && n_start == 4 && n_sound_idle == 0,
          $sformatf("all-OFF block started %0d sounds (exp 0); normal block started %0d (exp 4); sound while idle %0d clocks",
                    n_off_start, n_start, n_sound_idle));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 newest wins");
    @(negedge clk) gameOver = 1;                                // game over sound starts
    clocks = 0;
    while (!(st == ST_PLAY && player.noteIndex == 1) && clocks < 20000) begin @(negedge clk); clocks++; end
    repeat (40) @(negedge clk);                                 // in the middle of its 2nd note
    e0 = n_ended; clear_log();
    pulse(objectCollected);                                     // a catch -> cuts the game over sound
    repeat (2) @(negedge clk);
    check(soundSelect == 4'(SND_CATCH) && st == ST_PLAY && player.noteIndex == 0,
          $sformatf("catch during game over: within 3 clocks the player plays note 0 of sound %0d (catch)", soundSelect));
    wait_end(clocks);
    compare(1, nok, tok, why);
    check(nok && tok && n_ended == e0 + 1,
          $sformatf("the WHOLE catch sound played (%0d notes, timing ok), the cut game over never ended (melodyEnded +%0d)%s",
                    log_n, n_ended - e0, (nok && tok) ? "" : why));
    s0 = n_start;
    repeat (5000) @(negedge clk);                               // gameOver is STILL 1
    check(n_start == s0 && st == ST_IDLE, "gameOver stays 1 for 5000 clocks: no second game over sound");
    @(negedge clk) gameOver = 0;
    repeat (20) @(negedge clk);

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 same clock -> most important");
    @(negedge clk) begin newLevel = 1; deliverPulse = 1; end
    @(negedge clk) begin newLevel = 0; deliverPulse = 0; end
    check(soundSelect == 4'(SND_LEVEL), $sformatf("level + money on one clock -> sound %0d (exp %0d level)", soundSelect, SND_LEVEL));
    repeat (50) @(negedge clk);
    @(negedge clk) begin deliverPulse = 1; objectCollected = 1; end
    @(negedge clk) begin deliverPulse = 0; objectCollected = 0; end
    check(soundSelect == 4'(SND_MONEY), $sformatf("money + catch on one clock -> sound %0d (exp %0d money)", soundSelect, SND_MONEY));
    repeat (50) @(negedge clk);
    @(negedge clk) begin gameOver = 1; newLevel = 1; end
    @(negedge clk) newLevel = 0;
    check(soundSelect == 4'(SND_GAMEOVER), $sformatf("game over + level on one clock -> sound %0d (exp %0d game over)", soundSelect, SND_GAMEOVER));
    wait_end(clocks);
    @(negedge clk) gameOver = 0;

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 opening screen = silent");
    @(negedge clk) gameResetN = 0;                              // game held in reset (start_screen)
    s0 = n_start;
    pulse(objectCollected); pulse(deliverPulse); pulse(newLevel);
    @(negedge clk) gameOver = 1; repeat (5) @(negedge clk); gameOver = 0;
    repeat (2000) @(negedge clk);
    check(n_start == s0 && st == ST_IDLE && !EnableSound,
          "gameResetN = 0: all four events -> no sound started, the player stays idle and silent");
    @(negedge clk) gameResetN = 1;

    // ------------------------------------------------------------ end
    t_end[5] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(5);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #20_000_000;
    $display("WATCHDOG: not finished after 20 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
