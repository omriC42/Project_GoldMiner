// ObjectsMatrixBitMap File (was GoldsMatrixBitMap) 
// A two level bitmap. displaying randomly spawned rocks and gold on the screen in an 8x4 grid (8 columns x 4 rows).
// Sprites: Large (64x64), Medium (32x32), Small (16x16) bitmaps made with BMPConverter_V21 (8-bit RRRGGGBB, 8'hFF = transparent).
// (c) Technion IIT, Department of Electrical Engineering 2026

module	ObjectsMatrixBitMap	(	
					input	logic	clk,
					input	logic	resetN,
					input logic	[10:0] offsetX,// offset from top left position 
					input logic	[10:0] offsetY,
					input	logic	InsideRectangle, // input that the pixel is within the grid area
					input logic collision_Hook_Object, // collision from miner hook/miner
					input logic newLevel, // one clock pulse from game_hud: level won -> build a new layout

					output	logic	drawingRequest, // output that the pixel should be displayed 
					output	logic	[7:0] RGBout,  // rgb value from the bitmap (3-3-2 format)
					output	logic	collectPulse,  // one clock pulse when the hook takes an object
					output	logic	[5:0] collectValue  // the value of that object in dollars
 ) ;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// RGB value representing a transparent pixel 

localparam  int TILE_NUMBER_OF_X_BITS = 6;  // 2^6 = 64 pixels per cell width
localparam  int TILE_NUMBER_OF_Y_BITS = 6;  // 2^6 = 64 pixels per cell height

localparam  int MAZE_NUMBER_OF__X_BITS = 3;  // 2^3 = 8 columns (8*64 = 512 pixels wide)
localparam  int MAZE_NUMBER_OF__Y_BITS = 2;  // 2^2 = 4 rows

logic [10:0] offsetX_LSB  ;
logic [10:0] offsetY_LSB  ; 
logic [10:0] offsetX_MSB ;
logic [10:0] offsetY_MSB  ;

assign offsetX_LSB  = offsetX[(TILE_NUMBER_OF_X_BITS-1):0] ; 
assign offsetY_LSB  = offsetY[(TILE_NUMBER_OF_Y_BITS-1):0] ; 
assign offsetX_MSB  = offsetX[(TILE_NUMBER_OF_X_BITS + MAZE_NUMBER_OF__X_BITS -1 ):TILE_NUMBER_OF_X_BITS] ; 
assign offsetY_MSB  = offsetY[(TILE_NUMBER_OF_Y_BITS + MAZE_NUMBER_OF__Y_BITS -1 ):TILE_NUMBER_OF_Y_BITS] ; 

// Grid storing object type and size inside each cell_idx:
// 3'd0: Empty
// 3'd1: Gold Small (16x16)
// 3'd2: Gold Medium (32x32)
// 3'd3: Gold Large (64x64)
// 3'd4: Rock Small (16x16)
// 3'd5: Rock Medium (32x32)
// 3'd6: Rock Large (64x64)
localparam  int NUM_COLS = 1 << MAZE_NUMBER_OF__X_BITS ; // 8
localparam  int NUM_ROWS = 1 << MAZE_NUMBER_OF__Y_BITS ; // 4

// ---- DENSITY SETTING --------------------------------------------------------
// Rows 1-3 give 3*8 = 24 playable cells. They are split into groups of
// CELLS_PER_OBJECT consecutive cells, and exactly ONE object is placed in a
// random cell_idx of each group (all the other cells of the group stay empty).
//   CELLS_PER_OBJECT = 2 -> 12 objects (half the cells empty)
//   CELLS_PER_OBJECT = 3 ->  8 objects (2/3 of the cells empty)   <-- current
//   CELLS_PER_OBJECT = 4 ->  6 objects (3/4 of the cells empty)
// Must divide 24 evenly (2, 3, 4, 6, 8, 12).
localparam  int CELLS_PER_OBJECT = 3;
localparam  int PLAY_CELLS  = (NUM_ROWS - 1) * NUM_COLS ;      // 24
localparam  int NUM_OBJECTS = PLAY_CELLS / CELLS_PER_OBJECT ;  // 8
localparam  int RAND_BITS_PER_OBJECT = 7 ; // 4 bits position + 1 bit gold/rock + 2 bits size

logic [2:0] MazeBitMapMask [0:NUM_ROWS-1][0:NUM_COLS-1];  

// ---- VALUES (dollars) --------------------------------------------------------
// gold: small 12, medium 24, large 36.   rock: a third of the gold of the same size.
localparam logic [5:0] GOLD_SMALL_VALUE  = 6'd12;
localparam logic [5:0] GOLD_MEDIUM_VALUE = 6'd24;
localparam logic [5:0] GOLD_LARGE_VALUE  = 6'd36;
localparam logic [5:0] ROCK_SMALL_VALUE  = GOLD_SMALL_VALUE  / 6'd3;  //  4
localparam logic [5:0] ROCK_MEDIUM_VALUE = GOLD_MEDIUM_VALUE / 6'd3;  //  8
localparam logic [5:0] ROCK_LARGE_VALUE  = GOLD_LARGE_VALUE  / 6'd3;  // 12

function automatic logic [5:0] objectValue(input logic [2:0] obj);
	case (obj)
		3'd1:    objectValue = GOLD_SMALL_VALUE;
		3'd2:    objectValue = GOLD_MEDIUM_VALUE;
		3'd3:    objectValue = GOLD_LARGE_VALUE;
		3'd4:    objectValue = ROCK_SMALL_VALUE;
		3'd5:    objectValue = ROCK_MEDIUM_VALUE;
		3'd6:    objectValue = ROCK_LARGE_VALUE;
		default: objectValue = 6'd0;
	endcase
endfunction

// 96-bit LFSR (taps 96,94,49,47 = maximal length). It runs freely all the time
// and is sampled on the first clock after reset (and at every new level), so the
// layout depends on WHEN reset / the new level happens.
// 96 bits are enough for up to 13 objects * 7 bits.
logic [95:0] rand_counter = 96'hABCD1234_5A5AC3C3_0F1E2D3C;

always_ff @(posedge clk) begin
    rand_counter <= {rand_counter[94:0], rand_counter[95] ^ rand_counter[93] ^ rand_counter[48] ^ rand_counter[46]};
end

// ---- layout memory ------------------------------------------------------------
// loadLayout (first clock after reset) or newLevel (level won) -> build a new random layout.
// It is built synchronously: building it inside the asynchronous reset (the old way) made
// Quartus replace the grid registers with latches (warnings 13004/13310).
logic loadLayout;
logic clearCell;   // the hook touches an object on the current pixel
assign clearCell = collision_Hook_Object && InsideRectangle && (offsetY_MSB != 2'b00)
                   && (MazeBitMapMask[offsetY_MSB][offsetX_MSB] != 3'd0);

always_ff @(posedge clk)
begin
	if (loadLayout || newLevel) begin
			// Row 0 is ALWAYS empty (miner/miner area)
			for (int c = 0; c < NUM_COLS; c++)
				MazeBitMapMask[0][c] <= 3'd0;
		
			// Place exactly one object per group of CELLS_PER_OBJECT cells in rows 1-3
			for (int j = 0; j < NUM_OBJECTS; j++) begin
				automatic logic [6:0] r       = rand_counter[j*RAND_BITS_PER_OBJECT +: RAND_BITS_PER_OBJECT];
				automatic int         pos     = int'(r[3:0]) % CELLS_PER_OBJECT; // which cell_idx of the group gets the object
				automatic logic       is_gold = r[4];
				automatic logic [1:0] size_opt = r[6:5];
				automatic logic [2:0] obj_val;
			
				// Determine object type and size
				if (is_gold) begin
					if (size_opt == 2'b00) obj_val = 3'd1; // Gold Small
					else if (size_opt == 2'b01) obj_val = 3'd2; // Gold Medium
					else obj_val = 3'd3; // Gold Large
				end else begin
					if (size_opt == 2'b00) obj_val = 3'd4; // Rock Small
					else if (size_opt == 2'b01) obj_val = 3'd5; // Rock Medium
					else obj_val = 3'd6; // Rock Large
				end
			
				// Write the group: object in cell_idx 'pos', empty elsewhere
				for (int k = 0; k < CELLS_PER_OBJECT; k++) begin
					automatic int cell_idx = j*CELLS_PER_OBJECT + k;   // 0..23
					automatic int row  = (cell_idx / NUM_COLS) + 1;    // +1 to skip row 0
					automatic int col  =  cell_idx % NUM_COLS;
					MazeBitMapMask[row][col] <= (k == pos) ? obj_val : 3'd0;
				end
			end
	end
	else if (clearCell)
		MazeBitMapMask[offsetY_MSB][offsetX_MSB] <= 3'd0;  // the hook took it
end


// ---- SPRITE BITMAPS (BMPConverter_V21) -----------------------------------------
// Every cell is 64x64. A sprite smaller than the cell is drawn in the MIDDLE of the cell:
//   small  16x16 -> cell pixels 24..39      medium 32x32 -> cell pixels 16..47
//   large  64x64 -> the whole cell (its own transparent margin keeps it inside)
// Source images: _new_assets/objects/*.png (256x256). Converter: Scale 4 -> 16x16,
// Scale 3 -> 32x32, Scale 2 -> 64x64, MODE 0, 8-bit, Create Output Files.

// Gold Small - 16x16, generated by BMPConverter_V21 (Mode 8-bit). Row 0 = TOP of the sprite.
logic [0:15][0:15][7:0] gold_small_colors = {
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'h8C,8'hFC,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'h8C,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF4,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF4,8'hF4,8'h8C,8'hFF},
	{8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF4,8'hF8,8'h8C,8'hFF},
	{8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF4,8'h8C,8'hFF,8'hFF},
	{8'h8C,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF4,8'hD4,8'hF4,8'h8C,8'hFF},
	{8'h8C,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF},
	{8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'h8C,8'hFF},
	{8'hFF,8'h8C,8'hF8,8'hF4,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF8,8'h8C,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF8,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};

// Gold Medium - 32x32, generated by BMPConverter_V21 (Mode 8-bit). Row 0 = TOP of the sprite.
logic [0:31][0:31][7:0] gold_medium_colors = {
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hFC,8'h8C,8'h8C,8'h8C,8'hFC,8'hFC,8'hF8,8'hF8,8'hD4,8'hF8,8'hF8,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hD8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF4,8'hD4,8'hF4,8'hF8,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFD,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hD4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hF8,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF8,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hD4,8'hF4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF4,8'hF8,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hD4,8'hF4,8'hF4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF4,8'hF4,8'hF4,8'hD4,8'hF8,8'hF4,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'hD4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF8,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};

// Gold Large - 64x64, generated by BMPConverter_V21 (Mode 8-bit). Row 0 = TOP of the sprite.
logic [0:63][0:63][7:0] gold_large_colors = {
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFD,8'hFC,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFC,8'hFD,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFC,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFC,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFD,8'hFD,8'hFC,8'hFC,8'hFD,8'hFD,8'hFC,8'hF8,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFD,8'hFD,8'hFD,8'hFD,8'hFD,8'hFC,8'hFC,8'hF8,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFD,8'hFD,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFD,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFD,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hFC,8'hFC,8'hFC,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hFC,8'hF8,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hFC,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF8,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF8,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF4,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF8,8'hF8,8'hF8,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF8,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hF4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hD4,8'hF4,8'hF4,8'hD4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hD4,8'hD4,8'hD4,8'hD4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hD4,8'hF4,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF4,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hD4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF8,8'hF4,8'hF4,8'hF8,8'hF4,8'hF4,8'hF4,8'hF4,8'hF4,8'hF8,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF4,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF8,8'hF8,8'hF4,8'hF4,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF4,8'hF4,8'hF8,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'hF8,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};

// Rock Small - 16x16, generated by BMPConverter_V21 (Mode 8-bit). Row 0 = TOP of the sprite.
logic [0:15][0:15][7:0] rock_small_colors = {
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h92,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'hB6,8'h25,8'hFF},
	{8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'hB6,8'h25,8'hFF},
	{8'hFF,8'h25,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF},
	{8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h25,8'hFF},
	{8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'h25,8'hFF},
	{8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF},
	{8'hFF,8'h25,8'hB6,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'h25,8'h25,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};

// Rock Medium - 32x32, generated by BMPConverter_V21 (Mode 8-bit). Row 0 = TOP of the sprite.
logic [0:31][0:31][7:0] rock_medium_colors = {
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h25,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h25,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h25,8'hFF,8'hFF},
	{8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'h25,8'hB6,8'hB6,8'hB6,8'h25,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'hFF,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};

// Rock Large - 64x64, generated by BMPConverter_V21 (Mode 8-bit). Row 0 = TOP of the sprite.
logic [0:63][0:63][7:0] rock_large_colors = {
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hDB,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hDB,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'hB6,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'h25,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};

// ---- position of the current pixel inside a sprite -------------------------------
localparam logic [5:0] SMALL_START  = 6'd24;   // (64-16)/2
localparam logic [5:0] MEDIUM_START = 6'd16;   // (64-32)/2

logic [5:0] cellX, cellY;        // pixel inside the 64x64 cell (0..63)
logic [5:0] smallX, smallY;      // pixel inside a 16x16 sprite (valid when inSmall)
logic [5:0] mediumX, mediumY;    // pixel inside a 32x32 sprite (valid when inMedium)
logic       inSmall, inMedium;

assign cellX   = offsetX_LSB[5:0];
assign cellY   = offsetY_LSB[5:0];
assign smallX  = cellX - SMALL_START;
assign smallY  = cellY - SMALL_START;
assign mediumX = cellX - MEDIUM_START;
assign mediumY = cellY - MEDIUM_START;
assign inSmall  = (cellX >= SMALL_START)  && (cellX < SMALL_START  + 6'd16) &&
                  (cellY >= SMALL_START)  && (cellY < SMALL_START  + 6'd16);
assign inMedium = (cellX >= MEDIUM_START) && (cellX < MEDIUM_START + 6'd32) &&
                  (cellY >= MEDIUM_START) && (cellY < MEDIUM_START + 6'd32);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		collectPulse <= 1'b0;
		collectValue <= 6'd0;
		loadLayout <= 1'b1;  // build a layout on the first clock after reset
	end
	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default 
		
		loadLayout <= 1'b0;

		// report what the hook collected (only once: from the next clock the cell is empty)
		collectPulse <= clearCell && !loadLayout && !newLevel;
		if (clearCell)
			collectValue <= objectValue(MazeBitMapMask[offsetY_MSB][offsetX_MSB]);
		
		// Ensure Row 0 (the top row of cells) is never drawn
		if (InsideRectangle == 1'b1 && offsetY_MSB != 2'b00)
		begin
			// read the sprite of the object stored in this cell (8'hFF in the bitmap = transparent)
			case (MazeBitMapMask[offsetY_MSB][offsetX_MSB])
				3'd1: if (inSmall)  RGBout <= gold_small_colors [smallY[3:0]] [smallX[3:0]];   // Gold Small  16x16
				3'd2: if (inMedium) RGBout <= gold_medium_colors[mediumY[4:0]][mediumX[4:0]];  // Gold Medium 32x32
				3'd3:              RGBout <= gold_large_colors [cellY]       [cellX];          // Gold Large  64x64
				3'd4: if (inSmall)  RGBout <= rock_small_colors [smallY[3:0]] [smallX[3:0]];   // Rock Small  16x16
				3'd5: if (inMedium) RGBout <= rock_medium_colors[mediumY[4:0]][mediumX[4:0]];  // Rock Medium 32x32
				3'd6:              RGBout <= rock_large_colors [cellY]       [cellX];          // Rock Large  64x64
				default:           RGBout <= TRANSPARENT_ENCODING;                             // 0 = empty
			endcase
		end
	end
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING ) ? 1'b1 : 1'b0 ; 

endmodule
