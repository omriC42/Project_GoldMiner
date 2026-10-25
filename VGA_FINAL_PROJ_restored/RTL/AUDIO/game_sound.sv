// game_sound - turns game events into "play sound N" for melody_player_1 (Step 11, Oct 2026).
//
//   event (TOP_VGA_DEMO_KBD net)                    sound (game_params::sound_t)
//   objectCollected  (gold field: object taken)     SND_CATCH     "clunk"
//   deliverPulse     (hook_block: object at top)    SND_MONEY     "cha-ching"
//   newLevel         (game_hud: level won / + key)  SND_LEVEL     fanfare
//   gameOver         (game_hud, 0 -> 1 only)        SND_GAMEOVER  sad tune
//
//  * The NEWEST event always wins: it restarts the player with its own sound, cutting whatever
//    was playing (decided with the user). If two events come on the SAME clock (rare), the more
//    important one is taken: game over > level > money > catch.
//  * soundSelect is held until the next event, because the jukebox reads it during the whole
//    sound. startSound is a 1-clock pulse, on the same clock as the new soundSelect.
//  * Each sound can be switched off in game_params.sv (SOUND_*_ON); an off event does nothing.
//  * resetN = gameResetN: silent on the opening screen.

module game_sound #(
    // on/off per sound: the game uses game_params.sv; a testbench may override them
    parameter bit CATCH_ON    = game_params::SOUND_CATCH_ON,
    parameter bit MONEY_ON    = game_params::SOUND_MONEY_ON,
    parameter bit LEVEL_ON    = game_params::SOUND_LEVEL_ON,
    parameter bit GAMEOVER_ON = game_params::SOUND_GAMEOVER_ON
) (
    input  logic       clk,
    input  logic       resetN,          // gameResetN
    input  logic       catchPulse,      // objectCollected (1 clock)
    input  logic       moneyPulse,      // deliverPulse    (1 clock)
    input  logic       newLevel,        // newLevel        (1 clock)
    input  logic       gameOver,        // gameOver        (level: 1 from game over until reset)
    output logic       startSound,      // 1-clock pulse -> melody_player_1.startMelodyKey
    output logic [3:0] soundSelect      // which sound   -> melody_player_1.melodySelect
);
import game_params::*;

// game over: only the moment it starts (0 -> 1)
logic gameOver_d;
logic gameOverStart;
assign gameOverStart = gameOver && !gameOver_d;

// which sound this clock asks for (switched-off sounds never ask)
sound_t request;
always_comb begin
    if      (gameOverStart && GAMEOVER_ON) request = SND_GAMEOVER;
    else if (newLevel      && LEVEL_ON)    request = SND_LEVEL;
    else if (moneyPulse    && MONEY_ON)    request = SND_MONEY;
    else if (catchPulse    && CATCH_ON)    request = SND_CATCH;
    else                                         request = SND_NONE;
end

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        gameOver_d  <= 1'b0;
        startSound  <= 1'b0;
        soundSelect <= 4'(SND_NONE);
    end
    else begin
        gameOver_d <= gameOver;
        startSound <= 1'b0;
        if (request != SND_NONE) begin
            soundSelect <= 4'(request);
            startSound  <= 1'b1;
        end
    end
end

endmodule
