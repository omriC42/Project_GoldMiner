// tb_start_screen.sv - the opening screen as a PICTURE (start_screen.hex, 320x240 drawn 2x2)
//
// Run:  ModelSim -> cd <project>/tests -> do run_start_screen.do        (expect VERSION 10.0)
// Checklist: tests/CHECKLIST_start_screen.md
//
// T1 one full frame after reset: every one of the 307,200 pixels is compared with an INDEPENDENT
//    model of the old drawn screen ("PRESS ENTER TO START", 5x7 font x4, yellow on black) ->
//    the picture looks exactly like before. Image: frames/start_screen.bmp
// T2 the game is held in reset (gameResetN = 0) while the picture is shown
// T3 ENTER held from reset does NOT start the game (it must be pressed again)
// T4 a new ENTER press -> gameResetN = 1, the screen now shows the game picture (gameRGB)
// T5 more ENTER presses change nothing (stays in the game until reset)
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_start_screen;

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

logic        enterKey = 0;
logic  [7:0] gameRGB  = 8'h1C;           // a plain green "game" so it is easy to see
logic [10:0] pixelX = 0, pixelY = 0;
logic  [7:0] RGBOut;
logic        gameResetN;

start_screen #(.IMAGE_FILE("../RTL/VGA/start_screen.hex")) dut (
    .clk, .resetN, .enterKey, .gameRGB, .pixelX, .pixelY, .RGBOut, .gameResetN);

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            mismatches = 0, yellow_px = 0;
logic  [7:0]   expected = 0;
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

// ---------------- independent model of the OLD drawn opening screen ----------------
// (the same font/position the previous start_screen.sv calculated; the picture must match it)
localparam int SCALE = 4, CHAR_W = 20, CHAR_H = 28, STEP = 24, MSG_LEN = 20;
localparam int TEXT_X = 82, TEXT_Y = 226, TEXT_W = (MSG_LEN - 1) * STEP + CHAR_W;
localparam logic [0:7][0:6][4:0] FONT = {
    5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10000, 5'b10000, 5'b10000,   // P
    5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001,   // R
    5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111,   // E
    5'b01111, 5'b10000, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110,   // S
    5'b10001, 5'b11001, 5'b10101, 5'b10011, 5'b10001, 5'b10001, 5'b10001,   // N
    5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100,   // T
    5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110,   // O
    5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001 }; // A
// P R E S S _ E N T E R _ T O _ S T A R T   (8 = space)
localparam int MSG [0:MSG_LEN-1] = '{0,1,2,3,3,8, 2,4,5,2,1,8, 5,6,8, 3,5,7,1,5};
function automatic logic [7:0] old_screen(input int x, input int y);
    int rx, ry, ci, col, code;
    if (x < TEXT_X || x >= TEXT_X + TEXT_W || y < TEXT_Y || y >= TEXT_Y + CHAR_H) return 8'h00;
    rx = x - TEXT_X; ry = y - TEXT_Y; ci = rx / STEP; col = rx - ci * STEP; code = MSG[ci];
    if (col >= CHAR_W || code == 8) return 8'h00;
    return FONT[code][ry / SCALE][4 - col / SCALE] ? 8'hFC : 8'h00;
endfunction

// ---------------- one full frame (pixel -> RGBOut one clock later), compared + saved ----------------
logic [7:0] img [0:479][0:639];
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic scan_frame(input string fname);
    int px, py, fd; byte r, g, b; logic [7:0] c;
    px = -1; py = 0; mismatches = 0; yellow_px = 0;
    for (int n = 0; n <= 640*480; n++) begin
        @(negedge clk);
        if (px >= 0) begin                           // the pixel presented one clock ago
            img[py][px] = RGBOut;
            expected = old_screen(px, py);
            if (RGBOut !== expected) begin
                if (mismatches < 5) $display("   mismatch at (%0d,%0d): got %h expected %h", px, py, RGBOut, expected);
                mismatches++;
            end
            if (RGBOut == 8'hFC) yellow_px++;
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
// wait n clocks and report if gameResetN ever went high
task automatic hold(input int n, output bit went_high);
    went_high = 0;
    repeat (n) begin @(negedge clk); if (gameResetN) went_high = 1; end
endtask

bit hi;

initial begin
    $display("\n##### tb_start_screen VERSION 10.0 (2026-10-25, opening screen = picture start_screen.hex) - if not the version Claude announced, run the full  do run_start_screen.do  #####");
    repeat (3) @(negedge clk);

    // ------------------------------------------------------------ T1 + T2
    begin_test(1, "T1 the picture = the old screen");
    @(negedge clk) resetN = 1;
    scan_frame("frames/start_screen.bmp");
    check(mismatches == 0, $sformatf("all 307,200 pixels equal the old drawn screen (%0d mismatches)", mismatches));
    check(yellow_px == 4208, $sformatf("%0d yellow text pixels (expected 4208 = the 20-letter message)", yellow_px));
    begin_test(2, "T2 game held in reset");
    check(!gameResetN, "while the picture is shown: gameResetN = 0 (game held in reset)");

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 ENTER held from reset");
    @(negedge clk) resetN = 0; enterKey = 1;          // ENTER already held when reset ends
    repeat (3) @(negedge clk);
    @(negedge clk) resetN = 1;
    hold(50, hi);
    check(!hi, "ENTER held through reset does NOT start the game");
    @(negedge clk) enterKey = 0;
    hold(20, hi);
    check(!hi, "released: still on the opening screen");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 ENTER starts the game");
    @(negedge clk) enterKey = 1;
    hold(3, hi);
    check(gameResetN, "a NEW ENTER press -> gameResetN = 1 within 2 clocks");
    @(negedge clk) begin pixelX = 300; pixelY = 240; end   // a pixel that is yellow text on the picture
    repeat (2) @(negedge clk);
    check(RGBOut == gameRGB, $sformatf("screen now shows the game picture (RGBOut %h = gameRGB %h)", RGBOut, gameRGB));
    @(negedge clk) enterKey = 0;

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 more ENTER presses");
    repeat (3) begin
        @(negedge clk) enterKey = 1; repeat (5) @(negedge clk); enterKey = 0; repeat (5) @(negedge clk);
    end
    check(gameResetN && RGBOut == gameRGB, "3 more ENTER presses: still in the game");

    // ------------------------------------------------------------ end
    t_end[5] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(5);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Image: tests/frames/start_screen.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #20_000_000;
    $display("WATCHDOG: not finished after 20 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
