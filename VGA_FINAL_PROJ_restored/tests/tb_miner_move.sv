// tb_miner_move.sv - Step 5: miner movement + the new hook lock
//
// Run:  ModelSim -> cd <project>/tests -> do run_miner_move.do        (expect VERSION 5.3)
// Checklist: tests/CHECKLIST_step5_miner.md
//
// Checks: normal movement with keys 4/6 is unchanged, minerMoving = key 4 or 6,
// hookBusy = 1 stops the miner in the SAME frame (also while gliding after a key release)
// and ignores the keys, hookBusy = 0 frees it again, screen borders still work.
// Oct 2026 (5.3): movingLeft / movingRight follow the REAL speed (dust): 1 while moving or gliding,
// 0 at a border with the key still held and 0 while hookBusy.
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded
// loops, stimulus on the falling edge.

`timescale 1ns/1ps
module tb_miner_move;

logic clk = 0, resetN = 0, sof = 0;
always #5 clk = ~clk;

logic key4 = 0, key6 = 0, hookBusy = 0;
logic signed [10:0] topLeftX, topLeftY;
logic minerMoving, movingLeft, movingRight;

// same parameter values as the game's top level (TOP_VGA_DEMO_KBD passes initial_x 280, x speed 60)
miner_move #(.INITIAL_X(280), .INITIAL_X_SPEED(60)) dut (
    .clk, .resetN, .startOfFrame(sof),
    .Y_direction_key(key4), .toggle_x_key(key6),
    .collision(1'b0), .HitEdgeCode(3'b000),
    .hookBusy, .minerMoving, .movingLeft, .movingRight,
    .topLeftX, .topLeftY
);

logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            minerX, xspeed;
assign minerX = topLeftX;
assign xspeed = dut.Xspeed;
realtime t_start [0:8];
realtime t_end   [0:8];

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
task automatic frames(input int n);     // n frames: startOfFrame pulse, then let the FSM finish
    repeat (n) begin
        @(negedge clk) sof = 1;
        @(negedge clk) sof = 0;
        repeat (18) @(negedge clk);
    end
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

int x0, x1, f;

initial begin
    $display("\n##### tb_miner_move VERSION 5.3 (2026-10-25, movingLeft/movingRight = real motion for the dust) - if not the version Claude announced, run the full  do run_miner_move.do  #####");

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 reset position");
    repeat (3) @(negedge clk); resetN = 1;
    frames(3);
    check(topLeftX == 280 && topLeftY == 100, $sformatf("miner starts at (280,100): (%0d,%0d)", topLeftX, topLeftY));
    check(!minerMoving, "no key -> minerMoving = 0");

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 key 6 moves right (unchanged)");
    @(negedge clk) key6 = 1;
    @(negedge clk);
    check(minerMoving, "key 6 held -> minerMoving = 1 (immediately)");
    x0 = topLeftX; frames(30); x1 = topLeftX;
    check(x1 > x0 + 10, $sformatf("moved right: %0d -> %0d", x0, x1));
    check(movingRight && !movingLeft, "moving right -> movingRight = 1, movingLeft = 0");
    @(negedge clk) key6 = 0;
    @(negedge clk);
    check(!minerMoving, "key released -> minerMoving = 0 (immediately)");
    x0 = topLeftX; frames(30); x1 = topLeftX;
    check(x1 > x0, $sformatf("glides a little after release (normal behaviour): %0d -> %0d", x0, x1));
    check(xspeed == 0, "then stops (speed 0)");
    check(!movingRight && !movingLeft, "stopped -> movingRight = movingLeft = 0 (no dust)");

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 hookBusy locks while key held");
    @(negedge clk) key6 = 1;
    frames(15);
    check(xspeed > 0, $sformatf("moving right, speed %0d", xspeed));
    @(negedge clk) hookBusy = 1;                    // the hook was fired
    frames(1);
    check(xspeed == 0, "hookBusy -> speed 0 in the SAME frame");
    x0 = topLeftX; frames(30); x1 = topLeftX;
    check(x1 == x0, $sformatf("key 6 still held for 30 frames, miner does not move: %0d -> %0d", x0, x1));
    check(!movingRight && !movingLeft, "hookBusy with key 6 held -> movingRight = 0 (no dust while the hook is out)");
    @(negedge clk) key6 = 0; hookBusy = 0;

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 hookBusy stops a glide");
    @(negedge clk) key4 = 1;
    frames(15);
    @(negedge clk) key4 = 0;                        // released -> would glide for several frames
    frames(1);
    check(xspeed < 0, $sformatf("gliding left after release, speed %0d", xspeed));
    check(movingLeft && !movingRight, "gliding left with no key -> movingLeft = 1 (dust continues during the glide)");
    @(negedge clk) hookBusy = 1;
    frames(1);
    x0 = topLeftX; frames(20); x1 = topLeftX;
    check(xspeed == 0 && x1 == x0, $sformatf("hookBusy stops the glide at once: %0d -> %0d", x0, x1));

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 free again after hookBusy");
    @(negedge clk) hookBusy = 0; key4 = 1;
    x0 = topLeftX; frames(20); x1 = topLeftX;
    check(x1 < x0 - 5, $sformatf("hookBusy = 0 -> key 4 moves left again: %0d -> %0d", x0, x1));

    // ------------------------------------------------------------ T6
    begin_test(6, "T6 left border still works");
    f = 0; while (topLeftX > 2 && f < 1000) begin frames(10); f += 10; end
    frames(10);
    check(topLeftX == 2, $sformatf("stops at the left border x = 2 (got %0d)", topLeftX));
    check(!movingLeft && !movingRight, "key 4 still held at the left border -> movingLeft = 0 (no dust against the wall)");
    @(negedge clk) key4 = 0;
    frames(5);

    // ------------------------------------------------------------ end
    t_end[6] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(6);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #50_000_000;
    $display("WATCHDOG: not finished after 50 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
