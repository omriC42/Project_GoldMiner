// game controller dudy Febriary 2020
// (c) Technion IIT, Department of Electrical Engineering 2021
//updated --Eyal Lev 2021
// Sep 2026: the number box was removed, so its collision input was removed too.

module	game_controller	(
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,  // short pulse every start of frame
			input	logic	drawing_request_smiley,
			input	logic	drawing_request_boarders,

			output logic collision,      // active in case of collision between two objects
			output logic SingleHitPulse  // a single pulse per frame when a collision happens
);

logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions

assign collision = (drawing_request_smiley && drawing_request_boarders);

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

		if ( collision && (flag == 1'b0)) begin
			flag    <= 1'b1; // to enter only once
			SingleHitPulse <= 1'b1 ;
		end
	end
end

endmodule
