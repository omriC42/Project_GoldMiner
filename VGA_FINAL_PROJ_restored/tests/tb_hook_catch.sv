// tb_hook_catch.sv - Step 7: CATCHING. Real objects field (square_object + ObjectsMatrixBitMap,
// same parameters as Objects_DISPLAY) + real hook_block + objects_mux (for the images).
//
// Run:  ModelSim -> cd <project>/tests -> do run_hook_catch.do        (expect VERSION 7.4.2)
// Checklist: tests/CHECKLIST_step7_catch.md
//
// T1 reads the random layout and picks a target object (biggest gold, else biggest rock).
// T2 MEASURES the pixel delays: objectsDrawingRequest must come 2 clocks after its pixel and
//    tipDR 1 clock after its pixel (hook_block delays tipDR by 1 -> both describe the same pixel).
// T3 places the miner above the target, shoots straight down: hookCatch -> object removed,
//    ONE collectPulse with the right value, hook pulls back.
// T4 shoots down where there is no gold field (x = 600): no catch, hook turns at the floor.
// 7.4 (Oct 2026): hook_block deliverPulse/deliverValue (score at the top): T3 ONE delivery with the
//    object's value when the hook is home, T4 none after the empty shot.
// Images: frames/catch_1_before.bmp, catch_2_caught.bmp, catch_3_after.bmp
// Note: to shoot exactly straight down the testbench FORCES the swing angle to 90 deg for
// the moment of the key press (shown as force_angle in the waves). Real play aims by timing.

`timescale 1ns/1ps
module tb_hook_catch;
import hook_params::*;

logic clk = 0, resetN = 0, sof = 0;
always #5 clk = ~clk;

logic [10:0] pixelX = 0, pixelY = 0;
logic signed [10:0] minerX = 11'sd280, minerY = 11'sd100;
logic shoot_key = 0;

// ---------------- gold field = Gold_DISPLAY contents ----------------
logic [10:0] offX, offY; logic boxDR; logic [7:0] boxRGB;
logic goldDR; logic [7:0] goldRGB;
logic collectPulse; logic [5:0] collectValue; logic [2:0] collectType;
logic hookCatch;
square_object #(.OBJECT_WIDTH_X(512), .OBJECT_HEIGHT_Y(256)) gsq (
    .clk, .resetN, .pixelX, .pixelY, .topLeftX(11'sd64), .topLeftY(11'sd224),
    .offsetX(offX), .offsetY(offY), .drawingRequest(boxDR), .RGBout(boxRGB));
ObjectsMatrixBitMap gbm (
    .clk, .resetN, .offsetX(offX), .offsetY(offY), .InsideRectangle(boxDR),
    .collision_Hook_Object(hookCatch), .newLevel(1'b0), .difficulty(2'(game_params::DIFFICULTY)),
    .drawingRequest(goldDR), .RGBout(goldRGB), .collectPulse, .collectValue, .collectType);

// ---------------- the hook ----------------
logic hookDR, tipDR, hookBusy; logic [7:0] hookRGB; logic [1:0] hookState;
logic deliverPulse; logic [5:0] deliverValue;         // 7.4: score at the top
hook_block hb (.clk, .resetN, .startOfFrame(sof), .pixelX, .pixelY, .minerX, .minerY,
               .minerMoving(1'b0), .shoot_key, .tipCollision(1'b0), .goldDR, .freeze(1'b0), .newLevel(1'b0),
               .catchType(collectType), .difficulty(2'(game_params::DIFFICULTY)),
               .hookDR, .hookRGB, .tipDR, .hookBusy, .hookState, .hookCatch,
               .deliverPulse, .deliverValue);

// ---------------- screen (for the images) ----------------
logic [7:0] RGBOut;
objects_mux mux (.clk, .resetN, .minerDrawingRequest(1'b0), .minerRGB(8'h00),
    .hookDrawingRequest(hookDR), .hookRGB, .dustDrawingRequest(1'b0), .dustRGB(8'h00),
    .timerDrawingRequest(1'b0), .timerRGB(8'h00), .objectsDrawingRequest(goldDR), .objectsRGB(goldRGB),
    .backGroundRGB(8'h00), .BGDrawingRequest(1'b0), .RGB_MIF(8'h88), .RGBOut);

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
logic [8*16:1] scan_kind = "idle";
int  frame_no = 0;
bit  force_angle = 0;
int  n_hookCatch = 0, n_collect = 0, last_value = 0;
int  n_deliver = 0, last_deliver = -1;
int  lat_gold = -1, lat_tip = -1;
int  tgt_row = -1, tgt_col = -1, tgt_type = 0, tgt_value = 0, tgt_cx = 0, tgt_cy = 0;
int  angle_deg; assign angle_deg = hb.u_move.angle_idx * ANGLE_STEP_DEG;
always @(posedge clk) begin
    if (hookCatch)    n_hookCatch++;
    if (collectPulse) begin n_collect++; last_value = collectValue; end
    if (deliverPulse) begin n_deliver++; last_deliver = deliverValue; end
end
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

// scan a rectangle, one pixel per clock (the hook does not move: no startOfFrame)
task automatic scan_rect(input int ax, input int ay, input int bx, input int by);
    int w, total;
    if (ax < 0) ax = 0; if (ay < 0) ay = 0; if (bx > 639) bx = 639; if (by > 479) by = 479;
    w = bx - ax + 1; total = w * (by - ay + 1);
    for (int n = 0; n < total; n++) begin
        @(negedge clk); pixelX = ax + n % w; pixelY = ay + n / w;
    end
    repeat (4) @(negedge clk);
endtask
task automatic game_frame();
    @(negedge clk) sof = 1; @(negedge clk) sof = 0;
    frame_no++;
    $sformat(scan_kind, "%s", "CLAW WINDOW");
    scan_rect(hb.Xend - 10, hb.Yend - 10, hb.Xend + 10, hb.Yend + 10);
    $sformat(scan_kind, "%s", "idle");
endtask

// full frame through objects_mux -> image (mux output = 2 clocks after the pixel for gold)
logic [7:0] img [0:479][0:639];
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic snapshot(input string fname);
    int qx [0:2], qy [0:2], fd; byte r, g, b; logic [7:0] c;
    $sformat(scan_kind, "%s", "FULL FRAME");
    qx = '{-1,-1,-1}; qy = '{0,0,0};
    for (int n = 0; n <= 640*480 + 2; n++) begin
        @(negedge clk);
        if (qx[2] >= 0) img[qy[2]][qx[2]] = RGBOut;
        qx[2] = qx[1]; qy[2] = qy[1]; qx[1] = qx[0]; qy[1] = qy[0];
        if (n < 640*480) begin pixelX = n % 640; pixelY = n / 640; qx[0] = n % 640; qy[0] = n / 640; end
        else qx[0] = -1;
    end
    fd = $fopen(fname, "wb");
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--) for (int x = 0; x < 640; x++) begin
        c = img[y][x];
        r = {c[7:5], c[7:5], c[7:6]}; g = {c[4:2], c[4:2], c[4:3]}; b = {c[1:0], c[1:0], c[1:0], c[1:0]};
        $fwrite(fd, "%c%c%c", b, g, r);
    end
    $fclose(fd);
    $sformat(scan_kind, "%s", "idle");
    $display("   image %s  (hook %s, tip %0d,%0d)", fname, (hookState==0)?"SWING":(hookState==1)?"SHOOT":"RETRACT", hb.Xend, hb.Yend);
endtask

function automatic int value_of(input int t);
    case (t)   // expected values = game_params.sv
        1: return game_params::GOLD_SMALL_VALUE;  2: return game_params::GOLD_MEDIUM_VALUE; 3: return game_params::GOLD_LARGE_VALUE;
        4: return game_params::ROCK_SMALL_VALUE;  5: return game_params::ROCK_MEDIUM_VALUE; 6: return game_params::ROCK_LARGE_VALUE;
        default: return 0;
    endcase
endfunction
function automatic int radius_of(input int t);
    case (t) 1, 4: return 8; 2, 5: return 16; 3, 6: return 28; default: return 0; endcase
endfunction

// sprite edges measured from ObjectsMatrixBitMap's bitmaps (cell is 64x64, centre at 32,32):
//   left_of = first opaque pixel on the centre row, as a distance left of the centre
//   top_of  = first opaque pixel from the top within +-5 px of the centre column (the claw width)
function automatic int left_of(input int t);
    case (t) 1: return 8; 2: return 15; 3: return 28; 4: return 7; 5: return 13; 6: return 25; default: return 0; endcase
endfunction
function automatic int top_of(input int t);
    case (t) 1: return 7; 2: return 13; 3: return 29; 4: return 6; 5: return 12; 6: return 25; default: return 0; endcase
endfunction

// measure how many clocks after its pixel a signal rises, scanning one line from x0
task automatic measure_latency(input int y, input int x0, input int x_first, input bit use_tip, output int lat);
    int n = 0, rise = -1;
    for (n = 0; n < 200 && rise < 0; n++) begin
        @(negedge clk); pixelX = x0 + n; pixelY = y;
        #1; if ((use_tip ? tipDR : goldDR) && rise < 0) rise = n;   // signal seen while pixel n is driven
    end
    // pixel x_first is driven at index (x_first - x0); a signal registered N times is first
    // seen N clocks (= N indices) later -> latency = rise index - x_first index
    lat = (rise < 0) ? -1 : rise - (x_first - x0);
    repeat (4) @(negedge clk);
endtask

int f, best, t, r0;

initial begin
    $display("\n##### tb_hook_catch VERSION 7.4.2 (2026-10-25, difficulty inputs) - if not the version Claude announced, run the full  do run_hook_catch.do  #####");
    repeat (3) @(negedge clk); resetN = 1;
    repeat (5) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 read the random layout");
    best = -1;
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++) begin
        t = gbm.MazeBitMapMask[row][col];
        if (t != 0) begin
            // score: gold before rock, bigger before smaller
            int sc; sc = (t <= 3 ? 10 : 0) + radius_of(t);
            $display("   cell row %0d col %0d : type %0d (%s, value %0d)", row, col, t, (t<=3)?"gold":"rock", value_of(t));
            if (sc > best) begin best = sc; tgt_row = row; tgt_col = col; tgt_type = t; end
        end
    end
    tgt_value = value_of(tgt_type);
    tgt_cx = 64 + tgt_col*64 + 32; tgt_cy = 224 + tgt_row*64 + 32;
    check(tgt_type != 0, $sformatf("target: row %0d col %0d type %0d value %0d, centre (%0d,%0d)", tgt_row, tgt_col, tgt_type, tgt_value, tgt_cx, tgt_cy));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 measure pixel delays");
    $sformat(scan_kind, "%s", "LATENCY GOLD");
    measure_latency(tgt_cy, tgt_cx - 32, tgt_cx - left_of(tgt_type), 1'b0, lat_gold);   // scan from the cell's left edge
    check(lat_gold == 2, $sformatf("objectsDrawingRequest comes %0d clocks after its pixel (expected 2)", lat_gold));
    $sformat(scan_kind, "%s", "LATENCY CLAW");
    // claw row 7 (= tip row): first claw pixel is at Xend-5
    measure_latency(hb.Yend, hb.Xend - 40, hb.Xend - 5, 1'b1, lat_tip);
    check(lat_tip == 1, $sformatf("tipDR comes %0d clock after its pixel (expected 1)", lat_tip));
    check(lat_gold - lat_tip == 1, "hook_block delays tipDR by exactly 1 clock -> claw and gold compared on the SAME pixel");
    $sformat(scan_kind, "%s", "idle");

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 shoot straight down at the target");
    @(negedge clk) minerX = tgt_cx - HOOK_DX;      // rope origin right above the object centre
    game_frame();
    snapshot("frames/catch_1_before.bmp");
    force_angle = 1; force hb.u_move.angle_fp = 13'(30 * FP);   // 90 deg = straight down
    @(negedge clk) shoot_key = 1; repeat (3) @(negedge clk); shoot_key = 0;
    @(negedge clk); release hb.u_move.angle_fp; force_angle = 0;
    check(hookState == 2'd1, "SHOOT started at 90 deg");
    n_hookCatch = 0; n_collect = 0; n_deliver = 0;
    f = 0;
    while (hookState == 2'd1 && f < 400) begin game_frame(); f++; end
    check(n_hookCatch > 0, $sformatf("hookCatch fired after %0d frames (%0d pulse(s))", f, n_hookCatch));
    check(hookState == 2'd2, "hook switched to RETRACT because of the catch");
    check(hb.Yend + 5 >= tgt_cy - top_of(tgt_type) - 3 && hb.Yend < tgt_cy,
          $sformatf("stopped at the object's top edge: claw bottom y = %0d, object top y = %0d", hb.Yend + 5, tgt_cy - top_of(tgt_type)));
    repeat (10) @(negedge clk);
    check(gbm.MazeBitMapMask[tgt_row][tgt_col] == 0, "object removed from the gold field");
    check(n_collect == 1, $sformatf("exactly ONE collectPulse (got %0d) -> score added once", n_collect));
    check(last_value == tgt_value, $sformatf("collectValue = %0d (expected %0d)", last_value, tgt_value));
    snapshot("frames/catch_2_caught.bmp");
    f = 0; while (hookState != 2'd0 && f < 1500) begin game_frame(); f++; end   // heavy objects come back slowly (Step 9)
    check(hookState == 2'd0 && hb.R == MIN_R, $sformatf("back to SWING after %0d frames", f));
    repeat (5) @(negedge clk);
    check(n_deliver == 1 && last_deliver == tgt_value,
          $sformatf("hook home with the object: ONE deliverPulse (got %0d), deliverValue %0d (expected %0d)", n_deliver, last_deliver, tgt_value));
    snapshot("frames/catch_3_after.bmp");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 shoot where there is no gold");
    @(negedge clk) minerX = 11'sd568;              // origin x = 600, right of the gold field (x 64..575)
    game_frame();
    force_angle = 1; force hb.u_move.angle_fp = 13'(30 * FP);
    @(negedge clk) shoot_key = 1; repeat (3) @(negedge clk); shoot_key = 0;
    @(negedge clk); release hb.u_move.angle_fp; force_angle = 0;
    n_hookCatch = 0; n_collect = 0; n_deliver = 0; r0 = 0;
    f = 0; while (hookState == 2'd1 && f < 400) begin game_frame(); f++; if (hb.R > r0) r0 = hb.R; end
    check(n_hookCatch == 0 && n_collect == 0, "no hookCatch, no collectPulse");
    check(hb.Yend >= Y_MAX, $sformatf("hook went all the way to the floor (tip y %0d)", hb.Yend));
    f = 0; while (hookState != 2'd0 && f < 1500) begin game_frame(); f++; end
    repeat (5) @(negedge clk);
    check(hookState == 2'd0 && n_deliver == 0, $sformatf("empty hook back home after %0d frames: NO deliverPulse", f));

    t_end[4] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(4);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Images: tests/frames/catch_*.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #100_000_000;
    $display("WATCHDOG: not finished after 100 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
