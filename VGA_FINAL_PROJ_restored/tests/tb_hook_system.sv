// tb_hook_system.sv - Step 3: hook_move + hook_draw working TOGETHER (as in the game)
//
// Run:  ModelSim -> Transcript:  cd <project>/tests   then   do run_hook_system.do
// By-eye checklist: tests/CHECKLIST_step3_hook_system.md
//
// How a "frame" works here (fast but faithful):
//   1. one startOfFrame pulse -> hook_move moves (exactly like the 72.58 Hz pulse in the game)
//   2. the pixels around the claw (19x19) are scanned through hook_draw, one per clock,
//      and a GOLD OBJECT drawn by this testbench is checked on the same pixels:
//          tipCollision = tipDR AND goldDR        <- the same AND the game will use (Step 7)
//   3. sometimes a FULL 640x480 frame is scanned and saved as an image:
//          tests/frames/seq_<nnn>_T<test>_<state>.bmp   (numbered -> flip through them in order)
// hook_move only moves on startOfFrame, so the hook is frozen while a frame is being scanned,
// exactly like on the real screen.
//
// Conventions: never exits ($stop), GUI waves, chk_pass/chk_fail pulses, test_name/chk_name,
// cursors + "zt <n>", bounded loops, stimulus on the falling edge, independent reference checks.

`timescale 1ns/1ps
module tb_hook_system;
import hook_params::*;

localparam bit  SAVE_IMAGES = 1;          // set 0 for a fast run without images
localparam real FPS = FRAME_RATE_X100 / 100.0;
// swing limits from hook_params.sv (SWING_MIN_DEG / SWING_MAX_DEG) as LUT indices
localparam int  MIN_IDX = SWING_MIN_DEG / ANGLE_STEP_DEG;      // 15 deg -> 5
localparam int  MAX_IDX = SWING_MAX_DEG / ANGLE_STEP_DEG;      // 165 deg -> 55
localparam real SWING_PERIOD_EXP_S = 2.0 * (SWING_MAX_DEG - SWING_MIN_DEG) / SWING_DEG_PER_SEC; // 120 deg/s -> 2.50 s

// ---------------- DUTs ----------------
logic clk = 0, resetN = 0, sof = 0;
logic shoot_key = 0, tipCollision = 0, freeze = 0;
logic signed [10:0] X0 = 11'sd320, Y0 = 11'sd164;
logic signed [10:0] Xend, Yend;
logic [10:0] R;
logic [1:0]  hookState;
logic signed [9:0] dirCos, dirSin;     // Oct 2026: rope direction outputs
logic [10:0] pixelX = 0, pixelY = 0;
logic        drawingRequest, tipDR;
logic [7:0]  RGBout;

hook_move mv (.clk, .resetN, .startOfFrame(sof), .shoot_key, .tipCollision, .freeze,
              .retractStep(10'(RETRACT_EMPTY_STEP_FP)),   // Step 9 port: empty-hook speed
              .X0, .Y0, .Xend, .Yend, .R, .hookState, .dirCos, .dirSin);

// Oct 2026 (dirCos/dirSin outputs for the carried object): checked on EVERY clock against
// round(256*cos/sin(angle)) computed here with $cos/$sin - independent of the hook's table.
int dir_checks = 0, dir_bad = 0;
always @(posedge clk) if (resetN) begin
    automatic int ec = int'(256.0 * $cos(mv.angle_idx * 3 * 3.14159265358979 / 180.0));
    automatic int es = int'(256.0 * $sin(mv.angle_idx * 3 * 3.14159265358979 / 180.0));
    dir_checks++;
    if (int'(dirCos) != ec || int'(dirSin) != es) begin
        if (dir_bad < 3) $display("   dirCos/dirSin wrong at angle index %0d: %0d,%0d expected %0d,%0d", mv.angle_idx, dirCos, dirSin, ec, es);
        dir_bad++;
    end
end

hook_draw dr (.clk, .resetN, .pixelX, .pixelY, .X0, .Y0, .Xend, .Yend, .R,
              .drawingRequest, .RGBout, .tipDR);

always #5 clk = ~clk;

// ---------------- gold object (drawn by the testbench) ----------------
bit  gold_on = 0;
int  gx0, gy0, gx1, gy1;
logic goldDR = 0;                  // gold pixel at the same pixel as the hook_draw output
function automatic bit is_gold(input int x, input int y);
    return gold_on && x >= gx0 && x <= gx1 && y >= gy0 && y <= gy1;
endfunction

// ---------------- wave-window helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
logic [8*16:1] scan_kind = "idle";       // which kind of scan is running
logic          snap = 0;                 // pulse when an image is saved
int            frame_no = 0, image_no = 0;
int            angle_deg;
assign angle_deg = mv.angle_idx * ANGLE_STEP_DEG;

int  collisions = 0;                     // tipCollision pulses in the current test
int  rope_gold_px = 0, tip_gold_px = 0;  // overlaps seen in scans (current test)
int  rope_gold_frames = 0;
real meas_swing_period_s = 0;
real meas_ray_dev_px = 0;                // how far the tip left its straight line (max)
real meas_len_err_px = 0;                // | |tip-origin| - R |  (max)
int  meas_hit_x = 0, meas_hit_y = 0;     // tip position when the shot ended

realtime t_start [0:8];
realtime t_end   [0:8];

task automatic begin_test(input int n, input string name);
    if (test_no > 0) t_end[test_no] = $realtime;
    test_no = n; $sformat(test_name, "%s", name); t_start[n] = $realtime;
    collisions = 0; rope_gold_px = 0; tip_gold_px = 0; rope_gold_frames = 0;
    meas_ray_dev_px = 0; meas_len_err_px = 0;
    $display("\n[%0t] ---- T%0d %s ----", $time, n, name);
endtask

task automatic check(input bit ok, input string what);
    $sformat(chk_name, "%s", what);
    if (ok) begin nPass++; chk_pass = 1; $display("[%0t]   PASS  %s", $time, what); end
    else    begin nFail++; chk_fail = 1; $display("[%0t]   FAIL  %s   <-----", $time, what); end
    #20; chk_pass = 0; chk_fail = 0;
endtask

task automatic press_shoot();
    @(negedge clk) shoot_key = 1;
    repeat (3) @(negedge clk);
    shoot_key = 0;
endtask

// ---------------- scanning ----------------
logic [7:0] img [0:479][0:639];
int  scan_extra = 0;   // drawn pixels outside rope-box + claw-box during a full scan (must be 0)

// scan a rectangle of pixels through hook_draw (1 pixel per clock, outputs 1 clock later)
task automatic scan_rect(input int ax, input int ay, input int bx, input int by,
                         input bit collide, input bit full);
    int qx, qy, x, y, n, total, w;
    bit g, frame_rope_gold;
    if (ax < 0) ax = 0;   if (ay < 0) ay = 0;
    if (bx > 639) bx = 639; if (by > 479) by = 479;
    w = bx - ax + 1;
    total = w * (by - ay + 1);
    qx = -1; qy = -1; frame_rope_gold = 0;
    for (n = 0; n <= total; n++) begin
        @(negedge clk);
        tipCollision = 0;
        if (qx >= 0) begin
            g = is_gold(qx, qy);
            goldDR = g;
            if (full) img[qy][qx] = drawingRequest ? RGBout : (g ? 8'hFE : 8'hFF);
            if (g && tipDR) tip_gold_px++;
            if (g && drawingRequest && !tipDR) begin rope_gold_px++; frame_rope_gold = 1; end
            if (collide && g && tipDR && hookState == 2'd1) begin
                tipCollision = 1;            // = tipDR AND goldDR, for exactly one clock
                collisions++;
            end
        end
        if (n < total) begin
            x = ax + (n % w); y = ay + (n / w);
            pixelX = x; pixelY = y; qx = x; qy = y;
        end
    end
    @(negedge clk) tipCollision = 0; goldDR = 0;
    if (frame_rope_gold) rope_gold_frames++;
endtask

// ---------------- images ----------------
function automatic void to_rgb(input logic [7:0] c, output byte r, output byte g, output byte b);
    if (c == 8'hFF)      begin r = 8'd110; g = 8'd72;  b = 8'd40; end   // background (brown)
    else if (c == 8'hFE) begin r = 8'd235; g = 8'd190; b = 8'd30; end   // test gold object
    else begin r = {c[7:5], c[7:5], c[7:6]}; g = {c[4:2], c[4:2], c[4:3]}; b = {c[1:0], c[1:0], c[1:0], c[1:0]}; end
endfunction
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic save_bmp(input string fname);
    int fd; byte r, g, b;
    fd = $fopen(fname, "wb");
    if (fd == 0) begin $display("   could not open %s", fname); return; end
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--)
        for (int x = 0; x < 640; x++) begin
            to_rgb(img[y][x], r, g, b);
            $fwrite(fd, "%c%c%c", b, g, r);
        end
    $fclose(fd);
endtask

function automatic string state_str(input logic [1:0] s);
    return (s == 2'd0) ? "SWING" : (s == 2'd1) ? "SHOOT" : (s == 2'd2) ? "RETRACT" : "BAD";
endfunction

// full-frame image: also checks that nothing is drawn outside rope box + claw box
task automatic snapshot();
    int xmin, xmax, ymin, ymax;
    string fname, pad;
    if (!SAVE_IMAGES) return;
    $sformat(scan_kind, "%s", "FULL FRAME");
    scan_rect(0, 0, 639, 479, 0, 1);
    xmin = ((X0 < Xend) ? X0 : Xend) - 1; xmax = ((X0 < Xend) ? Xend : X0) + 1;
    ymin = ((Y0 < Yend) ? Y0 : Yend) - 1; ymax = ((Y0 < Yend) ? Yend : Y0) + 1;
    scan_extra = 0;
    for (int y = 0; y < 480; y++)
        for (int x = 0; x < 640; x++)
            if (img[y][x] != 8'hFF && img[y][x] != 8'hFE) begin
                bit inRope, inClaw;
                inRope = (x >= xmin && x <= xmax && y >= ymin && y <= ymax);
                inClaw = (x >= Xend-7 && x <= Xend+8 && y >= Yend-7 && y <= Yend+8);
                if (!inRope && !inClaw) scan_extra++;
            end
    image_no++;
    // zero padding done by hand: ModelSim 10.5b pads %03d with SPACES ("seq_ 25").
    // Built with if/else on a string variable (a ?: between string literals of different
    // lengths is treated as a number and can add hidden NUL characters).
    if (image_no < 10)       pad = "00";
    else if (image_no < 100) pad = "0";
    else                     pad = "";
    fname = {"frames/seq_", pad, $sformatf("%0d_T%0d_%s_f%0d.bmp", image_no, test_no, state_str(hookState), frame_no)};
    snap = 1; save_bmp(fname); #10 snap = 0;
    $display("   image %s  (angle %0d, R %0d, tip (%0d,%0d))", fname, angle_deg, R, Xend, Yend);
    $sformat(scan_kind, "%s", "idle");
endtask

// ---------------- one game frame ----------------
// LUT values for the ray check (same rounding as hook_move's table)
function automatic int lut256(input real v);
    return (v >= 0) ? $rtoi(256.0 * v + 0.5) : -$rtoi(-256.0 * v + 0.5);
endfunction
int  ray_c = 256, ray_s = 0;      // direction the shot was fired in
bit  track_ray = 0;
bit  watch_origin = 0;            // also scan the area under the origin (T5)

task automatic game_frame(input bit take_image);
    real d, L;
    int  ex, ey;
    @(negedge clk) sof = 1;
    @(negedge clk) sof = 0;               // exactly one rising edge with sof = 1
    frame_no++;
    // collision scan around the claw
    $sformat(scan_kind, "%s", "CLAW WINDOW");
    scan_rect(Xend - 9, Yend - 9, Xend + 9, Yend + 9, 1, 0);
    if (watch_origin) begin
        $sformat(scan_kind, "%s", "ORIGIN AREA");
        scan_rect(X0 - 50, Y0 - 5, X0 + 50, Y0 + 50, 1, 0);
    end
    $sformat(scan_kind, "%s", "idle");
    // geometry references
    ex = Xend - X0; ey = Yend - Y0;
    L  = $sqrt(real'(ex*ex + ey*ey));
    d  = L - real'(R); if (d < 0) d = -d;
    if (d > meas_len_err_px) meas_len_err_px = d;
    if (track_ray) begin
        d = real'(ex * ray_s - ey * ray_c) / 256.0; if (d < 0) d = -d;
        if (d > meas_ray_dev_px) meas_ray_dev_px = d;
    end
    if (take_image) snapshot();
endtask

task automatic frames_until_angle(input int lo, input int hi);   // swing until lo <= angle index <= hi
    int f = 0, idx;
    idx = mv.angle_idx;
    while (!(idx >= lo && idx <= hi) && f < 300) begin game_frame(0); f++; idx = mv.angle_idx; end
    check(idx >= lo && idx <= hi, $sformatf("swing reached %0d..%0d deg (took %0d frames)", lo*3, hi*3, f));
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

// ======================================================================
int  f, idx, minIdx, maxIdx, shot_idx, maxR, r_at_hit;
bit  r_constant, angle_constant;

initial begin
    $display("\n##### tb_hook_system VERSION 3.5 (file date 2026-10-25, + dirCos/dirSin outputs) - if this is not the version Claude announced, run the full  do run_*.do  (restart does NOT recompile) #####");
    $display("\n===== tb_hook_system: hook_move + hook_draw together (images: %0d) =====", SAVE_IMAGES);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 reset + first frame");
    repeat (3) @(negedge clk);
    resetN = 1;
    @(posedge clk); #1;
    // BEFORE the first frame: exactly the reset values
    check(hookState == 2'd0, "state SWING after reset");
    check(angle_deg == 90 && R == MIN_R, $sformatf("reset: hook hangs straight down (angle %0d, R %0d)", angle_deg, R));
    game_frame(1);
    // AFTER one frame the swing has already moved one step (65/64 of a 3-deg entry; the
    // integer part can drop by 2 entries = 6 deg in one frame, as noted in Step 1)
    check(angle_deg >= 84 && angle_deg <= 90, $sformatf("after 1 frame the hook moved at most 6 deg (angle %0d)", angle_deg));
    check(SAVE_IMAGES == 0 || img[Yend][Xend] == CLAW_COLOR, "image: claw drawn on the tip");
    check(SAVE_IMAGES == 0 || scan_extra == 0, $sformatf("image: nothing drawn outside rope+claw (%0d px)", scan_extra));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 one full swing (images)");
    f = 0; idx = mv.angle_idx;
    while (idx != MIN_IDX && f < 300) begin game_frame(0); f++; idx = mv.angle_idx; end
    minIdx = 99; maxIdx = -1; f = 0; r_constant = 1;
    do begin
        game_frame((f % 15) == 0);
        f++; idx = mv.angle_idx;
        if (idx < minIdx) minIdx = idx;
        if (idx > maxIdx) maxIdx = idx;
        if (R != MIN_R || hookState != 2'd0) r_constant = 0;
        if (SAVE_IMAGES && (f % 15) == 1 && scan_extra != 0)
            check(0, $sformatf("image frame %0d: %0d stray pixels", frame_no, scan_extra));
    end while (!(idx == MIN_IDX && maxIdx == MAX_IDX) && f < 800);
    meas_swing_period_s = f / FPS;
    check(minIdx == MIN_IDX && maxIdx == MAX_IDX,
          $sformatf("swing covers %0d..%0d deg, never outside (saw %0d..%0d deg)",
                    SWING_MIN_DEG, SWING_MAX_DEG, minIdx*ANGLE_STEP_DEG, maxIdx*ANGLE_STEP_DEG));
    check(meas_swing_period_s > 0.9*SWING_PERIOD_EXP_S && meas_swing_period_s < 1.1*SWING_PERIOD_EXP_S,
          $sformatf("swing period %0.2f s (target %0.2f s +-10%%)", meas_swing_period_s, SWING_PERIOD_EXP_S));
    check(r_constant, "rope stays MIN_R and state SWING during the whole swing");
    check(meas_len_err_px <= 2.0, $sformatf("tip always R away from origin (max error %0.2f px)", meas_len_err_px));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 shoot ~60 deg -> wall/floor");
    frames_until_angle(19, 21);
    shot_idx = mv.angle_idx;
    ray_c = lut256($cos(shot_idx * 3 * 3.14159265358979 / 180.0));
    ray_s = lut256($sin(shot_idx * 3 * 3.14159265358979 / 180.0));
    track_ray = 1; angle_constant = 1; maxR = 0;
    press_shoot(); @(posedge clk); #1;
    check(hookState == 2'd1, $sformatf("key 2 -> SHOOT at %0d deg", shot_idx * 3));
    f = 0;
    while (hookState == 2'd1 && f < 600) begin
        game_frame((f % 30) == 0); f++;
        if (mv.angle_idx != shot_idx) angle_constant = 0;
        if (R > maxR) maxR = R;
    end
    meas_hit_x = Xend; meas_hit_y = Yend;
    snapshot();                                   // image at the moment of the hit
    check(hookState == 2'd2, $sformatf("border reached after %0d frames -> RETRACT", f));
    check(Xend >= X_MAX || Xend <= X_MIN || Yend >= Y_MAX,
          $sformatf("tip at the border when it turned: (%0d,%0d)", Xend, Yend));
    f = 0;
    while (hookState == 2'd2 && f < 600) begin
        game_frame((f % 30) == 0); f++;
        if (mv.angle_idx != shot_idx) angle_constant = 0;
    end
    track_ray = 0;
    check(hookState == 2'd0 && R == MIN_R, $sformatf("retract done after %0d frames: SWING, R = %0d", f, R));
    check(angle_constant, "angle did not change during shoot + retract");
    check(meas_ray_dev_px <= 1.5, $sformatf("tip stayed on its straight line (max %0.2f px off)", meas_ray_dev_px));
    check(meas_len_err_px <= 2.0, $sformatf("rope length matches R (max error %0.2f px)", meas_len_err_px));
    check(collisions == 0, "no collisions (no gold in this test)");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 shoot down -> catch gold");
    gold_on = 1; gx0 = 300; gy0 = 330; gx1 = 340; gy1 = 360;      // 41x31 gold block
    frames_until_angle(29, 31);
    shot_idx = mv.angle_idx;
    press_shoot();
    f = 0;
    while (hookState == 2'd1 && f < 600) begin
        game_frame((f % 20) == 0); f++;
    end
    r_at_hit = R; meas_hit_x = Xend; meas_hit_y = Yend;
    snapshot();                                   // image at the moment of the catch
    check(collisions >= 1, $sformatf("tipCollision fired (%0d pulse(s)) = tipDR AND goldDR", collisions));
    check(hookState == 2'd2, $sformatf("caught after %0d frames -> RETRACT", f));
    check(Yend >= gy0 - 6 && Yend <= gy0, $sformatf("claw stopped at the top of the gold: tip y = %0d (gold top %0d)", Yend, gy0));
    check(Yend < Y_MAX - 20, "stopped by the gold, not by the floor");
    game_frame(0);
    check(R < r_at_hit, $sformatf("rope gets shorter right after the catch (%0d -> %0d)", r_at_hit, R));
    f = 0;
    while (hookState == 2'd2 && f < 600) begin game_frame((f % 20) == 0); f++; end
    check(hookState == 2'd0 && R == MIN_R, $sformatf("back to SWING after %0d frames", f));
    gold_on = 0;

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 rope over gold = no catch");
    gold_on = 1; gx0 = 316; gy0 = 180; gx1 = 324; gy1 = 188;      // small gold UNDER the origin, inside the rope circle
    watch_origin = 1;
    f = 0;
    while (f < 130) begin
        idx = mv.angle_idx;
        game_frame(idx >= 29 && idx <= 31 && (f % 4) == 0);
        f++;
    end
    watch_origin = 0;
    check(rope_gold_frames > 0, $sformatf("the rope DID pass over the gold (%0d frames, %0d px)", rope_gold_frames, rope_gold_px));
    check(tip_gold_px == 0, "the claw never touched the gold");
    check(collisions == 0, "no tipCollision -> rope alone never catches");
    check(hookState == 2'd0, "still swinging");
    gold_on = 0;

    check(dir_bad == 0, $sformatf("dirCos/dirSin = the rope angle on all %0d clocks (%0d wrong)", dir_checks, dir_bad));

    // ------------------------------------------------------------ end
    t_end[5] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(5);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("%0d images in tests/frames/seq_*.bmp - open the first one and use the arrow keys.", image_no);
    $display("Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin   // watchdog: pause, never exit
    #400_000_000;
    $display("WATCHDOG: not finished after 400 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
