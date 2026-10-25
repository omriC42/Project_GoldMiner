//
// (c) Technion IIT, The Faculty of Electrical and Computer Engineering, 2025
//
//  PRELIMINARY VERSION  -  23 March 2025
//
// Gold Miner changes (Step 11, Oct 2026) - marked "GM" below:
//  GM1 the sheet music comes from GameJukeBox (the 4 game sounds) instead of JukeBox1.
//  GM2 the beat length comes from the jukebox (each sound has its own tempo) and the gap after
//      every note from game_params.sv (SOUND_GAP_CS) - they were fixed localparams.
//  GM3 a start pulse ALWAYS restarts from the first note, even in the middle of a sound
//      ("the newest sound wins"). A one-clock s_load state reads the first note's length after
//      noteIndex went back to 0.
//  GM4 parameter SIMULATION_MODE (passed to Mili_sec_counter): 1 = a "1/100 s" tick every
//      21 clocks, so a testbench can play whole sounds quickly. The game uses 0 (real time).
//  GM5 no 1-clock sound blip on the end mark (length 0).

module melody_player_1
 #(parameter logic SIMULATION_MODE = 1'b0)    // GM4
    (
    // Declare wires and regs :
 input logic resetN ,
 input logic CLOCK_31p5 ,
 input logic startMelodyPulse ,         // 1-clock pulse: start (or restart) the selected sound
 input logic [3:0] melodySelect ,     // selector of one melody (game_params::sound_t)

  output logic [3:0] tone,
  output logic EnableSoundOut,// controls AUDIO module on/off
  output logic melodyEnded        // indicates end of melody.
  );

 import game_params::*;

 localparam logic [4:0] gap_duration = 5'(SOUND_GAP_CS);   // GM2: inter-note gap, 1/100 s (max 31)

 // Maestro state machine declaration
 enum logic [2:0] {s_idle, s_load, s_playNote, s_gap, s_ended} SM_Maestro; // GM3: + s_load

	logic [9:0] noteTimeCounter; // count down 1/100 seconds timer ( maximum 1023 )
   logic [9:0] noteDuration;    // total length of current note in 1/100 seconds = beat * note_length
   logic hundredthSecPulse; // A short pulse, once every 1/100 second.

// Juke box interface signals
	logic [3:0] note_length;    // length of notes, in beats. determined by noteIndex via the jukebox
	logic [5:0] beat_duration;  // GM2: one beat of the current sound, 1/100 s
   logic silenceN;
	logic [4:0] noteIndex;

   assign noteDuration = beat_duration * note_length ;       // total duration of current note, in 1/100 seconds

  //----------------------------------------------------------------------------------------------------------
  // Instances of slow counter.  pulse every 10 mSec
  //----------------------------------------------------------------------------------------------------------
   Mili_sec_counter #(.SIMULATION_MODE(SIMULATION_MODE), .mSecPerTick(10), .PLLClock(315)) mili_sec_counter_inst
	                     (.clk(CLOCK_31p5),
								 .resetN(resetN),
								 .turbo(1'h0),
								 .hundredth_sec(hundredthSecPulse) );

  //----------------------------------------------------------------------------------------------------------
  // GM1: the game sounds
  //----------------------------------------------------------------------------------------------------------
	GameJukeBox  jukebox (.melodySelect(melodySelect), .noteIndex(noteIndex), .tone(tone),
	                      .note_length(note_length), .beatCs(beat_duration), .silenceOutN(silenceN) ) ;

//----------------------------------------------------------------------------------------------------------
//   syncronous code,  executed once every clock to update the current state and outputs
//----------------------------------------------------------------------------------------------------------
always_ff @(posedge CLOCK_31p5 or negedge resetN) // State machine logic
   begin
   if ( !resetN ) begin // Asynchronic reset, initialize the state machine
		SM_Maestro <= s_idle;
   	noteIndex <= 5'b0 ;
		noteTimeCounter  <= 10'b0 ;
		EnableSoundOut <= 1'b0 ;
		melodyEnded <= 1'b0 ;
	end // asynch
	else begin 				   // Synchronic logic of the state machine; once every clock

		// default outputs
		EnableSoundOut <= 1'b0 ;
		melodyEnded <= 1'b0 ;

		if (startMelodyPulse) begin             // GM3: from ANY state - (re)start at the first note
			noteIndex  <= 5'b0;
			SM_Maestro <= s_load;
		end
		else begin
		case ( SM_Maestro )
//                ================================================
						s_idle: begin
                     noteIndex <= 5'b0;
						 end // s_idle
//                ================================================
						s_load: begin                  // GM3: noteIndex is 0 now -> its length is valid
								noteTimeCounter <= noteDuration ;
								SM_Maestro <= s_playNote ;
						 end // s_load
//                ================================================
						s_playNote: begin
						         EnableSoundOut <= silenceN && (note_length != 4'b0) ; // sound, unless a rest or the end mark (GM5)
						    if (!(note_length == 4'b0)) begin   // if did not reach the end of the song
							     if ( hundredthSecPulse ) noteTimeCounter <= noteTimeCounter - 10'b1; // decremnt counter
								  if (noteTimeCounter == 10'b0) begin // timer finished
										  noteIndex <= noteIndex + 1'b1 ;   // increment note Index
										  SM_Maestro <= s_gap ;   // next state
										  noteTimeCounter <= 10'(gap_duration) ;// preset counter for gap
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
		end // not start
	end // if reset else
end // always_ff state machine

endmodule
