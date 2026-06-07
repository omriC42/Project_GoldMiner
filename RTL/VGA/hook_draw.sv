module	hook_draw	(						
					input	 logic signed 	[10:0] X0, //center point of character
					//y0 is constant
					
					input logic signed 	[10:0] Xend, //end point defined by hook_move module
					input logic signed	[10:0] Yend, 
					input logic signed	[10:0] R_pixel,   //derived from move module to calculate rope thickness
					
					input logic signed 	[10:0] x, //current pixel to be drawn
					input logic signed	[10:0] y, 
					
					
					output logic drawingRequest
					
);
localparam signed [10:0] Y0 = 11'sd10; //to be changed to correct number
localparam logic [2:0] thickness_exp = 3'd1; //represents thickness value using powers of 2
logic signed [20:0] line_func;
logic signed [10:0] thickness;
logic in_thickness_bounds;
logic in_x_bounds;
logic in_y_bounds;


assign thickness = R_pixel << thickness_exp;
assign line_func = (y-Y0)*(Xend-X0)- (x-X0)*(Yend-Y0);
assign in_thickness_bounds = (line_func >= -thickness) && (line_func <= thickness);
assign in_x_bounds = (x >= X0 && x <= Xend) || (x <= X0 && x >= Xend);
assign in_y_bounds = (y >= Y0 && y <= Yend);
assign drawingRequest = (in_thickness_bounds) && (in_x_bounds) && (in_y_bounds);

endmodule	
