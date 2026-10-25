// hook_speed_test_core.sv - Step 3.5: everything the speed test does, except the
// clock (PLL), VGA timing and keyboard IP (those are in hook_speed_test_top.sv).
// Kept separate so it can be simulated in ModelSim (the keyboard IP cannot).
//
// Uses EXACTLY the game's hook files: ../RTL/VGA/hook_params.sv, hook_move.sv, hook_draw.sv
//
// Keypad:  2 = shoot   8 = pretend catch (tipCollision)   5 = pause/resume   0 = reset hook
// Lights:  green = SWING   yellow = SHOOT   red = RETRACT
// Screen:  brown background, grid every 100 px, red lines = floor and walls (where the
//          hook must turn back), white square = rope origin, rope + claw.
// Colors are 8-bit RRRGGGBB like the rest of the project (red = E0, gold = FC).

module hook_speed_test_core (
    input  logic        clk,
    input  logic        resetN,
    input  logic        startOfFrame,
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic        key_shoot,    // keypad 2
    input  logic        key_catch,    // keypad 8
    input  logic        key_pause,    // keypad 5
    input  logic        key_reset,    // keypad 0

    output logic [7:0]  RGBout,       // to VGA_Controller.RGBIn
    output logic        greenLight,
    output logic        yellowLight,
    output logic        redLight,
    output logic        paused,       // for the testbench / debugging
    output logic [1:0]  hookState
);

import hook_params::*;

// rope origin (will be under the miner in the game).
// Constants cannot use the .X0 shorthand in a port list, so they have their own names
// and are connected explicitly: .X0(ORIGIN_X)
localparam logic signed [10:0] ORIGIN_X = 11'sd320;
localparam logic signed [10:0] ORIGIN_Y = 11'sd164;

localparam logic [7:0] COLOR_BG     = 8'h88;   // brown   100 010 00
localparam logic [7:0] COLOR_GRID   = 8'hAC;   // light brown
localparam logic [7:0] COLOR_BORDER = 8'hE0;   // red
localparam logic [7:0] COLOR_ORIGIN = 8'hFF;   // white

// ---------------- keys ----------------
logic key_pause_d;
logic hookResetN;                 // hook-only reset (key 0), registered = clean reset
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        key_pause_d <= 1'b0;
        paused      <= 1'b0;
        hookResetN  <= 1'b0;
    end
    else begin
        key_pause_d <= key_pause;
        if (key_pause && !key_pause_d) paused <= !paused;   // toggle on each press of 5
        hookResetN  <= !key_reset;
    end
end

// ---------------- the hook (game files) ----------------
logic signed [10:0] Xend, Yend;
logic        [10:0] R;
logic               hookDR, tipDR;
logic        [7:0]  hookRGB;

hook_move u_move (
    .clk, .resetN(hookResetN), .startOfFrame,
    .shoot_key(key_shoot), .tipCollision(key_catch), .freeze(paused), .restart(1'b0),
    .retractStep(10'(RETRACT_EMPTY_STEP_FP)),   // Step 9: empty-hook pull-back speed
    .X0(ORIGIN_X), .Y0(ORIGIN_Y), .Xend, .Yend, .R, .hookState,
    .dirCos(), .dirSin()                        // Oct 2026 outputs, not used in this test project
);

hook_draw u_draw (
    .clk, .resetN(hookResetN), .pixelX, .pixelY,
    .X0(ORIGIN_X), .Y0(ORIGIN_Y), .Xend, .Yend, .R,
    .drawingRequest(hookDR), .RGBout(hookRGB), .tipDR
);

// ---------------- background (registered: same 1-clock latency as hook_draw) ----------------
logic [7:0] bgRGB;
logic       isGrid, isBorder, isOrigin;
// grid every 100 px (plain compares - "% 100" would build a divider in hardware)
assign isGrid   = (pixelX == 100) || (pixelX == 200) || (pixelX == 300) || (pixelX == 400) ||
                  (pixelX == 500) || (pixelX == 600) ||
                  (pixelY == 100) || (pixelY == 200) || (pixelY == 300) || (pixelY == 400);
assign isBorder = (pixelX == X_MIN) || (pixelX == X_MAX) || (pixelY == Y_MAX);
assign isOrigin = (pixelX >= 317) && (pixelX <= 322) && (pixelY >= 161) && (pixelY <= 166);

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) bgRGB <= COLOR_BG;
    else if (isOrigin) bgRGB <= COLOR_ORIGIN;
    else if (isBorder) bgRGB <= COLOR_BORDER;
    else if (isGrid)   bgRGB <= COLOR_GRID;
    else               bgRGB <= COLOR_BG;
end

// ---------------- mux: hook on top of everything ----------------
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) RGBout <= 8'h00;
    else         RGBout <= hookDR ? hookRGB : bgRGB;
end

// ---------------- lights ----------------
assign greenLight  = (hookState == 2'd0);
assign yellowLight = (hookState == 2'd1);
assign redLight    = (hookState == 2'd2);

endmodule
