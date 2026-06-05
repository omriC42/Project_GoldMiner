// (c) Technion IIT, Department of Electrical Engineering 2025 
//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// SystemVerilog version Alex Grinshpun May 2018
// coding convention dudy December 2018
// updated Eyal Lev April 2023
// updated to state machine Dudy March 2023 
// update the hit and collision algoritm - Eyal MAR 2024
// good practice code - Dudy MAR 2025

module	hook_move	(	
 
					input	 logic clk,
					input	 logic resetN,
					input	 logic startOfFrame,      //short pulse every start of frame 30Hz 
					input	 logic shoot_key,   //move Y Up     
					input	 logic x0,
					input  logic y0,//maybe not needed implement as parameter?
					input  logic collision,         //legacy use for collision
					input  logic [2:0] HitEdgeCode, //legacy use for collision
					output logic signed 	[10:0] Xend, 
					output logic signed	[10:0] Yend  
					
);


// a module used to generate the hook angles.  



const int MAX_RADIUS_BITS = 10; //to be changed according to border
const int	FIXED_POINT_MULTIPLIER = 64; // note it must be 2^n 
// FIXED_POINT_MULTIPLIER is used to enable working with integers in high resolution so that 
// we do all calculations with topLeftX_FixedPoint to get a resolution of 1/64 pixel in calcuatuions,
// we devide at the end by FIXED_POINT_MULTIPLIER which must be 2^n, to return to the initial proportions
// movement limits 
const int   OBJECT_WIDTH_X = 64; //TODO:change according to graphics
const int   OBJECT_HIGHT_Y = 64; //TODO:change according to graphics
const int	SafetyMargin   =	2;
const int	x_FRAME_LEFT	=	SafetyMargin; 
const int	x_FRAME_RIGHT	=	639 - SafetyMargin - OBJECT_WIDTH_X; 
const int	y_FRAME_TOP		=	SafetyMargin;
const int	y_FRAME_BOTTOM	=	479 -SafetyMargin - OBJECT_HIGHT_Y; //- OBJECT_HIGHT_Y

//edges 
	//------------
	//			 434
	//			 1x2
	//			 404
	//

const logic [4:0] CORNER =	5'b10000; 
const logic [3:0] TOP =		 4'b1000; 
const logic [3:0] RIGHT =   4'b0100; 
const logic [3:0] LEFT =	 4'b0010; 
const logic [3:0] BOTTOM =  4'b0001; 





//--------------
//Angle trigonometric lookup table
//provide transformation LUT_trigfunc[state_index]=64*trigfunc(15*state_index)
/*TODO check if degrees look good on screen*/
const int ANGLE_RESOLUTION = 12; //change according to delta theta using formula res=180/delta theta
localparam signed [7:0] LUT_cos [0:ANGLE_RESOLUTION] = '{
    8'sd64,  // Index 0:  0 degrees
    8'sd62,  // Index 1:  15 degrees
    8'sd55,  // Index 2:  30 degrees
    8'sd45,  // Index 3:  45 degrees
    8'sd32,  // Index 4:  60 degrees
    8'sd17,  // Index 5:  75 degrees
    8'sd0,   // Index 6:  90 degrees
   -8'sd17,  // Index 7:  105 degrees
   -8'sd32,  // Index 8:  120 degrees
   -8'sd45,  // Index 9:  135 degrees
   -8'sd55,  // Index 10: 150 degrees
   -8'sd62,  // Index 11: 165 degrees
   -8'sd64   // Index 12: 180 degrees
};

localparam signed [7:0] LUT_sin [0:ANGLE_RESOLUTION] = '{
    8'sd0,  // Index 0:  0 degrees
    8'sd17,  // Index 1:  15 degrees
    8'sd32,  // Index 2:  30 degrees
    8'sd45,  // Index 3:  45 degrees
    8'sd55,  // Index 4:  60 degrees
    8'sd62,  // Index 5:  75 degrees
    8'sd64,   // Index 6:  90 degrees
	 8'sd62,  // Index 7:  105 degrees
    8'sd55,  // Index 8:  120 degrees
    8'sd45,  // Index 9:  135 degrees
    8'sd32,  // Index 10: 150 degrees
    8'sd17,  // Index 11: 165 degrees
    8'sd0   // Index 12: 180 degrees
};

//--------------
localparam signed [10:0] MIN_R = 11'sd40; //TODO:to be changed when implementing graphics
localparam signed [2:0] DELTA_R = 3'sd5 ; //TODO:to be changed to LUT when implementing treasures mass



enum  logic [2:0] {S_SWING,         	//  swing from side to side change theta
						 S_SHOOT, 				// lengthen hook increase R and handle colision
						 S_RETRACT	          // retract hiok decrease R and no colision
						}  SM_Motion ;


logic toggle_x_key_D ;


 logic [4:0] hit_reg = 5'b00000;
  
//place tracking
logic [3:0] state_index;
logic swing_dir;
logic next_swing_dir;
logic signed [MAX_RADIUS_BITS:0] R;
 //---------

 //calculate swing edge cases unsynchronically
always_comb begin
	next_swing_dir = swing_dir;
	if ((state_index == 4'd12) && swing_dir)//right end and swings right 
        next_swing_dir = 1'b0;
   else if ((state_index == 4'd0) && ~swing_dir) //left end and swings left
        next_swing_dir = 1'b1;
 end
	
always_ff @(posedge clk or negedge resetN)
begin : fsm_sync_proc

	if (resetN == 1'b0) begin 
		SM_Motion <= S_SWING ; 
		state_index <= 4'd6  ; 
		R <= MIN_R;
		swing_dir <= 1'b0;
		hit_reg <= 5'b0 ;	
	
	end 	
	
	else begin
	
		case(SM_Motion)
		
		//------------
			S_SWING: begin //swing back and forth between 0 and 180 degrees
		//------------
			swing_dir <= next_swing_dir; //update direction
			state_index <= next_swing_dir ? (state_index + 1'b1) : (state_index - 1'b1);//implement movment in direciton
			if (shoot_key)
				SM_Motion <= S_SHOOT;
			
			end
	
		//------------
			S_SHOOT:  begin     // lengthen hook and check collisions
		//------------
			R <= R+DELTA_R;
			if ((Xend >= x_FRAME_RIGHT) || (Xend <= x_FRAME_LEFT)  || //check collision with boundries
			(Yend >= y_FRAME_BOTTOM)) begin
				SM_motion <= S_RETRACT;
			end
					
		 /*TODO handle collision with treasure */			
				
		end 
		
		//------------
			S_RETRACT:  begin      //shorten hook back and handle treasures mass
		//------------
			/*TODO change DELTA_R according to LUT*/
			R <= R-DELTA_R;
			if(R<=MIN_R)
				SM_motion <= S_SWING;
		end 

		endcase  // case 

		
	end 

end // end fsm_sync


//calculate asynchronically the end coordinites to be provided to graphic module
  
assign 	Xend = x0+((R*LUT_cos[state_index])>>>6) ;  // calculate x coordinate and normalise by 64 because of LUT
assign 	Yend = y0+((R*LUT_sin[state_index])>>>6) ;  // calculate y coordinate and normalise by 64 because of LUT  
	

endmodule	
//---------------
 
