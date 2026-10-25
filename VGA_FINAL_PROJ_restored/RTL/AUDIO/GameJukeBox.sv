// GameJukeBox - the "sheet music" of the Gold Miner game sounds (Step 11, Oct 2026).
// Same idea and format as the course JukeBox1: for the selected sound and the current note
// number (noteIndex) it gives the note's pitch (tone -> ToneDecoder in AUDIO.bdf) and its length
// in beats. A length of 0 = end of the sound. NEW here: each sound also has its own tempo
// (beatCs = one beat in 1/100 s, from game_params.sv), so short effects can be faster.
//
// Pitches: one octave from do (~1043 Hz) to si, then DO, DO#, RE of the next octave (ToneDecoder).
// To change a sound: edit its lines below (pitch, beats), recompile. Previews were made as .wav
// files at these exact pitches and lengths before the hardware was written.
//
//   sound      notes (pitch x beats)                                tempo   length
//   catch      sol x2, do x3                                        fast    ~0.23 s
//   money      do x1, mi x1, sol x1, DO x4                          fast    ~0.37 s
//   level won  do x2, mi x2, sol x2, DO x2, (rest x1), sol x2, DO x6  slow    ~1.3 s
//   game over  sol x4, fa# x4, fa x4, mi x10                        slow    ~1.5 s

module GameJukeBox (
    input  logic [3:0] melodySelect,   // game_params::sound_t (from game_sound, via melody_player_1)
    input  logic [4:0] noteIndex,      // which note of the sound (0, 1, 2 ...)
    output logic [3:0] tone,           // pitch index -> ToneDecoder
    output logic [3:0] note_length,    // length in beats, 0 = end of the sound
    output logic [5:0] beatCs,         // one beat of THIS sound, in 1/100 s
    output logic       silenceOutN     // 0 = this note is a rest (no sound)
);
import game_params::*;

// note names (the same numbers as JukeBox1 / ToneDecoder)
typedef enum logic [3:0] {do_, doD, re, reD, mi, fa, faD, sol, solD, la, laD, si, do_H, doDH, re_H, silence} musicNote;

localparam int MAX_NOTES = 8;          // longest game sound (level won = 7 notes + end mark)

musicNote   frq [0:MAX_NOTES-1];
logic [3:0] len [0:MAX_NOTES-1];

always_comb begin
    frq    = '{default: do_};
    len    = '{default: 4'd0};         // length 0 everywhere = "end" unless written below
    beatCs = 6'(SOUND_BEAT_SLOW_CS);
    case (sound_t'(melodySelect))
        SND_CATCH: begin                                   // hook shot sound
            beatCs = 6'(SOUND_BEAT_FAST_CS);
            frq[0] = sol;   len[0] = 4'd2;
            frq[1] = do_;   len[1] = 4'd3;
        end
        SND_MONEY: begin                                   // object acquired sound
            beatCs = 6'(SOUND_BEAT_FAST_CS);
            frq[0] = do_;   len[0] = 4'd1;
            frq[1] = mi;    len[1] = 4'd1;
            frq[2] = sol;   len[2] = 4'd1;
            frq[3] = do_H;  len[3] = 4'd4;
        end
        SND_LEVEL: begin                                   // win sound
            beatCs = 6'(SOUND_BEAT_SLOW_CS);
            frq[0] = do_;     len[0] = 4'd2;
            frq[1] = mi;      len[1] = 4'd2;
            frq[2] = sol;     len[2] = 4'd2;
            frq[3] = do_H;    len[3] = 4'd2;
            frq[4] = silence; len[4] = 4'd1;
            frq[5] = sol;     len[5] = 4'd2;
            frq[6] = do_H;    len[6] = 4'd6;
        end
        SND_GAMEOVER: begin                                // lose sound
            beatCs = 6'(SOUND_BEAT_SLOW_CS);
            frq[0] = sol;   len[0] = 4'd4;
            frq[1] = faD;   len[1] = 4'd4;
            frq[2] = fa;    len[2] = 4'd4;
            frq[3] = mi;    len[3] = 4'd10;
        end
        default: ;                                         // SND_NONE: nothing (length 0 = end)
    endcase
end

// the current note (beyond the table = end of the sound)
always_comb begin
    if (noteIndex < 5'(MAX_NOTES)) begin
        tone        = frq[noteIndex[2:0]];
        note_length = len[noteIndex[2:0]];
    end
    else begin
        tone        = do_;
        note_length = 4'd0;
    end
end
assign silenceOutN = (tone != silence);

endmodule
