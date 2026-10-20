// System-Verilog 'written by Alex Grinshpun May 2018
// New bitmap dudy February 2025
// (c) Technion IIT, Department of Electrical Engineering 2025 



module	minerBitMap	(	
					input	logic	clk,
					input	logic	resetN,
					input logic	[10:0] offsetX,// offset from top left  position 
					input logic	[10:0] offsetY,
					input	logic	InsideRectangle, //input that the pixel is within a bracket 

					output	logic	drawingRequest, //output that the pixel should be dispalyed 
					output	logic	[7:0] RGBout,  //rgb value from the bitmap 
				   output   logic	[2:0] HitEdgeCode 
 ) ;

// this is the devider used to acess the right pixel 
localparam  int OBJECT_NUMBER_OF_Y_BITS = 6;  // 2^6 = 64 (miner sprite is 64x64)
localparam  int OBJECT_NUMBER_OF_X_BITS = 6;  // 2^6 = 64 


localparam  int OBJECT_HEIGHT_Y = 1 <<  OBJECT_NUMBER_OF_Y_BITS ;
localparam  int OBJECT_WIDTH_X = 1 <<  OBJECT_NUMBER_OF_X_BITS;

 logic	[10:0] HitCodeX ;// offset of Hitcode 
 logic	[10:0] HitCodeY ; 
assign HitCodeX = offsetX >> ( OBJECT_NUMBER_OF_X_BITS - 4 );	// hitedge code MSB of the offset
assign HitCodeY = offsetY >> ( OBJECT_NUMBER_OF_Y_BITS - 4 );	 	 

// generating a miner bitmap

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// RGB value in the bitmap representing a transparent pixel 

logic [0:OBJECT_HEIGHT_Y-1] [0:OBJECT_WIDTH_X-1] [7:0] object_colors = {
// miner in a mine cart, 64x64, RRRGGGBB, 8'hFF = transparent. Row 0 = TOP of the sprite.
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'h24,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'h24,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'h24,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'h24,8'hFA,8'hFA,8'hFA,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'h24,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'h24,8'hFA,8'hFA,8'hFA,8'hFA,8'hFA,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'h24,8'hF5,8'hFA,8'hFA,8'hFA,8'hFA,8'hFA,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'h24,8'h24,8'hB6,8'hB6,8'hB6,8'h24,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'h24,8'hB6,8'hB6,8'hB6,8'h24,8'h24,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'hFE,8'h00,8'hF5,8'hF5,8'hF5,8'hF1,8'hF1,8'hF1,8'hF5,8'hF5,8'hFE,8'h00,8'hD1,8'hD1,8'hD1,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'h00,8'h00,8'hF5,8'hF5,8'hF1,8'hFA,8'hF1,8'hF1,8'hF1,8'hF5,8'h00,8'h00,8'hD1,8'hD1,8'hD1,8'hD1,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'hB6,8'hB6,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'h00,8'h00,8'hF5,8'hF1,8'hFA,8'hFA,8'hFA,8'hF1,8'hF1,8'hF1,8'h00,8'h00,8'hD1,8'hD1,8'hD1,8'hD1,8'hB6,8'hB6,8'hB6,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hF5,8'hF5,8'hB6,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF1,8'hF1,8'hFA,8'hF1,8'hF1,8'hF1,8'hF1,8'hD1,8'hD1,8'hD1,8'hD1,8'hD1,8'hD1,8'hB6,8'hD1,8'hD1,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hF5,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hD1,8'hD1,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hF5,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hD1,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hF1,8'hF1,8'hF1,8'hF1,8'hF1,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hF1,8'hF1,8'hF1,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'h92,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hDB,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'h92,8'h92,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'h84,8'h84,8'hB6,8'hB6,8'hB6,8'h84,8'h84,8'h84,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hB6,8'hB6,8'hDB,8'hDB,8'hDB,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'h84,8'h84,8'h84,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hD0,8'hB6,8'hB6,8'hB6,8'hDB,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hD0,8'hD0,8'hD0,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h88,8'h88,8'h88,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h88,8'h88,8'h88,8'h88,8'h24,8'hFF,8'hFF,8'h24,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'hB6,8'h88,8'h88,8'h88,8'h88,8'h88,8'h88,8'h24,8'h24,8'h24,8'hF5,8'hD1,8'hD1,8'hD1,8'hD1,8'hD1,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'h24,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hD0,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'h92,8'h92,8'h92,8'hB6,8'hB6,8'h88,8'h88,8'h88,8'h88,8'h88,8'hAC,8'hAC,8'hAC,8'hAC,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h88,8'h88,8'h88,8'hD0,8'hD0,8'hD0,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h92,8'hB6,8'hB6,8'hB6,8'hB6,8'h88,8'h88,8'hAC,8'hAC,8'hAC,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'hAC,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h88,8'h88,8'h88,8'hD0,8'hF5,8'hF5,8'hF5,8'hD0,8'hD0,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h88,8'h88,8'h88,8'h88,8'h88,8'hAC,8'hAC,8'hAC,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'hAC,8'hAC,8'hF5,8'hF5,8'hF5,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h88,8'h88,8'h88,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hAC,8'hAC,8'hAC,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'hAC,8'hAC,8'h88,8'h88,8'h88,8'h88,8'h88,8'hAC,8'hAC,8'hAC,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'hAC,8'hAC,8'hDB,8'hDB,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h49,8'h00,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'hAC,8'hAC,8'hDB,8'hDB,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h49,8'h00,8'hF5,8'hD1,8'hD1,8'hD1,8'hD1,8'hD1,8'hF5,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'h24,8'h24,8'hDB,8'hDB,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h49,8'h00,8'h00,8'hF5,8'hF5,8'hF5,8'hF5,8'hF5,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'h92,8'h92,8'hDB,8'hDB,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h00,8'h49,8'h00,8'h00,8'hF5,8'hF5,8'hF5,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'h92,8'h92,8'hDB,8'hDB,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'h24,8'h24,8'h24,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h64,8'h64,8'hA8,8'hA8,8'hA8,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'h49,8'h00,8'h00,8'hA8,8'hA8,8'hA8,8'h64,8'h64,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h24,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'hDB,8'h24,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h24,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h24,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h24,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h24,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'h24,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h49,8'h49,8'h49,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h49,8'h49,8'h49,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h92,8'h24,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'h24,8'h24,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h24,8'h24,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h68,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h49,8'hDB,8'h49,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h49,8'hDB,8'h49,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h68,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h49,8'h49,8'h49,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h49,8'h49,8'h49,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'hDB,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'hDB,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h68,8'h8C,8'h8C,8'h8C,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h8C,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h8C,8'h8C,8'h8C,8'h68,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h44,8'h44,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h44,8'h44,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h68,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h68,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h68,8'h49,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h49,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h68,8'h49,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h49,8'h68,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'h49,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h44,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'h49,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h24,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'hB6,8'hB6,8'hB6,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF},
	{8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'h24,8'h49,8'h49,8'h49,8'h49,8'h49,8'h24,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF}
};


//////////--------------------------------------------------------------------------------------------------------------=
//hit bit map has one encoding per edge:  hit_colors[2:0] =   
 
logic [0:15] [0:15] [2:0] hit_colors = 
		  {48'o4433333333333344,     
			48'o4443333333333444,    
			48'o1444333333334442, 
			48'o1144433333344422,
			48'o1114443333444222,
			48'o1111444334442222,
			48'o1111144444422222,
			48'o1111114444222222,
			48'o1111114444222222,
			48'o1111144444422222,
			48'o1111444004442222,
			48'o1114440000444222,
			48'o1144400000044422,
			48'o1444000000004442,
			48'o4440000000000444,
			48'o4400000000000044};
 
 
// pipeline (ff) to get the pixel color from the array 	 

//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout <=	8'h00;
		HitEdgeCode <= 3'h0;

	end

	else begin
		RGBout <= TRANSPARENT_ENCODING ; // default  
		HitEdgeCode <= 3'h0;

		if (InsideRectangle == 1'b1 ) 
		begin // inside an external bracket 
			RGBout <= object_colors[offsetY][offsetX]; // row 0 of the table is the top (no vertical flip)
			HitEdgeCode <= hit_colors[HitCodeY][HitCodeX];	//get hitting edge code from the colors table  
		
		end  	
	end
		
end

//////////--------------------------------------------------------------------------------------------------------------=
// decide if to draw the pixel or not 
assign drawingRequest = (RGBout != TRANSPARENT_ENCODING ) ? 1'b1 : 1'b0 ; // get optional transparent command from the bitmpap   

endmodule