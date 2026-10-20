// game controller dudy Febriary 2020
// (c) Technion IIT, Department of Electrical Engineering 2021 
//updated --Eyal Lev 2021


module	game_controller	(	
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,  // short pulse every start of frame 30Hz 
			input	logic	drawing_request_miner,
			input	logic	drawing_request_boarders,

//---------------------#1-add input drawing request of number/box
		
			input logic numberDrawingRequest,
		

//---------------------#1-end input drawing request of number/box


// drawing_request_miner   -->  miner
// drawing_request_boarders -->  brackets
// drawing_request_number   -->  number/box 

//---------------------#2-add  drawing request of hart

		//	input	logic	drawing_request_hart,

//---------------------#2-end drawing request of hart		

			
			output logic collision, // active in case of collision between two objects
			
			output logic SingleHitPulse // critical code, generating A single pulse in a frame 
			
			

//---------------------#3-add collision  miner and hart   -------------------------------------

		//	output logic collision_Miner_Hart // active in case of collision between Miner and hart

//---------------------#3-end collision  miner and hart	--------------------------------------
			
);

logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions 
logic collision_miner_number; // collision between Miner and number - is not output

//assign collision = (drawing_request_miner && drawing_request_boarders);// any collision --> comment after updating with #4 or #5 

//---------------------#4-update  collision  conditions - add collision between miner and number   ----------------------------


assign collision = (drawing_request_miner && drawing_request_boarders) || collision_miner_number; // any collision
assign collision_miner_number = drawing_request_miner && numberDrawingRequest;

//---------------------#4-end update  collision  conditions - add collision between miner and number	-------------------------
	
					

//---------------------#5-update  collision  conditions - add collision between miner and hart  ---------------------------------

//assign collision = <collision_before> +( drawing_request_miner && drawing_request_hart ); 

//---------------------#5-end update  collision  conditions	- add collision between miner and hart	-----------------------------
	

//-------------------------- #6-add colision between Miner and hart-----------------

//assign collision_Miner_Hart = ( drawing_request_miner && drawing_request_hart ) ;

//---------------------------#6-end colision betweenand Miner and hart-----------------



always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN)
	begin 
		flag	<= 1'b0;
		SingleHitPulse <= 1'b0; 
		
	end 
	else begin 
	
			SingleHitPulse <= 1'b0 ; // default 
			if(startOfFrame) 
				flag <= 1'b0 ; // reset for next time 
				
//	----#7 - change the collision condition below to collision_miner_number ---------

if ( collision_miner_number  && (flag == 1'b0)) begin 
            flag    <= 1'b1; // to enter only once 
            SingleHitPulse <= 1'b1 ; 
        end ;
 
	end 
end

endmodule
