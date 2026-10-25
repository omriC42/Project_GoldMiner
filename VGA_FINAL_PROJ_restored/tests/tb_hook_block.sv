// tb_hook_block.sv - Step 4: the hook_block wrapper (hook_move + hook_draw + new rules)
//
// Run:  ModelSim -> cd <project>/tests  ->  do run_hook_block.do      (expect VERSION 4.5)
// Checklist: tests/CHECKLIST_step4_hook_block.md
//
// Tests the NEW things in the wrapper:
//   * rope origin = miner top-left + (32,64), follows the miner
//   * no shot while moving; a shot needs a FRESH press of 2 while not moving
//   * hookBusy = 1 during SHOOT and RETRACT (Step 5 uses it to lock the miner)
//   * freeze passes through; catchType alone does nothing (only a REAL catch (hookCatch) loads a weight)
//   * drawing outputs: 2 full frames saved as images with the miner at different places
//   * Oct 2026 (4.4): CARRY + SCORE AT THE TOP. T7 catches each of the 6 objects (a fake gold field:
//     goldDR = 1 while the scan is on the claw): the object hangs on the claw only during RETRACT
//     (claw drawn over it, it never shows on tipDR), and exactly ONE deliverPulse with the right
//     value comes when the hook is back up. T8 empty pull-back: no carry, no delivery.
//     T9 nothing is carried while SHOOTING.
//   * Step 10 (4.5): T10 freeze (= game over) in the middle of a shot, claw on gold: NO catch, nothing
//     moves, key 2 ignored; after unfreeze the shot goes on. T11 newLevel while pulling an object
//     back: hook straight home empty, NO deliverPulse (the object is lost), nothing on the claw;
//     the next catch works normally.
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_hook_block;
import hook_params::*;

logic clk = 0, resetN = 0, sof = 0;
always #5 clk = ~clk;

logic [10:0] pixelX = 0, pixelY = 0;
logic signed [10:0] minerX = 11'sd280, minerY = 11'sd100;   // game start position
logic minerMoving = 0, shoot_key = 0, tipCollision = 0, freeze = 0, newLevel = 0;
logic [2:0] catchType = 0;
logic hookDR, tipDR, hookBusy;
logic [7:0] hookRGB;
logic [1:0] hookState;
logic goldDR_tb = 0;                        // fake gold field: 1 = "the pixel is gold"
logic hookCatch, deliverPulse;
logic [5:0] deliverValue;
int   n_deliver = 0, last_deliver = -1;
always @(posedge clk) if (deliverPulse) begin n_deliver++; last_deliver = deliverValue; end
int   n_hookCatch = 0;
always @(posedge clk) if (hookCatch) n_hookCatch++;

hook_block dut (.clk, .resetN, .startOfFrame(sof), .pixelX, .pixelY, .minerX, .minerY,
                .minerMoving, .shoot_key, .tipCollision, .goldDR(goldDR_tb), .freeze, .newLevel, .catchType,
                .hookDR, .hookRGB, .tipDR, .hookBusy, .hookState, .hookCatch,
                .deliverPulse, .deliverValue);

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

// ---------------- carry helpers (4.4) ----------------
function automatic int value_of(input int t);          // expected dollars = game_params.sv
    case (t)
        1: return game_params::GOLD_SMALL_VALUE;  2: return game_params::GOLD_MEDIUM_VALUE; 3: return game_params::GOLD_LARGE_VALUE;
        4: return game_params::ROCK_SMALL_VALUE;  5: return game_params::ROCK_MEDIUM_VALUE; 6: return game_params::ROCK_LARGE_VALUE;
        default: return 0;
    endcase
endfunction
// shoot, and after 15 frames let the claw "touch gold" of type t (the fake field reports type t)
task automatic catch_object(input int t);
    press(shoot_key); frames(15);
    @(negedge clk) begin catchType = 3'(t); goldDR_tb = 1; pixelX = dut.Xend; pixelY = dut.Yend; end
    repeat (6) @(negedge clk);
    goldDR_tb = 0;
    @(negedge clk);
endtask
// scan a 180x180 window around the claw tip (hook frozen: no startOfFrame) and count
int n_carry = 0, n_claw = 0, n_order_bad = 0, n_or_bad = 0;
task automatic scan_carry();
    int qx, qy, x0, y0;
    n_carry = 0; n_claw = 0; n_order_bad = 0; n_or_bad = 0; qx = -1;
    x0 = dut.Xend - 90; y0 = dut.Yend - 90;
    for (int n = 0; n <= 180*180; n++) begin
        @(negedge clk);
        if (qx >= 0) begin                                       // outputs of the pixel one clock ago
            if (dut.carryDR) n_carry++;
            if (tipDR) n_claw++;
            if (hookDR !== (dut.drawDR || dut.carryDR)) n_or_bad++;
            if (tipDR && hookRGB !== CLAW_COLOR) n_order_bad++;                       // claw on top
            if (!tipDR && dut.carryDR && hookRGB !== dut.carryRGB) n_order_bad++;      // object over the rope
        end
        qx = x0 + n % 180; qy = y0 + n / 180;
        if (n < 180*180 && qx >= 0 && qx < 640 && qy >= 0 && qy < 480) begin pixelX = qx; pixelY = qy; end
        else begin qx = -1; pixelX = 0; pixelY = 0; end
    end
endtask
int n_before, fr;

initial begin
    $display("\n##### tb_hook_block VERSION 4.5 (2026-10-25, game over freeze + new level) - if not the version Claude announced, run the full  do run_hook_block.do  #####");

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

    check(n_deliver == 0, $sformatf("no deliverPulse from any of these empty pull-backs (%0d)", n_deliver));

    // ------------------------------------------------------------ T7
    begin_test(7, "T7 carry + score at the top x6");
    for (int t = 1; t <= 6; t++) begin
        n_before = n_deliver;
        catch_object(t);
        check(hookState == 2'd2 && dut.caught && int'(dut.caughtType) == t && n_deliver == n_before,
              $sformatf("%0d: caught type %0d -> RETRACT, nothing delivered yet", t, int'(dut.caughtType)));
        frames(3);
        scan_carry();
        check(n_carry > 0 && n_order_bad == 0 && n_or_bad == 0,
              $sformatf("%0d: object on the claw while pulling back: %0d px, claw on top, order errors %0d, hookDR errors %0d", t, n_carry, n_order_bad, n_or_bad));
        fr = 0; while (hookState != 2'd0 && fr < 2000) begin frames(1); fr++; end
        repeat (3) @(negedge clk);
        check(n_deliver == n_before + 1 && last_deliver == value_of(t),
              $sformatf("%0d: back at the top after %0d frames -> ONE deliverPulse, value %0d (game_params %0d)", t, fr, last_deliver, value_of(t)));
    end
    scan_carry();
    check(n_carry == 0 && !dut.caught, $sformatf("back to SWING: nothing hangs on the claw any more (%0d px)", n_carry));
    @(negedge clk) catchType = 3'd0;

    // ------------------------------------------------------------ T8
    begin_test(8, "T8 empty pull-back");
    n_before = n_deliver;
    press(shoot_key); frames(20);
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;
    frames(2);
    scan_carry();
    check(hookState == 2'd2 && n_carry == 0, $sformatf("empty RETRACT: nothing on the claw (%0d px)", n_carry));
    fr = 0; while (hookState != 2'd0 && fr < 2000) begin frames(1); fr++; end
    repeat (3) @(negedge clk);
    check(n_deliver == n_before, "empty pull-back reached the top: NO deliverPulse");

    // ------------------------------------------------------------ T9
    begin_test(9, "T9 nothing carried while shooting");
    press(shoot_key); frames(10);
    scan_carry();
    check(hookState == 2'd1 && n_carry == 0 && n_claw > 0, $sformatf("SHOOT: claw drawn (%0d px), no object (%0d px)", n_claw, n_carry));
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;
    fr = 0; while (hookState != 2'd0 && fr < 2000) begin frames(1); fr++; end

    // ------------------------------------------------------------ T10 (Step 10)
    begin_test(10, "T10 freeze = game over");
    press(shoot_key); frames(15);
    @(negedge clk) freeze = 1;
    n_before = n_hookCatch; maxR = dut.R; dx0 = dut.u_move.angle_fp;
    @(negedge clk) begin catchType = 3'd3; goldDR_tb = 1; pixelX = dut.Xend; pixelY = dut.Yend; end   // claw on gold
    repeat (6) @(negedge clk);
    goldDR_tb = 0;
    repeat (3) @(negedge clk);
    check(n_hookCatch == n_before && !dut.caught && hookState == 2'd1,
          $sformatf("frozen claw on gold: NO hookCatch (%0d), nothing caught, still SHOOT", n_hookCatch - n_before));
    press(shoot_key); frames(20);
    check(dut.R == maxR && dut.u_move.angle_fp == dx0 && hookState == 2'd1,
          $sformatf("20 frames frozen: rope stays %0d px, angle unchanged, key 2 ignored", dut.R));
    @(negedge clk) begin freeze = 0; catchType = 3'd0; end
    frames(5);
    check(dut.R > maxR && hookState == 2'd1, $sformatf("unfreeze: the shot goes on (R %0d -> %0d)", maxR, dut.R));
    @(negedge clk) tipCollision = 1; @(negedge clk) tipCollision = 0;
    fr = 0; while (hookState != 2'd0 && fr < 2000) begin frames(1); fr++; end

    // ------------------------------------------------------------ T11 (Step 10)
    begin_test(11, "T11 new level drops the object");
    n_before = n_deliver;
    catch_object(3);                                         // large gold = slowest pull-back
    frames(5);
    maxR = dut.R;
    @(negedge clk) newLevel = 1; @(negedge clk) newLevel = 0;   // 1-clock pulse (game_hud newLevel)
    check(maxR > MIN_R && hookState == 2'd0 && dut.R == MIN_R && !dut.caught && !dut.carryShow && !hookBusy,
          $sformatf("newLevel while pulling gold back (R %0d): at once SWING, R = %0d, hook empty, hookBusy 0", maxR, dut.R));
    frames(10);
    scan_carry();
    check(n_deliver == n_before && n_carry == 0,
          $sformatf("the object is LOST: no deliverPulse (%0d), nothing on the claw (%0d px)", n_deliver - n_before, n_carry));
    @(negedge clk) catchType = 3'd0;
    catch_object(1);
    fr = 0; while (hookState != 2'd0 && fr < 2000) begin frames(1); fr++; end
    repeat (3) @(negedge clk);
    check(n_deliver == n_before + 1 && last_deliver == value_of(1),
          $sformatf("next catch after the new level works: ONE deliverPulse, value %0d", last_deliver));
    @(negedge clk) catchType = 3'd0;

    // ------------------------------------------------------------ end
    t_end[11] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(11);
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
