
// (c) Technion IIT, Department of Electrical Engineering 2025 
//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// SystemVerilog version Alex Grinshpun May 2018
// coding convention dudy December 2018

//-- Eyal Lev 31 Jan 2021
// Oct 2026 (hook integration Step 6+8): hook input, drawn just below the miner
//   priority: miner > hook (rope + claw) > dust > timer > objects (gold/rocks) > background

module	objects_mux	(	
					input		logic	clk,
					input		logic	resetN,
		   // miner 
					input		logic	minerDrawingRequest,
					input		logic	[7:0] minerRGB, 
					     
		  // hook: rope + claw (hook_block)
					input    logic hookDrawingRequest,
					input		logic	[7:0] hookRGB,

		  // dust behind the mine cart (under the miner, not part of any collision)
					input    logic dustDrawingRequest,
					input		logic	[7:0] dustRGB,

		  // countdown clock (top right of the screen)
					input    logic timerDrawingRequest,
					input		logic	[7:0] timerRGB,

		  // objects field (gold + rocks, drawn by ObjectsMatrixBitMap)
					input    logic objectsDrawingRequest, 
					input		logic	[7:0] objectsRGB,   
					
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
		if (minerDrawingRequest == 1'b1 )   
			RGBOut <= minerRGB;  //first priority 
		else if (hookDrawingRequest == 1'b1)
			RGBOut <= hookRGB;    // rope + claw over everything except the miner
		else if (dustDrawingRequest == 1'b1)
			RGBOut <= dustRGB;
		else if (timerDrawingRequest == 1'b1)
			RGBOut <= timerRGB;
 		else if (objectsDrawingRequest == 1'b1)
			RGBOut <= objectsRGB;
		else if (BGDrawingRequest == 1'b1)
			RGBOut <= backGroundRGB ;
		else RGBOut <= RGB_MIF ;// last priority 
	end 
end

endmodule


