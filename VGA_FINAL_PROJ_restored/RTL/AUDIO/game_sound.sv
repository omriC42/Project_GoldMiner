// game_sound - turns game events into "play sound N" for melody_player_1.


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
    input  logic       soundOn,         // settings: 1 = sounds on, 0 = silent
    output logic       startSound,      // 1-clock pulse -> melody_player_1.startMelodyPulse
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
        if (request != SND_NONE && soundOn) begin
            soundSelect <= 4'(request);
            startSound  <= 1'b1;
        end
    end
end

endmodule
