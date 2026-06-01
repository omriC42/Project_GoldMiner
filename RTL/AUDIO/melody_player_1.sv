//
// (c) Technion IIT, The Faculty of Electrical and Computer Engineering, 2025
//
//  PRELIMINARY VERSION  -  23 March 2025
//

module melody_player_1

    (
    // Declare wires and regs :
 input logic resetN ,
 input logic CLOCK_31p5 ,
 input logic startMelodyKey ,
 input logic [3:0] melodySelect ,     // selector of one melody  
      // from Jukebox: silence signal
 
  output logic [3:0] tone,
  output logic EnableSoundOut,// controls AUDIO module on/off 
  output logic melodyEnded        // indicates end of melody.  Also outputs to LED3      
  
  );   // serial number of current note. ( maximum 31 ). noteIndex determines freqIndex and note_length, via JueBox
 
 localparam logic [5:0] beat_duration = 6'd12 ;   // duration of each beat,     in 1/100 seconds.  max 63 (= 0.63 sec)
 localparam logic [4:0] gap_duration = 5'd3 ;     // duration of inter-note gap,  in 1/100 seconds  .  max 31 (= 0.31 sec)
  
 // Maestro state machine declaration 
 enum logic [1:0] {s_idle, s_playNote, s_gap, s_ended} SM_Maestro; // state machine

  // parameters declarations
	logic [9:0] noteTimeCounter; // count down 1/100 seconds timer ( maximum 1024 )
   logic [9:0] noteDuration;    // total length of current note in 1/100 seconds  (max 1024)  =  beat_duration * note_length  	
   logic hundredthSecPulse; // A short pulse, once every 1/100 second. 

// Juke box interface signals 	
	logic [3:0] note_length;    // length of notes, in beats. determined by noteIndex via JukeBox 
   logic silenceN;        
	logic [4:0] noteIndex;
	
   assign noteDuration = beat_duration * note_length ;       // total duration of current note, in 1/100 seconds  
			
  //----------------------------------------------------------------------------------------------------------
  // Instances of slow counter.  pulse every 10 mSec
  //----------------------------------------------------------------------------------------------------------									  									  								 
   Mili_sec_counter #(.SIMULATION_MODE(1'h0), .mSecPerTick(10), .PLLClock(315)) mili_sec_counter_inst 
	                     (.clk(CLOCK_31p5),   
								 .resetN(resetN),
								 .turbo(1'h0),   
								 .hundredth_sec(hundredthSecPulse) );
								 
  //----------------------------------------------------------------------------------------------------------
  // Instances of Music options 
  //----------------------------------------------------------------------------------------------------------									  									  								 
							 
	JukeBox1  JukeBox1 (.melodySelect(melodySelect), .noteIndex(noteIndex) , .tone(tone), .note_length(note_length) , .silenceOutN(silenceN) ) ;

  							 
//----------------------------------------------------------------------------------------------------------								 					 	 
//   syncronous code,  executed once every clock to update the current state and outputs 
//----------------------------------------------------------------------------------------------------------	
always_ff @(posedge CLOCK_31p5 or negedge resetN) // State machine logic 
   begin   
   if ( !resetN ) begin // Asynchronic reset, initialize the state machine 
		SM_Maestro <= s_idle;
   	noteIndex <= 5'b0 ;
		noteTimeCounter  <= noteDuration ;
		EnableSoundOut <= 1'b0 ;
		melodyEnded <= 1'b0 ;
				
	end // asynch
	else begin 				   // Synchronic logic of the state machine; once every clock 
//--------------------------------------------------------------------------------------------------------------------
	// state machine 
	
		// default outputs 
		EnableSoundOut <= 1'b0 ;
		melodyEnded <= 1'b0 ;
		
		case ( SM_Maestro )			
//                ================================================				
						s_idle: begin
                     noteIndex <= 5'b0;
                  
						   if (startMelodyKey)    // start melody pressed
						       begin
								    noteTimeCounter <= noteDuration ;// preset noteTimecounter
	                         SM_Maestro <= s_playNote ;	
								 end // if
						 end // s_idle	
//                ================================================				
						s_playNote: begin	
						         EnableSoundOut <= silenceN ; // enable sound, unless jukebox says "silence"    
						    if (!(note_length == 4'b0)) begin   // if did not reach the end of the song 
							     if ( hundredthSecPulse ) noteTimeCounter <= noteTimeCounter - 10'b1; // decremnt counter
								  if (noteTimeCounter == 10'b0) begin // timer finished  
										  noteIndex <= noteIndex + 1'b1 ;   // increment note Index 
										  SM_Maestro <= s_gap ;   // next state 
										  noteTimeCounter <= gap_duration ;// preset counter for gap 
								   end // if timer ended
							 end // if not end of song	  
							 else // reached end of song
							    SM_Maestro <= s_ended ;
						end // s_playNote
//                ================================================				
						s_gap : begin	
			            if ( hundredthSecPulse ) noteTimeCounter <= noteTimeCounter - 10'b1; // decremnt counter  
							if (noteTimeCounter == 10'b0)  // timer finished 
								begin 
 									SM_Maestro <= s_playNote ;   // back to playnote state    
				               noteTimeCounter <= noteDuration ;     // preset counter 
									end // if 
						end // s_gap
//                ================================================				
                  s_ended : begin
						      melodyEnded <= 1'b1 ;   
                        SM_Maestro <= s_idle ;  
						end //s_end
//						================================================				
                  default: begin
						   SM_Maestro <= s_idle ;
						end // default
	   endcase
	end // if reset else
end // always_ff state machine 
									  								  
endmodule

