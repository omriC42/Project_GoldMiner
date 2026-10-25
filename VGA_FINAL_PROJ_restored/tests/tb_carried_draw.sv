// tb_carried_draw.sv - the caught object hanging on the claw (carried_draw.sv, Oct 2026)
//
// Run:  ModelSim -> cd <project>/tests -> do run_carried_draw.do        (expect VERSION 11.0)
// Checklist: tests/CHECKLIST_carry.md
//
// carried_draw alone, driven directly (tip position, rope direction, show, object type):
// T1 all 6 objects x 5 rope angles (15, 45, 90, 135, 165 deg): a 160x160 window around the tip is
//    scanned pixel by pixel and compared with an INDEPENDENT model:
//      left      = tip x - size/2                      (hangs straight down under the claw)
//      top       = tip y + CARRY_OFFSET_PX - topPad      (first visible row tucked in the claw)
//      topPad    = first non-transparent row, found HERE by scanning the picture (not copied
//                  from carried_draw's table -> a wrong table in carried_draw fails T1)
//      picture   = the sprite table (object_sprites.svh = the same pictures as the objects field).
//    The rope angle must NOT move the object (same place at all 5 angles).
//    Every pixel must match, including the transparent ones (drawingRequest = 0 there).
// T2 show = 0 -> nothing at all, for every object
// T3 object code 0 (nothing on the hook) or 7 (unused) with show = 1 -> nothing
// T4 tip near the bottom-right corner -> the object is cut by the screen edge, no wrap-around
// T5 output timing: the drawing request comes exactly 1 clock after its pixel (same as hook_draw)
// Images: frames/carry_types_90deg.bmp (all 6 objects in the claw)
//         frames/carry_angles_gold_large.bmp (large gold at the 5 angles - always under the claw)
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_carried_draw;
import hook_params::*;

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

logic        [10:0] pixelX = 0, pixelY = 0;
logic signed [10:0] Xend = 0, Yend = 0;
logic signed  [9:0] dirCos = 0, dirSin = 256;
logic               show = 0;
logic         [2:0] objType = 0;
logic               drawingRequest;
logic         [7:0] RGBout;

carried_draw dut (.clk, .resetN, .pixelX, .pixelY, .Xend, .Yend, .dirCos, .dirSin,
                  .show, .objType, .drawingRequest, .RGBout);

// the pictures (the same file the objects field uses) - the reference for every pixel
`include "object_sprites.svh"

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            mismatches = 0, drawn = 0, angle_now = 0;
logic  [7:0]   expected = 8'hFF;
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

// ---------------- independent reference model ----------------
function automatic string obj_name(input int t);
    case (t) 1: return "gold S"; 2: return "gold M"; 3: return "gold L";
             4: return "rock S"; 5: return "rock M"; 6: return "rock L"; default: return "none"; endcase
endfunction
function automatic int size_of(input int t);
    case (t) 1, 4: return 16; 2, 5: return 32; 3, 6: return 64; default: return 0; endcase
endfunction
function automatic logic [7:0] sprite_px(input int t, input int sx, input int sy);
    case (t)
        1: return gold_small_colors [sy][sx];   2: return gold_medium_colors[sy][sx];
        3: return gold_large_colors [sy][sx];   4: return rock_small_colors [sy][sx];
        5: return rock_medium_colors[sy][sx];   6: return rock_large_colors [sy][sx];
        default: return 8'hFF;
    endcase
endfunction
function automatic int top_pad(input int t);     // first row of the picture that is not transparent
    int sz;
    sz = size_of(t);
    for (int y = 0; y < sz; y++) for (int x = 0; x < sz; x++)
        if (sprite_px(t, x, y) != 8'hFF) return y;
    return 0;
endfunction
int ref_left, ref_top;      // where the model puts the sprite (for the waves)
function automatic logic [7:0] model(input int t, input int tipx, input int tipy, input int c, input int s,
                                     input int x, input int y, input bit on);
    int sz, lx, ty;
    sz = size_of(t);
    if (!on || sz == 0) return 8'hFF;
    lx = tipx - sz / 2;                          // c, s (rope angle) are ignored on purpose
    ty = tipy + CARRY_OFFSET_PX - top_pad(t);
    ref_left = lx; ref_top = ty;
    if (x < lx || x >= lx + sz || y < ty || y >= ty + sz) return 8'hFF;
    return sprite_px(t, x - lx, y - ty);
endfunction

// ---------------- scan a window and compare every pixel ----------------
logic [7:0] img [0:479][0:639];
task automatic clear_img();
    for (int y = 0; y < 480; y++) for (int x = 0; x < 640; x++) img[y][x] = 8'hFF;
endtask
task automatic scan_window(input int x0, input int y0, input int w, input int h,
                           input int t, input int c, input int s, input bit on);
    int px, py;
    mismatches = 0; drawn = 0; px = -1; py = -1;
    for (int n = 0; n <= w * h; n++) begin
        @(negedge clk);
        if (px >= 0) begin                                // pixel presented one clock ago
            expected = model(t, Xend, Yend, c, s, px, py, on);
            if (RGBout !== expected || drawingRequest !== (expected != 8'hFF)) begin
                if (mismatches < 3) $display("   mismatch %s at (%0d,%0d): got %h/%b expected %h", obj_name(t), px, py, RGBout, drawingRequest, expected);
                mismatches++;
            end
            if (drawingRequest) begin drawn++; img[py][px] = RGBout; end
        end
        if (n < w * h) begin
            px = x0 + n % w; py = y0 + n / w;
            if (px < 0 || px > 639 || py < 0 || py > 479) begin px = -1; pixelX = 0; pixelY = 0; end
            else begin pixelX = px; pixelY = py; end
        end
        else px = -1;
    end
endtask
task automatic set_case(input int t, input int tipx, input int tipy, input int deg, input bit on,
                        output int c, output int s);
    c = int'(256.0 * $cos(deg * 3.14159265358979 / 180.0));
    s = int'(256.0 * $sin(deg * 3.14159265358979 / 180.0));
    @(negedge clk);
    objType = t; Xend = tipx; Yend = tipy; dirCos = c; dirSin = s; show = on; angle_now = deg;
    repeat (3) @(negedge clk);                            // the box is registered once per clock
endtask
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic save_bmp(input string fname);
    int fd; byte r, g, b; logic [7:0] col;
    fd = $fopen(fname, "wb");
    if (fd == 0) begin $display("   could not open %s", fname); return; end
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--) for (int x = 0; x < 640; x++) begin
        col = img[y][x];
        if (col == 8'hFF) begin r = 8'd110; g = 8'd72; b = 8'd40; end       // brown = transparent
        else begin r = {col[7:5], col[7:5], col[7:6]}; g = {col[4:2], col[4:2], col[4:3]}; b = {col[1:0], col[1:0], col[1:0], col[1:0]}; end
        $fwrite(fd, "%c%c%c", b, g, r);
    end
    $fclose(fd);
    $display("   image %s", fname);
endtask
// small white cross on the tip in the images (testbench only)
task automatic mark_tip(input int x, input int y);
    for (int k = -3; k <= 3; k++) begin
        if (x+k >= 0 && x+k < 640) img[y][x+k] = 8'hDB;
        if (y+k >= 0 && y+k < 480) img[y+k][x] = 8'hDB;
    end
endtask

localparam int ANGLES [0:4] = '{15, 45, 90, 135, 165};
int c, s, ok_cases, lat_ok, rise;

initial begin
    $display("\n##### tb_carried_draw VERSION 12.0 (2026-10-25, object hangs IN the claw, straight down) - if not the version Claude announced, run the full  do run_carried_draw.do  #####");
    $display("   CARRY_OFFSET_PX = %0d -> first visible row of the object is %0d px below the tip, centred in x",
             CARRY_OFFSET_PX, CARRY_OFFSET_PX);
    repeat (3) @(negedge clk); resetN = 1; repeat (2) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 6 objects x 5 angles");
    clear_img();
    for (int t = 1; t <= 6; t++) begin
        for (int a = 0; a < 5; a++) begin
            set_case(t, 320, 240, ANGLES[a], 1'b1, c, s);
            scan_window(320 - 80, 240 - 80, 160, 160, t, c, s, 1'b1);
            check(mismatches == 0 && drawn > 0,
                  $sformatf("%s at %0d deg: %0d px drawn, %0d mismatches (sprite at %0d,%0d)", obj_name(t), ANGLES[a], drawn, mismatches, ref_left, ref_top));
        end
    end

    // images: all 6 hanging straight down side by side, then large gold at the 5 angles
    clear_img();
    for (int t = 1; t <= 6; t++) begin
        set_case(t, 50 + (t - 1) * 105, 120, 90, 1'b1, c, s);
        scan_window(50 + (t - 1) * 105 - 40, 120 - 40, 80, 120, t, c, s, 1'b1);
        mark_tip(50 + (t - 1) * 105, 120);
    end
    save_bmp("frames/carry_types_90deg.bmp");
    clear_img();
    for (int a = 0; a < 5; a++) begin
        set_case(3, 64 + a * 128, 200, ANGLES[a], 1'b1, c, s);
        scan_window(64 + a * 128 - 60, 200 - 60, 120, 140, 3, c, s, 1'b1);
        mark_tip(64 + a * 128, 200);
    end
    save_bmp("frames/carry_angles_gold_large.bmp");

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 show = 0 -> nothing");
    ok_cases = 0;
    for (int t = 1; t <= 6; t++) begin
        set_case(t, 320, 240, 90, 1'b0, c, s);
        scan_window(320 - 80, 240 - 80, 160, 160, t, c, s, 1'b0);
        if (drawn == 0 && mismatches == 0) ok_cases++;
    end
    check(ok_cases == 6, $sformatf("show = 0: nothing drawn for all 6 objects (%0d of 6)", ok_cases));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 no object -> nothing");
    set_case(0, 320, 240, 90, 1'b1, c, s);
    scan_window(320 - 80, 240 - 80, 160, 160, 0, c, s, 1'b1);
    check(drawn == 0 && mismatches == 0, $sformatf("object code 0 with show = 1: nothing drawn (%0d px)", drawn));
    set_case(7, 320, 240, 90, 1'b1, c, s);
    scan_window(320 - 80, 240 - 80, 160, 160, 7, c, s, 1'b1);
    check(drawn == 0 && mismatches == 0, $sformatf("object code 7 (unused) with show = 1: nothing drawn (%0d px)", drawn));

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 cut by the screen edge");
    set_case(6, 610, 455, 45, 1'b1, c, s);                // large rock, lower right corner
    scan_window(500, 380, 140, 100, 6, c, s, 1'b1);
    check(mismatches == 0 && drawn > 0, $sformatf("large rock at the corner: %0d px drawn, %0d mismatches (part is off screen)", drawn, mismatches));
    scan_window(0, 0, 100, 100, 6, c, s, 1'b1);           // the top-left corner must stay empty
    check(drawn == 0, $sformatf("no wrap-around: nothing at the top-left corner (%0d px)", drawn));

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 1 clock latency");
    set_case(1, 320, 240, 90, 1'b1, c, s);                // small gold: box (312, 243) -> (320,252) = sprite (8, 9)
    lat_ok = 0; rise = -1;
    for (int k = 0; k < 4; k++) begin                     // hold one pixel for 4 clocks
        @(negedge clk) begin pixelX = 320; pixelY = 252; end
    end
    @(negedge clk) begin pixelX = 0; pixelY = 0; end      // leave
    @(negedge clk);
    check(!drawingRequest, "1 clock after leaving the object: drawingRequest = 0");
    @(negedge clk) begin pixelX = 320; pixelY = 252; end  // enter on this clock
    check(!drawingRequest, "on the clock the pixel arrives: not yet (registered)");
    @(negedge clk);
    check(drawingRequest == (sprite_px(1, 8, 9) != 8'hFF) && RGBout == sprite_px(1, 8, 9),
          $sformatf("one clock later: the sprite pixel %h (same timing as hook_draw)", RGBout));

    // ------------------------------------------------------------ end
    t_end[5] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(5);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Images: tests/frames/carry_*.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #200_000_000;
    $display("WATCHDOG: not finished after 200 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
