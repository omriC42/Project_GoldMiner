// tb_hook_move.sv - testbench for hook_move (Step 1), made to be WATCHED in ModelSim
//
// Run:  ModelSim -> Transcript:  cd <project>/tests   then   do run_hook_move.do
//
// What you see:
//   * The simulation does NOT close by itself. It stops with $stop at the end and
//     the wave window stays open - you can scroll, zoom, add signals, "run" more.
//   * Wave window is grouped: test info / inputs / hook state / measurements.
//   * test_name (ASCII) shows which test is running at every moment.
//   * chk_pass (green) / chk_fail (red) pulse at the exact time of every check;
//     chk_name shows what was checked. A FAIL is visible right next to the signals
//     that caused it.
//   * angle, R, Xend, Yend are drawn as analog curves so you SEE the swing/shoot/retract.
//   * meas_* signals show the measured speeds in real units (deg/s, px/s, seconds).
//   * After the run, type   zt 3   in the Transcript to zoom on test T3 (any 1..8),
//     or   zt 0   for the whole run. Cursors T1..T8 mark the start of every test.
//
// Frame compression: startOfFrame every FRAME_CLKS clocks instead of 433,993.
// hook_move moves only on startOfFrame, so motion per frame is identical; all
// speeds are converted to real time with the measured 72.58 Hz.

`timescale 1ns/1ps
module tb_hook_move;
import hook_params::*;

localparam int  FRAME_CLKS = 20;
localparam real FPS        = FRAME_RATE_X100 / 100.0;   // 72.58

// ---------------- DUT signals ----------------
logic clk = 0, resetN = 0, sof = 0;
logic shoot_key = 0, tipCollision = 0, freeze = 0, restart = 0;   // restart: Step 10 (new level)
logic signed [10:0] X0 = 11'sd320, Y0 = 11'sd164;
logic signed [10:0] Xend, Yend;
logic [10:0] R;
logic [1:0]  hookState;
logic signed [9:0] dirCos, dirSin;     // Oct 2026: rope direction outputs

hook_move dut (.clk, .resetN, .startOfFrame(sof), .shoot_key, .tipCollision, .freeze, .restart,
               .retractStep(10'(RETRACT_EMPTY_STEP_FP)),   // Step 9 port: empty-hook speed
               .X0, .Y0, .Xend, .Yend, .R, .hookState, .dirCos, .dirSin);

// Oct 2026 (dirCos/dirSin outputs for the carried object): checked on EVERY clock against
// round(256*cos/sin(angle)) computed here with $cos/$sin - independent of the hook's table.
int dir_checks = 0, dir_bad = 0;
always @(posedge clk) if (resetN) begin
    automatic int ec = int'(256.0 * $cos(dut.angle_idx * 3 * 3.14159265358979 / 180.0));
    automatic int es = int'(256.0 * $sin(dut.angle_idx * 3 * 3.14159265358979 / 180.0));
    dir_checks++;
    if (int'(dirCos) != ec || int'(dirSin) != es) begin
        if (dir_bad < 3) $display("   dirCos/dirSin wrong at angle index %0d: %0d,%0d expected %0d,%0d", dut.angle_idx, dirCos, dirSin, ec, es);
        dir_bad++;
    end
end


always #5 clk = ~clk;

// startOfFrame: 1-clock pulse every FRAME_CLKS clocks + frame counter
int sofCnt = 0;
int frame_no = 0;
always @(posedge clk) begin
    sofCnt <= (sofCnt == FRAME_CLKS-1) ? 0 : sofCnt + 1;
    sof    <= (sofCnt == FRAME_CLKS-1);
    if (sof) frame_no <= frame_no + 1;
end

// ---------------- signals made for the wave window ----------------
logic [8*32:1] test_name = "start";   // shown as ASCII
int            test_no   = 0;
logic [8*64:1] chk_name  = "";        // last check (ASCII)
logic          chk_pass  = 0;         // pulse on every passing check
logic          chk_fail  = 0;         // pulse on every failing check
int            nPass = 0, nFail = 0;
int            angle_deg;             // angle in degrees, for reading
real           meas_swing_period_s = 0;  // full MIN->MAX->MIN swing
// swing limits from hook_params.sv (SWING_MIN_DEG / SWING_MAX_DEG) as LUT indices
localparam int  MIN_IDX = SWING_MIN_DEG / ANGLE_STEP_DEG;      // 15 deg -> 5
localparam int  MAX_IDX = SWING_MAX_DEG / ANGLE_STEP_DEG;      // 165 deg -> 55
localparam real SWING_PERIOD_EXP_S = 2.0 * (SWING_MAX_DEG - SWING_MIN_DEG) / SWING_DEG_PER_SEC; // 120 deg/s -> 2.50 s
real           meas_swing_deg_s    = 0;
real           meas_shoot_px_s     = 0;
real           meas_retract_px_s   = 0;
int            meas_R_changes_3frames = 0;

assign angle_deg = dut.angle_idx * ANGLE_STEP_DEG;

// test start/end times -> written to test_windows.do for the zt command and cursors
realtime t_start [0:15];
realtime t_end   [0:15];

task automatic begin_test(input int n, input string name);
    if (test_no > 0) t_end[test_no] = $realtime;
    test_no   = n;
    $sformat(test_name, "%s", name);
    t_start[n] = $realtime;
    $display("\n[%0t] ---- T%0d %s ----", $time, n, name);
endtask

task automatic check(input bit ok, input string what);
    $sformat(chk_name, "%s", what);
    if (ok) begin nPass++; chk_pass = 1; $display("[%0t]   PASS  %s", $time, what); end
    else    begin nFail++; chk_fail = 1; $display("[%0t]   FAIL  %s   <-----", $time, what); end
    #20;                                   // 2-clock wide pulse, visible in the wave
    chk_pass = 0; chk_fail = 0;
endtask

task automatic frames(input int n);        // wait n startOfFrame pulses
    repeat (n) @(posedge clk iff sof);
    @(posedge clk); #1;
endtask

task automatic do_reset();
    @(negedge clk) resetN = 0; shoot_key = 0; tipCollision = 0; freeze = 0;
    repeat (3) @(negedge clk);
    resetN = 1; @(posedge clk); #1;
endtask

task automatic press_shoot();               // press and release keypad 2 (driven on falling edge)
    @(negedge clk) shoot_key = 1;
    repeat (3) @(negedge clk);
    shoot_key = 0;
endtask

task automatic write_windows_file();
    int fd;
    fd = $fopen("test_windows.do", "w");
    $fdisplay(fd, "# generated by tb_hook_move: test start/end times");
    $fdisplay(fd, "set TW(0) {0 %0d}", longint'($realtime));
    for (int i = 1; i <= 9; i++) begin
        $fdisplay(fd, "set TW(%0d) {%0d %0d}", i, longint'(t_start[i]), longint'(t_end[i]));
        $fdisplay(fd, "catch {wave cursor add -time %0dns -name T%0d}", longint'(t_start[i]), i);
    end
    $fclose(fd);
endtask

int f, r0, r1, lastIdx, maxJump, minIdx, maxIdx, idx, jump;
real t;

initial begin
    $display("\n##### tb_hook_move VERSION 1.6 (file date 2026-10-25, + restart = new level) - if this is not the version Claude announced, run the full  do run_*.do  (restart does NOT recompile) #####");
    $display("\n===== tb_hook_move  (SWING %0d deg/s, SHOOT %0d px/s, RETRACT %0d px/s) =====",
             SWING_DEG_PER_SEC, SHOOT_PX_PER_SEC, RETRACT_EMPTY_PX_PER_SEC);
    $display("   per-frame steps (x64): swing %0d, shoot %0d, retract %0d",
             SWING_STEP_FP, SHOOT_STEP_FP, RETRACT_EMPTY_STEP_FP);
    $display("   swing limits: %0d..%0d deg (LUT index %0d..%0d), expected full swing %0.2f s",
             SWING_MIN_DEG, SWING_MAX_DEG, MIN_IDX, MAX_IDX, SWING_PERIOD_EXP_S);

    // ================================================================ T1
    begin_test(1, "T1 reset");
    do_reset();
    check(hookState == 2'd0,   "state = SWING after reset");
    check(R == MIN_R,          $sformatf("R = MIN_R (%0d), got %0d", MIN_R, R));
    check(dut.angle_idx == 30, "angle = 90 deg (straight down)");
    check(Xend == X0 && Yend == Y0 + MIN_R,
          $sformatf("tip under origin (%0d,%0d), got (%0d,%0d)", X0, Y0+MIN_R, Xend, Yend));
    frames(3);

    // ================================================================ T2
    begin_test(2, "T2 swing range + speed");
    // NOTE: dut.angle_idx is an UNSIGNED 6-bit signal. Comparing it directly with a
    // signed int (e.g. maxIdx = -1) makes SystemVerilog do an UNSIGNED compare
    // (-1 becomes 4294967295), so it is first copied into the signed int "idx".
    minIdx = 99; maxIdx = -1; maxJump = 0;
    idx = dut.angle_idx; lastIdx = idx;
    f = 0;
    while (idx != MIN_IDX && f < 300) begin frames(1); f++; idx = dut.angle_idx; lastIdx = idx; end  // go to the right-hand end
    check(idx == MIN_IDX, $sformatf("swing reaches %0d deg within 300 frames (took %0d)", SWING_MIN_DEG, f));
    f = 0;
    do begin                                      // one full cycle MIN -> MAX -> MIN
        frames(1); f++;
        idx = dut.angle_idx;
        if (idx < minIdx) minIdx = idx;
        if (idx > maxIdx) maxIdx = idx;
        jump = (idx > lastIdx) ? idx - lastIdx : lastIdx - idx;
        if (jump > maxJump) maxJump = jump;
        lastIdx = idx;
    end while (!(idx == MIN_IDX && maxIdx == MAX_IDX) && f < 800);   // bounded: a broken design FAILS instead of hanging
    t = f / FPS;
    meas_swing_period_s = t;
    meas_swing_deg_s    = 2.0 * (SWING_MAX_DEG - SWING_MIN_DEG) / t;
    $display("   full swing %0d->%0d->%0d = %0d frames = %0.2f s (%0.0f deg/s)",
             SWING_MIN_DEG, SWING_MAX_DEG, SWING_MIN_DEG, f, t, meas_swing_deg_s);
    check(minIdx == MIN_IDX && maxIdx == MAX_IDX,
          $sformatf("swing reaches %0d and %0d deg, never outside (saw %0d..%0d deg)",
                    SWING_MIN_DEG, SWING_MAX_DEG, minIdx*ANGLE_STEP_DEG, maxIdx*ANGLE_STEP_DEG));
    check(maxJump <= 2, $sformatf("smooth: max %0d deg per frame", 3*maxJump));
    check(t > 0.9*SWING_PERIOD_EXP_S && t < 1.1*SWING_PERIOD_EXP_S,
          $sformatf("full swing %0.2f s (target %0.2f s +-10%%)", t, SWING_PERIOD_EXP_S));

    // ================================================================ T3
    begin_test(3, "T3 shoot down + speed + floor");
    do_reset();
    press_shoot(); @(posedge clk); #1;
    check(hookState == 2'd1, "state = SHOOT after pressing 2");
    frames(5);  r0 = R;
    frames(50); r1 = R;
    meas_shoot_px_s = (r1 - r0) / 50.0 * FPS;
    check(meas_shoot_px_s > 190 && meas_shoot_px_s < 210,
          $sformatf("shoot speed %0.1f px/s (target 190..210)", meas_shoot_px_s));
    check(dut.angle_idx == 30, "angle frozen while shooting");
    f = 0;
    while (hookState == 2'd1 && f < 1000) begin frames(1); f++; end
    check(hookState == 2'd2, "floor reached -> RETRACT");
    check(Yend >= Y_MAX && Yend <= Y_MAX + 3,
          $sformatf("tip stops at floor: Yend = %0d (Y_MAX = %0d)", Yend, Y_MAX));

    // ================================================================ T4
    begin_test(4, "T4 retract once/frame + speed");
    r0 = R; f = 0;
    repeat (3 * FRAME_CLKS) begin                 // watch R on EVERY clock for 3 frames
        @(posedge clk); #1;
        if (R != r0) begin f++; r0 = R; end
    end
    meas_R_changes_3frames = f;
    check(f <= 3, $sformatf("R changed %0d times in 3 frames (old bug: every clock)", f));
    frames(1); r0 = R;
    frames(20); r1 = R;
    meas_retract_px_s = (r0 - r1) / 20.0 * FPS;
    check(meas_retract_px_s > 285 && meas_retract_px_s < 315,
          $sformatf("retract speed %0.1f px/s (target 285..315)", meas_retract_px_s));
    f = 0;
    while (hookState == 2'd2 && f < 1000) begin frames(1); f++; end
    check(hookState == 2'd0, "back to SWING after retract");
    check(R == MIN_R, $sformatf("R back to exactly MIN_R, got %0d", R));

    // ================================================================ T5
    begin_test(5, "T5 hold key 2 = one shot only");
    do_reset();
    @(negedge clk) shoot_key = 1;                 // press and HOLD
    frames(1);
    check(hookState == 2'd1, "shoot on press");
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;   // end the shot quickly
    f = 0; while (hookState != 2'd0 && f < 1000) begin frames(1); f++; end
    frames(30);
    check(hookState == 2'd0, "key still held 30 frames -> stays SWING");
    @(negedge clk) shoot_key = 0; frames(1);
    press_shoot(); @(posedge clk); #1;
    check(hookState == 2'd1, "release + press again -> shoots");

    // ================================================================ T6
    begin_test(6, "T6 tip collision -> retract");
    do_reset(); press_shoot(); frames(10);
    r0 = R;
    @(negedge clk) tipCollision = 1; @(posedge clk); #1; tipCollision = 0;
    check(hookState == 2'd2, "RETRACT one clock after tipCollision");
    check(R == r0, "R did not grow on the collision clock");
    frames(5);

    // ================================================================ T7
    begin_test(7, "T7 freeze (pause/game over)");
    do_reset(); frames(3);
    lastIdx = dut.angle_fp; frames(20);
    check(dut.angle_fp != lastIdx, "swing moves when freeze = 0");
    @(negedge clk) freeze = 1;
    lastIdx = dut.angle_fp; r0 = R;
    press_shoot(); frames(20);
    check(dut.angle_fp == lastIdx && R == r0 && hookState == 2'd0,
          "freeze = 1: nothing moves, key 2 ignored");
    @(negedge clk) freeze = 0;
    frames(10);

    // ================================================================ T8
    begin_test(8, "T8 side walls");
    do_reset();
    f = 0; while (dut.angle_idx != MIN_IDX && f < 50000) begin @(posedge clk); #1; f++; end   // bounded wait
    check(dut.angle_idx == MIN_IDX, $sformatf("swing reached its right end (%0d deg) before shooting", SWING_MIN_DEG));
    press_shoot();   // aim right (press inside the same frame)
    f = 0; while (hookState == 2'd1 && f < 1000) begin frames(1); f++; end
    check(hookState == 2'd2 && Xend >= X_MAX,
          $sformatf("right wall: retract at Xend = %0d (X_MAX = %0d)", Xend, X_MAX));
    f = 0; while (hookState != 2'd0 && f < 1000) begin frames(1); f++; end
    f = 0; while (dut.angle_idx != MAX_IDX && f < 50000) begin @(posedge clk); #1; f++; end   // bounded wait
    check(dut.angle_idx == MAX_IDX, $sformatf("swing reached its left end (%0d deg) before shooting", SWING_MAX_DEG));
    press_shoot();   // aim left
    f = 0; while (hookState == 2'd1 && f < 1000) begin frames(1); f++; end
    check(hookState == 2'd2 && Xend <= X_MIN,
          $sformatf("left wall: retract at Xend = %0d (X_MIN = %0d)", Xend, X_MIN));
    f = 0; while (hookState != 2'd0 && f < 1000) begin frames(1); f++; end
    frames(5);

    // ================================================================ T9 (Step 10)
    // restart = 1-clock pulse (game_hud newLevel in the game): back to the top from any state
    begin_test(9, "T9 restart = new level");
    do_reset(); press_shoot(); frames(10);                       // shooting, rope long
    r0 = R;
    @(negedge clk) restart = 1; @(posedge clk); #1; restart = 0;
    check(r0 > MIN_R && hookState == 2'd0 && R == MIN_R && dut.angle_fp == 13'(30 * FP),
          $sformatf("restart during SHOOT (R was %0d): SWING, R = %0d (MIN_R %0d), pointing straight down", r0, R, MIN_R));
    press_shoot(); frames(10);
    @(negedge clk) tipCollision = 1; @(posedge clk); #1; tipCollision = 0;
    frames(2);                                                    // now pulling back
    r0 = R;
    @(negedge clk) restart = 1; @(posedge clk); #1; restart = 0;
    check(r0 > MIN_R && hookState == 2'd0 && R == MIN_R && dut.angle_fp == 13'(30 * FP),
          $sformatf("restart during RETRACT (R was %0d): SWING, R = %0d, straight down", r0, R));
    press_shoot(); frames(8);
    @(negedge clk) freeze = 1; frames(2);
    @(negedge clk) restart = 1; @(posedge clk); #1; restart = 0;
    check(hookState == 2'd0 && R == MIN_R, "restart wins over freeze (frozen SHOOT -> SWING at the top)");
    @(negedge clk) freeze = 0;
    lastIdx = dut.angle_fp; frames(10);
    check(dut.angle_fp != lastIdx && hookState == 2'd0, "after restart the hook swings again");
    press_shoot(); frames(3);
    check(hookState == 2'd1, "and a new press of 2 shoots normally");
    f = 0; while (hookState != 2'd0 && f < 2000) begin frames(1); f++; end

    check(dir_bad == 0, $sformatf("dirCos/dirSin = the rope angle on all %0d clocks of T1..T9 (%0d wrong)", dir_checks, dir_bad));

    // ================================================================ end
    t_end[9]  = $realtime;
    test_no   = 0;
    test_name = (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS";
    write_windows_file();
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Simulation PAUSED (not closed). Inspect the wave window.");
    $display("Type  zt <n>  to zoom on test n (1..9),  zt 0  for everything.\n");
    $stop;                                       // pause - nothing is closed
end

// safety net: if something hangs, pause (do not exit) so you can see where
initial begin
    #20_000_000;
    $display("WATCHDOG: simulation did not finish in 20 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
