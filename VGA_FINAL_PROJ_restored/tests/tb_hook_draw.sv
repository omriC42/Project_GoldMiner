// tb_hook_draw.sv - testbench for hook_draw (Step 2), made to be WATCHED in ModelSim
//
// Run:  ModelSim -> Transcript:  cd <project>/tests   then   do run_hook_draw.do
//
// What it does: for 6 hook positions it scans one full 640x480 VGA frame
// (one pixel per clock, exactly like VGA_Controller) and:
//   * checks every pixel (claw only near the tip, rope only near the line,
//     correct colors, transparent elsewhere)
//   * SAVES THE FRAME AS AN IMAGE:  tests/frames/hook_T<n>_<angle>deg.bmp
//     (open with any image viewer - this is exactly what the module drew).
//     A .ppm text copy is written too in case a viewer cannot open the .bmp.
// Conventions (tests/TESTING_CONVENTIONS.md): never exits ($stop), GUI waves,
// chk_pass/chk_fail pulses, test_name/chk_name in ASCII, cursors + "zt <n>",
// all loops bounded, stimulus on the falling edge.

`timescale 1ns/1ps
module tb_hook_draw;
import hook_params::*;

// ---------------- DUT ----------------
logic clk = 0, resetN = 0;
logic [10:0] pixelX = 0, pixelY = 0;
logic signed [10:0] X0 = 11'sd320, Y0 = 11'sd164, Xend = 0, Yend = 0;
logic [10:0] R = 0;
logic        drawingRequest, tipDR;
logic [7:0]  RGBout;

hook_draw dut (.clk, .resetN, .pixelX, .pixelY, .X0, .Y0, .Xend, .Yend, .R,
               .drawingRequest, .RGBout, .tipDR);

always #5 clk = ~clk;

// ---------------- wave-window helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no   = 0;
logic [8*64:1] chk_name  = "";
logic          chk_pass  = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            angle_deg = 0;
// per-frame results (shown in the MEASURED group)
int            meas_rope_px = 0, meas_claw_px = 0;
real           meas_rope_width_px = 0;      // rope pixels / R
real           meas_max_dist_px   = 0;      // farthest rope pixel from the ideal line
int            meas_claw_far_px   = 0;      // claw pixels farther than 8 px from the tip (must be 0)
int            meas_bad_color_px  = 0;      // wrong RGB for its type (must be 0)
int            meas_outside_box_px= 0;      // drawn pixels outside rope box + claw box (must be 0)

// ---- independent reference for the rope math (32-bit int, no width tricks) ----
// crossProd_ref is computed here by the testbench; the DUT's crossProd must equal it
// on EVERY clock. cross_mismatch counts differences (must stay 0).
int crossProd_ref = 0;
int cross_mismatch = 0;
int cross_pos_cnt = 0, cross_neg_cnt = 0;   // how many pixels had positive / negative crossProd
always @(posedge clk) begin
    #1;
    crossProd_ref = (int'(pixelY) - int'(Y0)) * (int'(Xend) - int'(X0))
                  - (int'(pixelX) - int'(X0)) * (int'(Yend) - int'(Y0));
    if (resetN) begin
        if (int'($signed(dut.crossProd)) != crossProd_ref) begin
            cross_mismatch++;
            if (cross_mismatch <= 10)
                $display("[%0t]   crossProd MISMATCH at pixel (%0d,%0d): DUT %0d, reference %0d",
                         $time, pixelX, pixelY, $signed(dut.crossProd), crossProd_ref);
        end
        if (crossProd_ref > 0) cross_pos_cnt++;
        if (crossProd_ref < 0) cross_neg_cnt++;
    end
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

// ---------------- frame buffer + image writers ----------------
logic [7:0] img [0:479][0:639];      // 8-bit color per pixel, 8'hFF = transparent

// 8-bit (3-3-2) -> 24-bit for the image file. Transparent shows a brown "mine" background.
function automatic void to_rgb(input logic [7:0] c, output byte r, output byte g, output byte b);
    if (c == 8'hFF) begin r = 8'd110; g = 8'd72; b = 8'd40; end
    else begin
        r = {c[7:5], c[7:5], c[7:6]};   // grey levels look the same in any 3-3-2 order
        g = {c[4:2], c[4:2], c[4:3]};
        b = {c[1:0], c[1:0], c[1:0], c[1:0]};
    end
endfunction

task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask

task automatic save_images(input string base);
    int fd; byte r, g, b;
    // ---- BMP (24-bit, bottom-up rows, 640*3 = 1920 bytes/row: no padding) ----
    fd = $fopen({base, ".bmp"}, "wb");
    if (fd == 0) begin $display("   could not open %s.bmp (does tests/frames exist?)", base); return; end
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);         // planes=1, bpp=24
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--)
        for (int x = 0; x < 640; x++) begin
            to_rgb(img[y][x], r, g, b);
            $fwrite(fd, "%c%c%c", b, g, r);
        end
    $fclose(fd);
    // ---- PPM text copy (P3) ----
    fd = $fopen({base, ".ppm"}, "w");
    $fdisplay(fd, "P3\n640 480\n255");
    for (int y = 0; y < 480; y++) begin
        for (int x = 0; x < 640; x++) begin
            to_rgb(img[y][x], r, g, b);
            $fwrite(fd, "%0d %0d %0d ", r, g, b);
        end
        $fdisplay(fd, "");
    end
    $fclose(fd);
    $display("   frame saved: %s.bmp  (and .ppm)", base);
endtask

// ---------------- geometry (same LUT rounding as hook_move) ----------------
function automatic int lut256(input real v);   // round(256*v)
    return (v >= 0) ? $rtoi(256.0 * v + 0.5) : -$rtoi(-256.0 * v + 0.5);
endfunction

task automatic set_hook(input int deg, input int len);
    int c, s;
    real a;
    a = deg * 3.14159265358979 / 180.0;
    c = lut256($cos(a)); s = lut256($sin(a));
    @(negedge clk);
    angle_deg = deg;
    R    = len;
    Xend = X0 + ((len * c) >>> 8);
    Yend = Y0 + ((len * s) >>> 8);
    $display("   hook: angle %0d deg, R = %0d, origin (%0d,%0d), tip (%0d,%0d)", deg, len, X0, Y0, Xend, Yend);
endtask

// ---------------- scan one frame, check every pixel ----------------
task automatic scan_frame(input int n, input int deg);
    int ex, ey;
    int px, py, qx, qy;      // q = coordinates of the output being sampled (1 clock latency)
    real L, d, crossv;
    int  xmin, xmax, ymin, ymax;
    bit  isRope, isClaw;
    meas_rope_px = 0; meas_claw_px = 0; meas_max_dist_px = 0;
    meas_claw_far_px = 0; meas_bad_color_px = 0; meas_outside_box_px = 0;
    ex = Xend - X0; ey = Yend - Y0;                 // copy to int first: 11-bit products would overflow
    L = $sqrt(real'(ex*ex + ey*ey));
    xmin = ((X0 < Xend) ? X0 : Xend) - 1;  xmax = ((X0 < Xend) ? Xend : X0) + 1;
    ymin = ((Y0 < Yend) ? Y0 : Yend) - 1;  ymax = ((Y0 < Yend) ? Yend : Y0) + 1;
    qx = -1; qy = -1;
    for (int k = 0; k <= 640*480; k++) begin          // +1 clock to collect the last pixel
        @(negedge clk);
        // sample output of the previous pixel
        if (qx >= 0) begin
            isClaw = tipDR;
            isRope = drawingRequest && !tipDR;
            img[qy][qx] = RGBout;
            if (isClaw) begin
                meas_claw_px++;
                if ((qx - Xend > 8) || (Xend - qx > 8) || (qy - Yend > 8) || (Yend - qy > 8)) meas_claw_far_px++;
                if (RGBout != CLAW_COLOR) meas_bad_color_px++;
            end
            else if (isRope) begin
                meas_rope_px++;
                crossv = real'((qy - Y0) * (Xend - X0) - (qx - X0) * (Yend - Y0));
                d = (crossv < 0 ? -crossv : crossv) / L;
                if (d > meas_max_dist_px) meas_max_dist_px = d;
                if (qx < xmin || qx > xmax || qy < ymin || qy > ymax) meas_outside_box_px++;
                if (RGBout != ROPE_COLOR) meas_bad_color_px++;
            end
            else if (RGBout != 8'hFF || drawingRequest) meas_bad_color_px++;
        end
        // drive next pixel
        if (k < 640*480) begin
            px = k % 640; py = k / 640;
            pixelX = px; pixelY = py; qx = px; qy = py;
        end
    end
    meas_rope_width_px = (R > 0) ? real'(meas_rope_px) / real'(R) : 0;
    $display("   rope px = %0d (%0.2f px wide), claw px = %0d, max rope distance = %0.2f px",
             meas_rope_px, meas_rope_width_px, meas_claw_px, meas_max_dist_px);
    save_images($sformatf("frames/hook_T%0d_%0ddeg_R%0d", n, deg, R));
endtask

task automatic hook_case(input int n, input int deg, input int len);
    begin_test(n, $sformatf("T%0d angle %0d deg R=%0d", n, deg, len));
    set_hook(deg, len);
    cross_pos_cnt = 0; cross_neg_cnt = 0;
    scan_frame(n, deg);
    $display("   crossProd: positive on %0d pixels, negative on %0d pixels, %0d mismatches so far",
             cross_pos_cnt, cross_neg_cnt, cross_mismatch);
    check(cross_mismatch == 0, $sformatf("DUT crossProd == reference on every pixel (%0d mismatches)", cross_mismatch));
    check(cross_pos_cnt > 0 && cross_neg_cnt > 0, "crossProd takes BOTH signs (pixels on both sides of the rope)");
    check(img[Yend][Xend] == CLAW_COLOR,         $sformatf("claw drawn ON the tip pixel (%0d,%0d)", Xend, Yend));
    check(meas_claw_px == 50,                    $sformatf("claw has all 50 pixels (got %0d)", meas_claw_px));
    check(meas_claw_far_px == 0,                 "no claw pixel more than 8 px from the tip");
    check(meas_rope_px > R,                      $sformatf("rope visible: %0d px for R = %0d", meas_rope_px, R));
    check(meas_rope_width_px >= 1.5 && meas_rope_width_px <= 3.5,
                                                 $sformatf("rope width %0.2f px (target 1.5..3.5)", meas_rope_width_px));
    check(meas_max_dist_px <= 1.05,              $sformatf("every rope pixel within 1 px of the line (max %0.2f)", meas_max_dist_px));
    check(meas_outside_box_px == 0,              "rope never goes past origin or tip");
    check(meas_bad_color_px == 0,                $sformatf("colors: rope/claw/transparent all correct (%0d wrong)", meas_bad_color_px));
    // points along the rope (25/50/75 %) are drawn
    for (int p = 1; p <= 3; p++) begin
        int sx, sy;
        sx = X0 + ((Xend - X0) * p) / 4;  sy = Y0 + ((Yend - Y0) * p) / 4;
        check(img[sy][sx] != 8'hFF, $sformatf("rope pixel at %0d%% of the length (%0d,%0d)", 25*p, sx, sy));
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

initial begin
    $display("\n##### tb_hook_draw VERSION 2.3 (file date 2026-10-19) - if this is not the version Claude announced, run the full  do run_*.do  (restart does NOT recompile) #####");
    $display("\n===== tb_hook_draw  (rope half-width %0d/4 px, rope color %h, claw color %h) =====",
             ROPE_HALF_WIDTH_X4, ROPE_COLOR, CLAW_COLOR);

    // ================================================================ T1
    begin_test(1, "T1 reset");
    repeat (3) @(negedge clk);
    check(drawingRequest == 0 && tipDR == 0 && RGBout == 8'hFF, "outputs idle/transparent in reset");
    @(negedge clk) resetN = 1;
    repeat (2) @(negedge clk);

    // ================================================================ T2..T7
    hook_case(2,   0, 200);    // pointing right (horizontal - failed in old code)
    hook_case(3,  45, 250);
    hook_case(4,  90, 300);    // straight down
    hook_case(5, 135, 250);
    hook_case(6, 180, 200);    // pointing left (horizontal)
    hook_case(7,  90,  40);    // short rope while swinging (MIN_R)

    // ================================================================ end
    t_end[7] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(7);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Images: tests/frames/*.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin   // watchdog: pause, never exit
    #60_000_000;
    $display("WATCHDOG: not finished after 60 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
