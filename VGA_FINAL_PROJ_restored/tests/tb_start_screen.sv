// tb_start_screen.sv - Step 14: drawing of the opening screen and the settings screen (start_screen.sv)
//
// Run:  ModelSim -> cd <project>/tests -> do run_start_screen.do        (expect VERSION 11.0)
// Checklist: tests/CHECKLIST_start_screen.md
//
// The screen / cursor / settings inputs are driven directly here (game_settings is tested in
// tb_game_settings). Every test scans a FULL 640x480 frame (RGBOut 1 clock after its pixel) and
// compares every pixel with an expected frame built HERE, independently of the hardware:
//   * the picture: start_screen.hex (each byte 2x2) or settings_screen.hex (each byte 4x4),
//   * on the settings screen, PAINTED on top of it: a green frame (2 px) around the chosen word
//     of each row and a yellow triangle (16x28) at the label of the cursor row - drawn as shapes
//     into the expected frame, not tested per pixel like the hardware does.
//   The word positions come from settings_layout.svh (written by make_menu_pictures.py with the
//   picture). Every frame is also saved as a .bmp to look at.
// T1 OPENING screen                       frames/menu_1_opening.bmp
// T2 SETTINGS, defaults, cursor row 0     frames/menu_2_settings_default.bmp
// T3 SETTINGS, HARD / 30 S / sound OFF / cheats OFF, cursor row 2 (SOUND)  frames/menu_3_settings_changed.bmp
// T4 SETTINGS, EASY / 90 S / sound ON / cheats OFF, cursor rows 1 and 3   frames/menu_4_*.bmp
// T5 PLAYING: the screen shows the game picture (gameRGB)
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_start_screen;

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

logic  [1:0] screen = 0, cursor = 0, difficulty = 1, timeSel = 1;
logic        soundOn = 1, cheatsOn = 1;
logic  [7:0] gameRGB = 8'h1C;            // a plain green "game"
logic [10:0] pixelX = 0, pixelY = 0;
logic  [7:0] RGBOut;

start_screen #(.IMAGE_FILE("../RTL/VGA/start_screen.hex"), .SETTINGS_FILE("../RTL/VGA/settings_screen.hex")) dut (
    .clk, .resetN, .screen, .cursor, .difficulty, .timeSel, .soundOn, .cheatsOn, .gameRGB, .pixelX, .pixelY, .RGBOut);

`include "settings_layout.svh"

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            mismatches = 0, n_arrow = 0, n_frame = 0;
logic  [7:0]   expected = 0;
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

// ---------------- the expected frame ----------------
logic [7:0] pic_open [0:320*240-1];
logic [7:0] pic_set  [0:160*120-1];
initial begin
    $readmemh("../RTL/VGA/start_screen.hex", pic_open);
    $readmemh("../RTL/VGA/settings_screen.hex", pic_set);
end
logic [7:0] exp_img [0:479][0:639];
task automatic build_expected(input int scr);
    int sel [0:3];
    int a, b, t, u, y0, w;
    for (int y = 0; y < 480; y++) for (int x = 0; x < 640; x++)
        exp_img[y][x] = (scr == 0) ? pic_open[(y / 2) * 320 + x / 2] : pic_set[(y / 4) * 160 + x / 4];
    if (scr != 1) return;
    sel[0] = difficulty; sel[1] = timeSel; sel[2] = soundOn ? 0 : 1; sel[3] = cheatsOn ? 0 : 1;
    for (int r = 0; r < SET_ROWS; r++) begin                 // green frames: 4 bars of 2 pixels
        a = SET_VAL_X0[r][sel[r]] - 6; b = SET_VAL_X1[r][sel[r]] + 5;
        t = SET_ROW_Y[r] - 6;          u = SET_ROW_Y[r] + SET_TEXT_H + 5;
        for (int x = a; x <= b; x++) begin exp_img[t][x] = 8'h1C; exp_img[t+1][x] = 8'h1C; exp_img[u-1][x] = 8'h1C; exp_img[u][x] = 8'h1C; end
        for (int y = t; y <= u; y++) begin exp_img[y][a] = 8'h1C; exp_img[y][a+1] = 8'h1C; exp_img[y][b-1] = 8'h1C; exp_img[y][b] = 8'h1C; end
    end
    y0 = SET_ROW_Y[cursor] - SET_LABEL_DY;                    // yellow triangle, row by row
    for (int dy = 0; dy < SET_TEXT_H; dy++) begin
        w = ((dy < 14) ? dy : 27 - dy) + 2;
        if (w > 16) w = 16;
        for (int dx = 0; dx < w; dx++) exp_img[y0 + dy][SET_ARROW_X + dx] = 8'hFC;
    end
endtask

// ---------------- scan one frame, compare, save ----------------
logic [7:0] img [0:479][0:639];
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic scan_frame(input string fname);
    int px, py, fd; byte r, g, b; logic [7:0] c;
    px = -1; py = 0; mismatches = 0; n_arrow = 0; n_frame = 0;
    for (int n = 0; n <= 640*480; n++) begin
        @(negedge clk);
        if (px >= 0) begin                           // the pixel presented one clock ago
            img[py][px] = RGBOut;
            expected = exp_img[py][px];
            if (RGBOut !== expected) begin
                if (mismatches < 5) $display("   mismatch at (%0d,%0d): got %h expected %h", px, py, RGBOut, expected);
                mismatches++;
            end
            if (dut.overlayOn && dut.overlayRGB == 8'hFC) n_arrow++;
            if (dut.overlayOn && dut.overlayRGB == 8'h1C) n_frame++;
        end
        if (n < 640*480) begin pixelX = n % 640; pixelY = n / 640; px = n % 640; py = n / 640; end
        else px = -1;
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
    $display("   image %s written", fname);
endtask
task automatic show(input int scr, input int cur, input int d, input int t, input bit s, input bit c, input string fname);
    @(negedge clk) begin screen = 2'(scr); cursor = 2'(cur); difficulty = 2'(d); timeSel = 2'(t); soundOn = s; cheatsOn = c; end
    build_expected(scr);
    scan_frame(fname);
endtask

int bad_total;

initial begin
    $display("\n##### tb_start_screen VERSION 11.0 (2026-10-25, opening + settings screens) - if not the version Claude announced, run the full  do run_start_screen.do  #####");
    repeat (3) @(negedge clk);
    resetN = 1;
    repeat (3) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 opening screen");
    show(0, 0, 1, 1, 1, 1, "frames/menu_1_opening.bmp");
    check(mismatches == 0, $sformatf("all 307,200 pixels = start_screen.hex drawn 2x2 (%0d mismatches)", mismatches));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 settings: defaults");
    show(1, 0, 1, 1, 1, 1, "frames/menu_2_settings_default.bmp");
    check(mismatches == 0 && n_arrow > 0 && n_frame > 0,
          $sformatf("settings, cursor DIFFICULTY, NORMAL / 60 S / ON / ON framed: %0d mismatches (arrow %0d px, frames %0d px)", mismatches, n_arrow, n_frame));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 settings: changed");
    show(1, 2, 2, 0, 0, 0, "frames/menu_3_settings_changed.bmp");
    check(mismatches == 0, $sformatf("cursor SOUND, HARD / 30 S / OFF / OFF framed: %0d mismatches", mismatches));

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 settings: other rows");
    show(1, 1, 0, 2, 1, 0, "frames/menu_4_settings_row1.bmp"); bad_total = mismatches;
    show(1, 3, 0, 2, 1, 0, "frames/menu_4_settings_row3.bmp"); bad_total += mismatches;
    check(bad_total == 0, $sformatf("cursor TIME and CHEATS, EASY / 90 S / ON / OFF framed: %0d mismatches", bad_total));

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 playing");
    @(negedge clk) screen = 2'd2;
    bad_total = 0;
    for (int k = 0; k < 2000; k++) begin
        @(negedge clk) begin pixelX = 11'(k % 640); pixelY = 11'(k / 7); gameRGB = 8'(k); end
        #1 if (RGBOut !== gameRGB) bad_total++;
    end
    check(bad_total == 0, $sformatf("PLAYING: RGBOut = gameRGB on 2000 pixels (%0d different)", bad_total));

    // ------------------------------------------------------------ end
    t_end[5] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(5);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Images: tests/frames/menu_*.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #200_000_000;
    $display("WATCHDOG: not finished after 200 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
