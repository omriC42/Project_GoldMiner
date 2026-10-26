// bcd_add3 - adds two 3-digit decimal (BCD) numbers, the way it is done on paper
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  * a and b are 3 decimal digits each, 4 bits per digit: {hundreds, tens, ones}, every digit 0..9.
//  * Each column adds the two digits and the carry from the column on its right. A column sum above 9
//    keeps (sum - 10) and carries 1 to the next column.
//  * The result stops at 999: a carry out of the hundreds column means the true sum is above 999.
//  * Combinational. Used by game_hud for "dollars + value" and for "target + target step".

module bcd_add3 (
    input  logic [11:0] a,      // {H, T, O}
    input  logic [11:0] b,      // {H, T, O}
    output logic [11:0] sum     // a + b as {H, T, O}, at most 999
);

logic [4:0] colO, colT, colH;   // column sums (0..19)
logic       carryO, carryT;     // carry into the tens / hundreds column
logic [3:0] digO, digT, digH;

always_comb begin
    colO   = 5'(a[3:0])  + 5'(b[3:0]);
    carryO = (colO > 5'd9);
    digO   = carryO ? 4'(colO - 5'd10) : 4'(colO);

    colT   = 5'(a[7:4])  + 5'(b[7:4])  + 5'(carryO);
    carryT = (colT > 5'd9);
    digT   = carryT ? 4'(colT - 5'd10) : 4'(colT);

    colH   = 5'(a[11:8]) + 5'(b[11:8]) + 5'(carryT);
    digH   = 4'(colH);

    if (colH > 5'd9)
        sum = 12'h999;                  // above 999 -> stop at 999
    else
        sum = {digH, digT, digO};
end

endmodule
