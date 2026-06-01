// System-Verilog 'written by Alex Grinshpun May 2018
// New bitmap dudy February 2025
// (c) Technion IIT, Department of Electrical Engineering 2025 



module	smileyBitMap	(	
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
localparam  int OBJECT_NUMBER_OF_Y_BITS = 4; 
localparam  int OBJECT_NUMBER_OF_X_BITS = 5;  


localparam  int OBJECT_HEIGHT_Y = 1 <<  OBJECT_NUMBER_OF_Y_BITS ;
localparam  int OBJECT_WIDTH_X = 1 <<  OBJECT_NUMBER_OF_X_BITS;

 logic	[10:0] HitCodeX ;// offset of Hitcode 
 logic	[10:0] HitCodeY ; 
assign HitCodeX = offsetX >> ( OBJECT_NUMBER_OF_X_BITS - 4 );	// hitedge code MSB of the offset
assign HitCodeY = offsetY >> ( OBJECT_NUMBER_OF_Y_BITS - 4 );	 	 

// generating a smiley bitmap

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// RGB value in the bitmap representing a transparent pixel 

// Auto-generated bitmap
// Mode: 8-bit

// Auto-generated bitmap
// Mode: 8-bit


logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][7:0] object_colors = {
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0},
	{8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0,8'hE0}
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
			RGBout <= object_colors[OBJECT_HEIGHT_Y-1 - offsetY][offsetX];
			HitEdgeCode <= hit_colors[HitCodeY][HitCodeX];	//get hitting edge code from the colors table  
		
		end  	
	end
		
end

//////////--------------------------------------------------------------------------------------------------------------=
// decide if to draw the pixel or not 
assign drawingRequest = (RGBout != TRANSPARENT_ENCODING ) ? 1'b1 : 1'b0 ; // get optional transparent command from the bitmpap   

endmodule