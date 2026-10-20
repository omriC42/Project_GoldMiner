// hook_speed_test_top.sv - Step 3.5 top level: wiring only.
// Same clock / reset / keyboard / VGA structure as TOP_VGA_DEMO_KBD.bdf:
//   CLOCK_50 -> CLK_31P5 PLL -> clk (31.5 MHz) for everything (keyboard included)
//   resetN_pin -> NOT -> PLL rst ;  PLL locked = resetN for everything
// Port names are the same as the game's top level, so the pin assignments are the same.

module hook_speed_test_top (
    input  logic        CLOCK_50,
    input  logic        resetN_pin,
    input  logic        PS2_CLK,
    input  logic        PS2_DAT,
    output logic [28:0] OVGA,
    output logic        redLight,
    output logic        yellowLight,
    output logic        greenLight
);

logic        clk, resetN;
logic [10:0] pixelX, pixelY;
logic        startOfFrame;
logic [7:0]  RGB;
logic [9:0]  keyIsPressed;      // keyIsPressed[n] = keypad digit n is held down
logic [18:0] vgaAddress;        // unused here (only the game's background ROM needs it)
logic [1:0]  hookState;
logic        paused;

CLK_31P5 u_pll (
    .refclk   (CLOCK_50),
    .rst      (!resetN_pin),
    .outclk_0 (clk),
    .locked   (resetN)
);

VGA_Controller u_vga (
    .RGBIn        (RGB),
    .PixelX       (pixelX),
    .PixelY       (pixelY),
    .startOfFrame (startOfFrame),
    .oVGA         (OVGA),
    .address      (vgaAddress),
    .clk          (clk),
    .resetN       (resetN)
);

// the project's keyboard block (TOP_KBD.bdf + KBDINTF.qxp), clocked by clk like in the game
TOP_KBD u_kbd (
    .CLOCK_50     (clk),
    .resetN       (resetN),
    .PS2_CLK      (PS2_CLK),
    .PS2_DAT      (PS2_DAT),
    .keyIsPressed (keyIsPressed)
);

hook_speed_test_core u_core (
    .clk, .resetN, .startOfFrame, .pixelX, .pixelY,
    .key_shoot (keyIsPressed[2]),
    .key_catch (keyIsPressed[8]),
    .key_pause (keyIsPressed[5]),
    .key_reset (keyIsPressed[0]),
    .RGBout    (RGB),
    .greenLight, .yellowLight, .redLight,
    .paused, .hookState
);

endmodule
