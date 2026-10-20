// GoldsMatrixBitMap File 
// A two level bitmap. displaying randomly spawned rocks and gold on the screen in a 4x4 grid.
// Tailored to rock/gold sizes of: Large (64x64), Medium (32x32), and Small (16x16).
// (c) Technion IIT, Department of Electrical Engineering 2026

module	GoldsMatrixBitMap	(	
					input	logic	clk,
					input	logic	resetN,
					input logic	[10:0] offsetX,// offset from top left position 
					input logic	[10:0] offsetY,
					input	logic	InsideRectangle, // input that the pixel is within the grid area
					input logic random_hart, // unused
					input logic collision_Smiley_Hart, // collision from miner hook/smiley

					output	logic	drawingRequest, // output that the pixel should be displayed 
					output	logic	[7:0] RGBout  // rgb value from the bitmap (3-3-2 format)
 ) ;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// RGB value representing a transparent pixel 

localparam  int TILE_NUMBER_OF_X_BITS = 6;  // 2^6 = 64 pixels per cell width
localparam  int TILE_NUMBER_OF_Y_BITS = 6;  // 2^6 = 64 pixels per cell height

localparam  int MAZE_NUMBER_OF__X_BITS = 2;  // 2^2 = 4 columns
localparam  int MAZE_NUMBER_OF__Y_BITS = 2;  // 2^2 = 4 rows

logic [10:0] offsetX_LSB  ;
logic [10:0] offsetY_LSB  ; 
logic [10:0] offsetX_MSB ;
logic [10:0] offsetY_MSB  ;

assign offsetX_LSB  = offsetX[(TILE_NUMBER_OF_X_BITS-1):0] ; 
assign offsetY_LSB  = offsetY[(TILE_NUMBER_OF_Y_BITS-1):0] ; 
assign offsetX_MSB  = offsetX[(TILE_NUMBER_OF_X_BITS + MAZE_NUMBER_OF__X_BITS -1 ):TILE_NUMBER_OF_X_BITS] ; 
assign offsetY_MSB  = offsetY[(TILE_NUMBER_OF_Y_BITS + MAZE_NUMBER_OF__Y_BITS -1 ):TILE_NUMBER_OF_Y_BITS] ; 

// Grid storing object type and size inside each cell:
// 3'd0: Empty
// 3'd1: Gold Small (16x16)
// 3'd2: Gold Medium (32x32)
// 3'd3: Gold Large (64x64)
// 3'd4: Rock Small (16x16)
// 3'd5: Rock Medium (32x32)
// 3'd6: Rock Large (64x64)
logic [2:0] MazeBitMapMask [0:3][0:3];  

logic [31:0] rand_counter;

always_ff @(posedge clk) begin
    rand_counter <= rand_counter + 1;
end

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		// Continuously randomize grid while in reset to have exactly 8 objects in total (one per pair)
		for (int j = 0; j < 8; j++) begin
			automatic logic choose_second = rand_counter[j];
			automatic logic [2:0] obj_val;
			automatic logic is_gold = rand_counter[j + 8];
			automatic logic [1:0] size_opt = rand_counter[j*2 + 16 +: 2];
			
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
			
			// Assign to grid cells
			if (choose_second) begin
				MazeBitMapMask[(2*j)/4][(2*j)%4] <= 3'd0;
				MazeBitMapMask[(2*j+1)/4][(2*j+1)%4] <= obj_val;
			end else begin
				MazeBitMapMask[(2*j)/4][(2*j)%4] <= obj_val;
				MazeBitMapMask[(2*j+1)/4][(2*j+1)%4] <= 3'd0;
			end
		end
	end
	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default 
		
		// Clear object from grid cell on collision with miner's hook
		if (collision_Smiley_Hart && InsideRectangle) begin
			MazeBitMapMask[offsetY_MSB][offsetX_MSB] <= 3'd0;
		end
		
		if (InsideRectangle == 1'b1)	
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
