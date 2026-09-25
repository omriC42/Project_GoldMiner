// GoldsMatrixBitMap File 
// A two level bitmap. displaying randomly spawned rocks and gold on the screen in an 8x4 grid (8 columns x 4 rows).
// Tailored to rock/gold sizes of: Large (64x64), Medium (32x32), and Small (16x16).
// (c) Technion IIT, Department of Electrical Engineering 2026

module	GoldsMatrixBitMap	(	
					input	logic	clk,
					input	logic	resetN,
					input logic	[10:0] offsetX,// offset from top left position 
					input logic	[10:0] offsetY,
					input	logic	InsideRectangle, // input that the pixel is within the grid area
					input logic random_hart, // unused
					input logic collision_Miner_Gold, // collision from miner hook/smiley

					output	logic	drawingRequest, // output that the pixel should be displayed 
					output	logic	[7:0] RGBout,  // rgb value from the bitmap (3-3-2 format)
					output	logic	collectPulse,  // one clock pulse when the hook takes an object
					output	logic	[5:0] collectValue  // the value of that object in dollars
 ) ;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// RGB value representing a transparent pixel 

localparam  int TILE_NUMBER_OF_X_BITS = 6;  // 2^6 = 64 pixels per cell_idx width
localparam  int TILE_NUMBER_OF_Y_BITS = 6;  // 2^6 = 64 pixels per cell_idx height

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
// and is sampled while resetN is low, so the layout depends on WHEN reset happens.
// 96 bits are enough for up to 13 objects * 7 bits.
logic [95:0] rand_counter = 96'hABCD1234_5A5AC3C3_0F1E2D3C;

always_ff @(posedge clk) begin
    rand_counter <= {rand_counter[94:0], rand_counter[95] ^ rand_counter[93] ^ rand_counter[48] ^ rand_counter[46]};
end

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		collectPulse <= 1'b0;
		collectValue <= 6'd0;
		
		// Row 0 is ALWAYS empty (smiley/miner area)
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
	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default 
		
		// Clear object from grid cell_idx on collision with miner's hook
		// and report what was collected (only once: the next pixels see an empty cell)
		collectPulse <= 1'b0; // default
		if (collision_Miner_Gold && InsideRectangle && (offsetY_MSB != 2'b00)
		    && (MazeBitMapMask[offsetY_MSB][offsetX_MSB] != 3'd0)) begin
			MazeBitMapMask[offsetY_MSB][offsetX_MSB] <= 3'd0;
			collectPulse <= 1'b1;
			collectValue <= objectValue(MazeBitMapMask[offsetY_MSB][offsetX_MSB]);
		end
		
		// Ensure Row 0 (the top row of cells) is never drawn
		if (InsideRectangle == 1'b1 && offsetY_MSB != 2'b00)	
		begin 
			automatic logic [2:0] obj = MazeBitMapMask[offsetY_MSB][offsetX_MSB];
			automatic int dx = int'(offsetX_LSB) - 32;
			automatic int dy = int'(offsetY_LSB) - 32;
			automatic int abs_dx = (dx < 0) ? -dx : dx;
			automatic int abs_dy = (dy < 0) ? -dy : dy;
			
			case (obj)
				3'd0: RGBout <= TRANSPARENT_ENCODING;
				
				// Gold Small (16x16 -> R = 8)
				3'd1: begin
					if (dx*dx + dy*dy <= 8*8) begin
						if (dx*dx + dy*dy <= 2*2)
							RGBout <= 8'hFF; // Highlight
						else if (dx + dy > 4)
							RGBout <= 8'hD4; // Shadow
						else
							RGBout <= 8'hFC; // Shiny gold
					end else begin
						RGBout <= TRANSPARENT_ENCODING;
					end
				end
				
				// Gold Medium (32x32 -> R = 16)
				3'd2: begin
					if (dx*dx + dy*dy <= 16*16) begin
						if (dx*dx + dy*dy <= 5*5)
							RGBout <= 8'hFF; // Highlight
						else if (dx + dy > 8)
							RGBout <= 8'hD4; // Shadow
						else
							RGBout <= 8'hFC; // Gold
					end else begin
						RGBout <= TRANSPARENT_ENCODING;
					end
				end
				
				// Gold Large (64x64 -> R = 28)
				3'd3: begin
					if (dx*dx + dy*dy <= 28*28) begin
						if (dx*dx + dy*dy <= 9*9)
							RGBout <= 8'hFF; // Highlight
						else if (dx + dy > 14)
							RGBout <= 8'hD4; // Shadow
						else
							RGBout <= 8'hFC; // Gold
					end else begin
						RGBout <= TRANSPARENT_ENCODING;
					end
				end
				
				// Rock Small (16x16 -> R = 8)
				3'd4: begin
					if (abs_dx <= 8 && abs_dy <= 8 && (abs_dx + abs_dy <= 11)) begin
						if (dx + dy > 4)
							RGBout <= 8'h24; // Shadow
						else if (dx + dy < -4)
							RGBout <= 8'hB6; // Highlight
						else
							RGBout <= 8'h49; // Rock body
					end else begin
						RGBout <= TRANSPARENT_ENCODING;
					end
				end
				
				// Rock Medium (32x32 -> R = 16)
				3'd5: begin
					if (abs_dx <= 16 && abs_dy <= 16 && (abs_dx + abs_dy <= 21)) begin
						if (dx + dy > 8)
							RGBout <= 8'h24;
						else if (dx + dy < -8)
							RGBout <= 8'hB6;
						else if ((offsetX_LSB ^ offsetY_LSB) % 5 == 0)
							RGBout <= 8'h6D; // Rock detail texture
						else
							RGBout <= 8'h49;
					end else begin
						RGBout <= TRANSPARENT_ENCODING;
					end
				end
				
				// Rock Large (64x64 -> R = 28)
				3'd6: begin
					if (abs_dx <= 28 && abs_dy <= 28 && (abs_dx + abs_dy <= 37)) begin
						if (dx + dy > 14)
							RGBout <= 8'h24;
						else if (dx + dy < -14)
							RGBout <= 8'hB6;
						else if ((offsetX_LSB ^ offsetY_LSB) % 7 == 0)
							RGBout <= 8'h6D; // Rock detail texture
						else
							RGBout <= 8'h49;
					end else begin
						RGBout <= TRANSPARENT_ENCODING;
					end
				end
				
				default: RGBout <= TRANSPARENT_ENCODING;
			endcase
		end 
	end 
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING ) ? 1'b1 : 1'b0 ; 

endmodule
