// tb_mux_hook.sv - Step 6+8: the hook drawn through objects_mux (priority) + hook_block
//
// Run:  ModelSim -> cd <project>/tests -> do run_mux_hook.do         (expect VERSION 6.4)
// Checklist: tests/CHECKLIST_step6_top.md
//
// T1: ALL 64 combinations of the 6 drawing requests -> objects_mux must pick
//     miner > hook > dust > timer > gold > background, every time.
// T2: one full 640x480 frame: real hook_block (rope + claw under the miner) + a test miner
//     box + a test gold block that the rope crosses -> image frames/top_mux_frame.bmp
//     and pixel checks: miner covers the rope start, rope over gold, claw on top, gold elsewhere.
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_mux_hook;
import hook_params::*;

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

// ---------------- objects_mux inputs ----------------
logic smileyDR = 0, hookDR_in = 0, dustDR = 0, timerDR = 0, goldDR = 0, bgDR = 0;
logic [7:0] smileyRGB = 8'h03, hookRGB_in = 8'h49, dustRGB = 8'h92, timerRGB = 8'hE0, goldRGB = 8'hFC, bgRGB = 8'h1C, mifRGB = 8'h88;
logic [7:0] RGBOut;
bit   use_hook_block = 0;               // T2: hook comes from the real hook_block
logic hb_DR; logic [7:0] hb_RGB;
logic mux_hookDR; logic [7:0] mux_hookRGB;
assign mux_hookDR  = use_hook_block ? hb_DR  : hookDR_in;
assign mux_hookRGB = use_hook_block ? hb_RGB : hookRGB_in;

objects_mux mux (.clk, .resetN,
    .minerDrawingRequest(smileyDR), .minerRGB(smileyRGB),
    .hookDrawingRequest(mux_hookDR), .hookRGB(mux_hookRGB),
    .dustDrawingRequest(dustDR), .dustRGB,
    .timerDrawingRequest(timerDR), .timerRGB,
    .objectsDrawingRequest(goldDR), .objectsRGB(goldRGB),
    .backGroundRGB(bgRGB), .BGDrawingRequest(bgDR), .RGB_MIF(mifRGB),
    .RGBOut);

// ---------------- real hook_block for T2 ----------------
logic [10:0] pixelX = 0, pixelY = 0;
logic tipDR, hookBusy; logic [1:0] hookState;
hook_block hb (.clk, .resetN, .startOfFrame(1'b0), .pixelX, .pixelY,
               .minerX(11'sd280), .minerY(11'sd100), .minerMoving(1'b0), .shoot_key(1'b0),
               .tipCollision(1'b0), .goldDR(1'b0), .freeze(1'b0), .catchType(3'd0),
               .hookDR(hb_DR), .hookRGB(hb_RGB), .tipDR, .hookBusy, .hookState, .hookCatch());

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int            combo = 0, mismatches = 0;
logic [7:0]    expected = 0;
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
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask

logic [7:0] img [0:479][0:639];
// test objects: miner box (game start position) and a gold block crossed by the hanging rope
function automatic bit in_miner(input int x, input int y); return x >= 280 && x <= 343 && y >= 100 && y <= 163; endfunction
function automatic bit in_gold (input int x, input int y); return x >= 296 && x <= 330 && y >= 176 && y <= 190; endfunction

initial begin
    $display("\n##### tb_mux_hook VERSION 6.4 (2026-10-20, merged project: miner/objects port names) - if not the version Claude announced, run the full  do run_mux_hook.do  #####");
    repeat (3) @(negedge clk); resetN = 1; @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 priority, all 64 combinations");
    for (combo = 0; combo < 64; combo++) begin
        @(negedge clk);
        {smileyDR, hookDR_in, dustDR, timerDR, goldDR, bgDR} = 6'(combo);
        expected = smileyDR  ? smileyRGB  :
                   hookDR_in ? hookRGB_in :
                   dustDR    ? dustRGB    :
                   timerDR   ? timerRGB   :
                   goldDR    ? goldRGB    :
                   bgDR      ? bgRGB      : mifRGB;
        @(negedge clk);                              // objects_mux output is registered
        if (RGBOut !== expected) begin
            mismatches++;
            $display("   combo %b: got %h expected %h", 6'(combo), RGBOut, expected);
        end
    end
    check(mismatches == 0, $sformatf("objects_mux picks the right object in all 64 cases (%0d wrong)", mismatches));
    @(negedge clk) {smileyDR, hookDR_in, dustDR, timerDR, goldDR, bgDR} = 6'd0;

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 full frame: miner, hook, gold");
    use_hook_block = 1;
    begin
        int qx, qy, rx, ry, fd; byte r, g, b; logic [7:0] c;
        // pipeline: pixel at clock k -> hook_block output at k+1 -> mux output at k+2
        // the test objects are delayed by 1 clock to line up with hook_block (like real sprites)
        qx = -1; qy = -1; rx = -1; ry = -1;
        for (int n = 0; n <= 640*480 + 1; n++) begin
            @(negedge clk);
            if (rx >= 0) img[ry][rx] = RGBOut;              // result of the pixel driven 2 clocks ago
            rx = qx; ry = qy;
            smileyDR = (qx >= 0) && in_miner(qx, qy);       // objects for the pixel driven 1 clock ago
            goldDR   = (qx >= 0) && in_gold(qx, qy);
            if (n < 640*480) begin pixelX = n % 640; pixelY = n / 640; qx = n % 640; qy = n / 640; end
            else qx = -1;
        end
        smileyDR = 0; goldDR = 0;
        fd = $fopen("frames/top_mux_frame.bmp", "wb");
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
        $display("   image frames/top_mux_frame.bmp  (hook tip at %0d,%0d)", hb.Xend, hb.Yend);
    end
    check(img[150][312] == smileyRGB,  $sformatf("miner drawn over everything (312,150): %h", img[150][312]));
    check(img[163][312] == smileyRGB,  $sformatf("rope start hidden under the miner's bottom row (312,163): %h", img[163][312]));
    check(img[170][312] == ROPE_COLOR, $sformatf("rope below the miner (312,170): %h", img[170][312]));
    check(img[183][312] == ROPE_COLOR, $sformatf("rope drawn OVER the gold (312,183): %h", img[183][312]));
    check(img[183][300] == goldRGB,    $sformatf("gold next to the rope (300,183): %h", img[183][300]));
    check(img[hb.Yend][hb.Xend] == CLAW_COLOR, $sformatf("claw at the tip (%0d,%0d): %h", hb.Xend, hb.Yend, img[hb.Yend][hb.Xend]));
    check(img[300][500] == mifRGB,     $sformatf("background elsewhere (500,300): %h", img[300][500]));

    t_end[2] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(2);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Image: tests/frames/top_mux_frame.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #20_000_000;
    $display("WATCHDOG: not finished after 20 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
