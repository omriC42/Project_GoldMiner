module MazeBitMapMask (
    input  logic clk,
    input  logic resetN,
    input  logic [10:0] offsetX,
    input  logic [10:0] offsetY,
    input  logic collision_detected, // פולס מהבקר למחיקת אובייקט
    
    output logic drawingRequest,
    output logic [7:0] RGBout
);

// 1. הגדרת המערך (10 עמודות על 6 שורות = 640/64, 384/64)
logic [2:0] MazeBitMapMask [0:9][0:5];
logic [31:0] rand_counter;

// קואורדינטות מנוורמלות לאזור המשחק
logic [10:0] normalized_Y;
logic [4:0] cell_x;
logic [4:0] cell_y;

assign normalized_Y = (offsetY >= 96) ? (offsetY - 96) : 0;
assign cell_x = offsetX[10:6];
assign cell_y = normalized_Y[10:6];

// מונה לאקראיות ראשונית
always_ff @(posedge clk) rand_counter <= rand_counter + 1;

// 2. לוגיקת אתחול ומחיקה
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        // אתחול אקראי פשוט לטבלה (כאן אפשר להרחיב ללוגיקה מורכבת יותר)
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 6; j++) begin
                MazeBitMapMask[i][j] <= (rand_counter[i+j] ^ i) % 7; // ערכים 0-6
            end
        end
    end else if (collision_detected && (offsetY >= 96)) begin
        // מחיקת עצם מהגריד בעת פגיעה
        MazeBitMapMask[cell_x][cell_y] <= 3'd0;
    end
end

// 3. לוגיקת ציור
always_ff @(posedge clk) begin
    if (offsetY < 96) begin
        drawingRequest <= 1'b0;
        RGBout <= 8'h00;
    end else begin
        automatic logic [2:0] obj = MazeBitMapMask[cell_x][cell_y];
        
        // כאן מממשים את הציור לפי ה-obj שנשלף
        case (obj)
            3'd0: begin // ריק
                drawingRequest <= 1'b0;
                RGBout <= 8'h00;
            end
            3'd1, 3'd2, 3'd3: begin // זהב
                drawingRequest <= 1'b1;
                RGBout <= 8'hFC; // צבע זהב לדוגמה
            end
            3'd4, 3'd5, 3'd6: begin // אבנים
                drawingRequest <= 1'b1;
                RGBout <= 8'h49; // צבע אבן לדוגמה
            end
            default: begin
                drawingRequest <= 1'b0;
                RGBout <= 8'h00;
            end
        endcase
    end
end

endmodule