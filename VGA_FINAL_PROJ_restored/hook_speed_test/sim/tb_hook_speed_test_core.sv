// tb_hook_speed_test_core.sv - Step 3.5: simulate the speed-test core before compiling.
//
// Run:  ModelSim -> Transcript:  cd <project>/hook_speed_test/sim   then   do run_speed_test_core.do
// Checklist: CHECKLIST_step35_speed_test.md (same folder)
//
// * T2/T5 use the REAL VGA_Controller: the frames saved as images are exactly what the
//   monitor receives (RGBout captured on active pixels, with the 2-clock pipeline delay).
// * T3/T4 use a fast startOfFrame (every 40 clocks) to test the keys quickly.
// Conventions: never exits ($stop), GUI waves, chk_pass/chk_fail, version banner,
// cursors + "zt <n>", bounded loops, stimulus on the falling edge.

`timescale 1ns/1ps
module tb_hook_speed_test_core;
import hook_params::*;

logic clk = 0, resetN = 0;
always #15.873 clk = ~clk;           // 31.5 MHz, like the PLL output

// ---------------- VGA controller (real) ----------------
logic [10:0] vgaX, vgaY;
logic        vgaSof;
logic [28:0] oVGA;
logic [18:0] addr;
logic [7:0]  RGB;
VGA_Controller u_vga (.RGBIn(RGB), .PixelX(vgaX), .PixelY(vgaY), .startOfFrame(vgaSof),
                      .oVGA, .address(addr), .clk, .resetN);
logic vgaActive;
assign vgaActive = oVGA[27];         // the BLANK bit: 1 = visible pixel

// ---------------- startOfFrame source: real VGA or fast ----------------
bit   use_fast_sof = 0;
logic fastSof = 0;
int   fastCnt = 0;
always @(posedge clk) begin
    fastCnt <= (fastCnt == 39) ? 0 : fastCnt + 1;
    fastSof <= (fastCnt == 39);
end
logic sof;
assign sof = use_fast_sof ? fastSof : vgaSof;

// ---------------- keys and DUT ----------------
logic key_shoot = 0, key_catch = 0, key_pause = 0, key_reset = 0;
logic greenLight, yellowLight, redLight, paused;
logic [1:0] hookState;

hook_speed_test_core dut (
    .clk, .resetN, .startOfFrame(sof), .pixelX(vgaX), .pixelY(vgaY),
    .key_shoot, .key_catch, .key_pause, .key_reset,
    .RGBout(RGB), .greenLight, .yellowLight, .redLight, .paused, .hookState
);

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            angle_deg;
assign angle_deg = dut.u_move.angle_idx * ANGLE_STEP_DEG;
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
    #64; chk_pass = 0; chk_fail = 0;
endtask
task automatic press(ref logic k);          // press and release a key (about 10 clocks)
    @(negedge clk) k = 1;
    repeat (10) @(negedge clk);
    k = 0;
endtask
task automatic fast_frames(input int n);
    repeat (n) @(posedge clk iff fastSof);
    @(negedge clk);
endtask

// ---------------- capture one real VGA frame into an image ----------------
logic [7:0] img [0:479][0:639];
logic        act_d1, act_d2;
logic [10:0] x_d1, x_d2, y_d1, y_d2;
always @(posedge clk) begin      // RGBout is 2 clocks behind the pixel coordinates
    act_d1 <= vgaActive; x_d1 <= vgaX; y_d1 <= vgaY;
    act_d2 <= act_d1;    x_d2 <= x_d1; y_d2 <= y_d1;
end
bit capturing = 0;
int captured_px = 0;
int cap_x = 0, cap_y = 0, cap_R = 0;   // hook tip/length DURING the captured frame
always @(negedge clk) if (capturing && act_d2 && x_d2 < 640 && y_d2 < 480) begin
    img[y_d2][x_d2] = RGB; captured_px++;
end

task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic save_bmp(input string fname);
    int fd; byte r, g, b; logic [7:0] c;
    fd = $fopen(fname, "wb");
    if (fd == 0) begin $display("   could not open %s", fname); return; end
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--)
        for (int x = 0; x < 640; x++) begin
            c = img[y][x];                          // RRRGGGBB -> 24-bit, like the VGA DAC
            r = {c[7:5], c[7:5], c[7:6]}; g = {c[4:2], c[4:2], c[4:3]}; b = {c[1:0], c[1:0], c[1:0], c[1:0]};
            $fwrite(fd, "%c%c%c", b, g, r);
        end
    $fclose(fd);
    $display("   screen image saved: %s", fname);
endtask

task automatic capture_frame(input string fname);    // waits for a frame start, records one frame
    int n = 0;
    use_fast_sof = 0;
    while (!vgaSof && n < 1_000_000) begin @(posedge clk); n++; end
    @(negedge clk); captured_px = 0; capturing = 1;
    cap_x = dut.Xend; cap_y = dut.Yend; cap_R = dut.R;   // the hook is still during the frame
    n = 0;
    do begin @(posedge clk); n++; end while (!vgaSof && n < 1_000_000);
    repeat (3) @(negedge clk); capturing = 0;
    save_bmp(fname);
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

int f, a0, r0;

initial begin
    $display("\n##### tb_hook_speed_test_core VERSION 3.5.2 (2026-10-19) - if not the version Claude announced, run the full  do run_speed_test_core.do  #####");

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 reset: lights + swing");
    repeat (5) @(negedge clk);
    resetN = 1;
    repeat (5) @(negedge clk);
    check(greenLight && !yellowLight && !redLight, "after reset only the GREEN light is on (SWING)");
    check(!paused, "not paused after reset");

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 real VGA frame: screen image");
    capture_frame("frames/screen_1_swing.bmp");
    check(captured_px == 640*480, $sformatf("captured a full 640x480 frame (%0d px)", captured_px));
    check(img[50][50]   == 8'h88, $sformatf("background brown 88 at (50,50): %h", img[50][50]));
    check(img[50][100]  == 8'hAC, $sformatf("grid line at x=100: %h", img[50][100]));
    check(img[200][50]  == 8'hAC, $sformatf("grid line at y=200 (50,200): %h", img[200][50]));
    check(img[50][X_MAX] == 8'hE0, $sformatf("red wall line at x=%0d: %h", X_MAX, img[50][X_MAX]));
    check(img[Y_MAX][50] == 8'hE0, $sformatf("red floor line at y=%0d: %h", Y_MAX, img[Y_MAX][50]));
    check(img[161][317] == 8'hFF, $sformatf("white origin square at (317,161): %h", img[161][317]));
    check(img[cap_y][cap_x] == CLAW_COLOR, $sformatf("claw on the tip (%0d,%0d): %h", cap_x, cap_y, img[cap_y][cap_x]));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 keys 2 / 8 and the lights");
    use_fast_sof = 1;
    fast_frames(5);
    press(key_shoot);
    fast_frames(1);
    check(yellowLight && !greenLight && !redLight, "key 2 -> YELLOW light (SHOOT)");
    fast_frames(20);
    r0 = dut.R;
    check(r0 > MIN_R, $sformatf("rope is getting longer (R = %0d)", r0));
    press(key_catch);
    @(negedge clk);
    check(redLight && !yellowLight && !greenLight, "key 8 (pretend catch) -> RED light (RETRACT)");
    f = 0; while (!greenLight && f < 500) begin fast_frames(1); f++; end
    check(greenLight && dut.R == MIN_R, $sformatf("back to GREEN after %0d frames, R = %0d", f, dut.R));

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 key 5 pause / key 0 reset");
    fast_frames(3);
    press(key_pause);
    fast_frames(1);
    a0 = dut.u_move.angle_fp;
    check(paused, "key 5 -> paused");
    fast_frames(30);
    check(dut.u_move.angle_fp == a0, "paused: swing does not move for 30 frames");
    press(key_shoot); fast_frames(2);
    check(greenLight, "paused: key 2 is ignored (still GREEN)");
    press(key_pause); fast_frames(5);
    check(!paused && dut.u_move.angle_fp != a0, "key 5 again -> running, swing moves");
    press(key_shoot); fast_frames(30);
    check(yellowLight, "shooting again (for the reset test)");
    press(key_reset); fast_frames(1);
    check(greenLight && dut.R == MIN_R, $sformatf("key 0 -> hook reset: GREEN, R = %0d", dut.R));
    check(angle_deg >= 84 && angle_deg <= 90, $sformatf("key 0 -> hook hangs down again (angle %0d)", angle_deg));

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 real VGA frame while shooting");
    press(key_shoot);
    fast_frames(60);                                  // long rope
    use_fast_sof = 0;
    capture_frame("frames/screen_2_shoot.bmp");
    check(img[cap_y][cap_x] == CLAW_COLOR, $sformatf("claw on the tip (%0d,%0d)", cap_x, cap_y));
    check(cap_R > 150, $sformatf("long rope in this image (R = %0d)", cap_R));

    // ------------------------------------------------------------ end
    t_end[5] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(5);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Screen images: hook_speed_test/sim/frames/screen_*.bmp   Simulation PAUSED. zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #200_000_000;
    $display("WATCHDOG: not finished after 200 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
