// hud_number - a number of up to 3 decimal digits on the HUD, left-aligned (B10, Oct 2026)
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  * value = {hundreds, tens, ones}, 4 bits per digit.
//  * No leading zeros, and the number starts at X: 7 is drawn as "7", 42 as "42", 305 as "305".
//    So place 0 shows the first digit that is not 0 (or the ones digit for 0..9), place 1 the next
//    one, place 2 the last one - each place is only drawn when the number has that many digits.
//  * Each place is one hud_digit (5x7 font drawn 4x bigger = 20x28 pixels), STEP pixels apart.
//  * Combinational, like hud_digit: game_hud registers the final colour.

module hud_number #(
    parameter int X    = 0,     // top-left corner of the first digit place
    parameter int Y    = 0,
    parameter int STEP = 24     // distance between two digit places
) (
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic [11:0] value,  // {H, T, O}
    output logic        hit     // 1 = the pixel is on one of the digits
);

logic [3:0] H, T, O;
assign H = value[11:8];
assign T = value[7:4];
assign O = value[3:0];

// which digit goes in each place, and is the place used
logic [3:0] p0, p1, p2;
logic       use1, use2;
assign p0   = (H != 4'd0) ? H : (T != 4'd0) ? T : O;
assign p1   = (H != 4'd0) ? T : O;
assign p2   = O;
assign use1 = (H != 4'd0) || (T != 4'd0);       // 2 or 3 digits
assign use2 = (H != 4'd0);                      // 3 digits

logic hit0, hit1, hit2;
hud_digit #(.X(X),            .Y(Y)) place0 (.pixelX, .pixelY, .digit(p0), .show(1'b1), .hit(hit0));
hud_digit #(.X(X + STEP),     .Y(Y)) place1 (.pixelX, .pixelY, .digit(p1), .show(use1), .hit(hit1));
hud_digit #(.X(X + 2 * STEP), .Y(Y)) place2 (.pixelX, .pixelY, .digit(p2), .show(use2), .hit(hit2));

assign hit = hit0 || hit1 || hit2;

endmodule
