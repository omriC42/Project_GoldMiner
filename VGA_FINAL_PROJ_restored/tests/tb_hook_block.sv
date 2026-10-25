// tb_hook_block.sv - Step 4: the hook_block wrapper (hook_move + hook_draw + new rules)
//
// Run:  ModelSim -> cd <project>/tests  ->  do run_hook_block.do      (expect VERSION 4.3)
// Checklist: tests/CHECKLIST_step4_hook_block.md
//
// Tests the NEW things in the wrapper:
//   * rope origin = miner top-left + (32,64), follows the miner
//   * no shot while moving; a shot needs a FRESH press of 2 while not moving
//   * hookBusy = 1 during SHOOT and RETRACT (Step 5 uses it to lock the miner)
//   * freeze passes through; catchType alone does nothing (only a REAL catch (hookCatch) loads a weight)
//   * drawing outputs: 2 full frames saved as images with the miner at different places
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_hook_block;
import hook_params::*;

logic clk = 0, resetN = 0, sof = 0;
always #5 clk = ~clk;

logic [10:0] pixelX = 0, pixelY = 0;
logic signed [10:0] minerX = 11'sd280, minerY = 11'sd100;   // game start position
logic minerMoving = 0, shoot_key = 0, tipCollision = 0, freeze = 0;
logic [2:0] catchType = 0;
logic hookDR, tipDR, hookBusy;
logic [7:0] hookRGB;
logic [1:0] hookState;

hook_block dut (.clk, .resetN, .startOfFrame(sof), .pixelX, .pixelY, .minerX, .minerY,
                .minerMoving, .shoot_key, .tipCollision, .goldDR(1'b0), .freeze, .catchType,
                .hookDR, .hookRGB, .tipDR, .hookBusy, .hookState, .hookCatch());   // Step 7 ports: no gold here

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            angle_deg, origin_x, origin_y, tip_dx, tip_dy;
assign angle_deg = dut.u_move.angle_idx * ANGLE_STEP_DEG;
assign origin_x  = dut.X0;
assign origin_y  = dut.Y0;
assign tip_dx    = dut.Xend - dut.X0;      // tip relative to the origin
assign tip_dy    = dut.Yend - dut.Y0;
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

task automatic frames(input int n);          // n fast frames (startOfFrame every ~40 clocks)
    repeat (n) begin
        @(negedge clk) sof = 1;
        @(negedge clk) sof = 0;
        repeat (38) @(negedge clk);
    end
endtask
task automatic press(ref logic k);
    @(negedge clk) k = 1;
    repeat (4) @(negedge clk);
    k = 0;
    @(negedge clk);
endtask

// ---------------- full-frame image (hook frozen: no startOfFrame while scanning) ----------------
logic [7:0] img [0:479][0:639];
int scan_extra = 0;
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic snapshot(input string fname);
    int qx, qy, fd, xmin, xmax, ymin, ymax; byte r, g, b; logic [7:0] c;
    qx = -1; qy = -1;
    for (int n = 0; n <= 640*480; n++) begin
        @(negedge clk);
        if (qx >= 0) img[qy][qx] = hookDR ? hookRGB : 8'hFF;
        if (n < 640*480) begin pixelX = n % 640; pixelY = n / 640; qx = n % 640; qy = n / 640; end
    end
    // nothing outside the rope box + claw box
    xmin = ((dut.X0 < dut.Xend) ? dut.X0 : dut.Xend) - 1;  xmax = ((dut.X0 < dut.Xend) ? dut.Xend : dut.X0) + 1;
    ymin = ((dut.Y0 < dut.Yend) ? dut.Y0 : dut.Yend) - 1;  ymax = ((dut.Y0 < dut.Yend) ? dut.Yend : dut.Y0) + 1;
    scan_extra = 0;
    for (int y = 0; y < 480; y++) for (int x = 0; x < 640; x++)
        if (img[y][x] != 8'hFF &&
            !(x >= xmin && x <= xmax && y >= ymin && y <= ymax) &&
            !(x >= dut.Xend-7 && x <= dut.Xend+8 && y >= dut.Yend-7 && y <= dut.Yend+8)) scan_extra++;
    // miner outline (yellow box, testbench only) so you can see where the miner is
    for (int x = 0; x < 64; x++) begin
        if (img[minerY][minerX+x] == 8'hFF)    img[minerY][minerX+x]    = 8'hFC;
        if (img[minerY+63][minerX+x] == 8'hFF) img[minerY+63][minerX+x] = 8'hFC;
        if (img[minerY+x][minerX] == 8'hFF)    img[minerY+x][minerX]    = 8'hFC;
        if (img[minerY+x][minerX+63] == 8'hFF) img[minerY+x][minerX+63] = 8'hFC;
    end
    fd = $fopen(fname, "wb");
    if (fd == 0) begin $display("   could not open %s", fname); return; end
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--) for (int x = 0; x < 640; x++) begin
        c = img[y][x];
        if (c == 8'hFF) begin r = 8'd110; g = 8'd72; b = 8'd40; end
        else begin r = {c[7:5], c[7:5], c[7:6]}; g = {c[4:2], c[4:2], c[4:3]}; b = {c[1:0], c[1:0], c[1:0], c[1:0]}; end
        $fwrite(fd, "%c%c%c", b, g, r);
    end
    $fclose(fd);
    $display("   image %s  (miner at %0d,%0d  origin %0d,%0d  tip %0d,%0d)", fname, minerX, minerY, dut.X0, dut.Y0, dut.Xend, dut.Yend);
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

int f, dx0, dy0, n_w0, n_w63, maxR;

initial begin
    $display("\n##### tb_hook_block VERSION 4.3 (2026-10-20) - if not the version Claude announced, run the full  do run_hook_block.do  #####");

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 reset");
    repeat (3) @(negedge clk);
    resetN = 1; @(negedge clk);
    check(hookState == 2'd0 && !hookBusy, "SWING and hookBusy = 0 after reset");
    check(origin_x == 280 + HOOK_DX && origin_y == 100 + HOOK_DY,
          $sformatf("rope origin = miner + (%0d,%0d) = (%0d,%0d)", HOOK_DX, HOOK_DY, origin_x, origin_y));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 origin follows the miner");
    frames(10);
    dx0 = tip_dx; dy0 = tip_dy;
    @(negedge clk) minerX = 11'sd100;               // miner jumps left (no frame in between)
    @(negedge clk);
    check(origin_x == 100 + HOOK_DX, $sformatf("miner at x=100 -> origin x = %0d", origin_x));
    check(tip_dx == dx0 && tip_dy == dy0, "the hook keeps its angle/length, it only moves with the miner");
    snapshot("frames/block_1_miner_left.bmp");
    check(img[dut.Yend][dut.Xend] == CLAW_COLOR, "image: claw on the tip");
    check(scan_extra == 0, $sformatf("image: nothing drawn away from rope + claw (%0d px)", scan_extra));
    @(negedge clk) minerX = 11'sd500;
    frames(20);
    check(origin_x == 500 + HOOK_DX, $sformatf("miner at x=500 -> origin x = %0d", origin_x));
    snapshot("frames/block_2_miner_right.bmp");
    check(img[dut.Yend][dut.Xend] == CLAW_COLOR, "image: claw on the tip");
    check(scan_extra == 0, $sformatf("image: nothing drawn away from rope + claw (%0d px)", scan_extra));
    @(negedge clk) minerX = 11'sd280;

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 no shot while moving");
    @(negedge clk) minerMoving = 1;                 // holding 4 or 6
    press(shoot_key); frames(3);
    check(hookState == 2'd0 && !hookBusy, "key 2 while moving -> ignored (still SWING)");
    @(negedge clk) shoot_key = 1;                   // press 2 and KEEP holding it ...
    frames(2);
    @(negedge clk) minerMoving = 0;                 // ... then stop moving
    frames(5);
    check(hookState == 2'd0, "stop moving while 2 is still held -> NO shot (needs a fresh press)");
    @(negedge clk) shoot_key = 0; frames(1);
    press(shoot_key); frames(1);
    check(hookState == 2'd1 && hookBusy, "fresh press of 2 while not moving -> SHOOT, hookBusy = 1");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 hookBusy during shoot+retract");
    frames(20);
    check(hookBusy, "hookBusy = 1 while shooting");
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;
    frames(1);
    check(hookState == 2'd2 && hookBusy, "RETRACT after tipCollision, hookBusy still 1");
    f = 0; while (hookState != 2'd0 && f < 500) begin frames(1); f++; end
    check(hookState == 2'd0 && !hookBusy, $sformatf("back to SWING after %0d frames -> hookBusy = 0 (miner free)", f));

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 freeze passes through");
    @(negedge clk) freeze = 1;
    dx0 = dut.u_move.angle_fp;
    frames(20);
    check(dut.u_move.angle_fp == dx0, "freeze = 1 -> swing stops");
    @(negedge clk) freeze = 0;
    frames(5);
    check(dut.u_move.angle_fp != dx0, "freeze = 0 -> swing continues");

    // ------------------------------------------------------------ T6
    begin_test(6, "T6 catchType alone = empty hook");
    @(negedge clk) catchType = 3'd0;
    press(shoot_key); frames(30);
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;
    n_w0 = 0; while (hookState != 2'd0 && n_w0 < 500) begin frames(1); n_w0++; end
    @(negedge clk) catchType = 3'd6;          // large rock on the input, but no real catch
    press(shoot_key); frames(30);
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;
    n_w63 = 0; while (hookState != 2'd0 && n_w63 < 500) begin frames(1); n_w63++; end
    check(n_w0 == n_w63, $sformatf("tipCollision (no gold) pulls back at EMPTY speed even with catchType 6: %0d and %0d frames", n_w0, n_w63));
    @(negedge clk) catchType = 3'd0;

    // ------------------------------------------------------------ end
    t_end[6] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(6);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Images: tests/frames/block_*.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #100_000_000;
    $display("WATCHDOG: not finished after 100 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
