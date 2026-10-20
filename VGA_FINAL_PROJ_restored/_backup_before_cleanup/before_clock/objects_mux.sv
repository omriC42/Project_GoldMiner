
// (c) Technion IIT, Department of Electrical Engineering 2025 
//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// SystemVerilog version Alex Grinshpun May 2018
// coding convention dudy December 2018

//-- Eyal Lev 31 Jan 2021

module	objects_mux	(	
					input		logic	clk,
					input		logic	resetN,
		   // smiley 
					input		logic	smileyDrawingRequest,
					input		logic	[7:0] smileyRGB, 
					     
		  // add the box for numbers here 
					input logic [7:0] boxRGB,
					input logic boxDrawingRequest,
		  // dust behind the mine cart (under the miner, not part of any collision)
					input    logic dustDrawingRequest,
					input		logic	[7:0] dustRGB,

		  // Gold field (gold + rocks, drawn by GoldsMatrixBitMap)
					input    logic GoldDrawingRequest, 
					input		logic	[7:0] goldRGB,   
					
		  // background 
					input		logic	[7:0] backGroundRGB, 
					input		logic	BGDrawingRequest, 
					input		logic	[7:0] RGB_MIF, 
			                  
				   output	logic	[7:0] RGBOut
);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
			RGBOut	<= 8'b0;
	end
	
	else begin
		if (smileyDrawingRequest == 1'b1 )   
			RGBOut <= smileyRGB;  //first priority 
		else if(boxDrawingRequest == 1'b1) 
			RGBOut <= boxRGB;
		else if (dustDrawingRequest == 1'b1)
			RGBOut <= dustRGB;
 		else if (GoldDrawingRequest == 1'b1)
			RGBOut <= goldRGB;
		else if (BGDrawingRequest == 1'b1)
			RGBOut <= backGroundRGB ;
		else RGBOut <= RGB_MIF ;// last priority 
	end 
end

endmodule


