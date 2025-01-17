//------------------------------------------------------//
//- Digital IC Design 2023                              //
//-                                                     //
//- Final Project: FP_MUL                               //
//------------------------------------------------------//
`timescale 1ns/10ps

module FP_MUL(CLK, RESET, ENABLE, DATA_IN, DATA_OUT, READY);
// I/O Ports
input         CLK;        //clock signal
input         RESET;      //sync. RESET=1
input         ENABLE;     //input data sequence when ENABLE =1
input   [7:0] DATA_IN;    //input data sequence
output  [7:0] DATA_OUT;   //ouput data sequence
output        READY;      //output data is READY when READY=1

integer       i;

reg [7:0]  DATA_OUT;
reg [2:0]  state, n_state;
reg [4:0]  counter_read;
reg [4:0]  counter_eval;
reg        counter_nor, special_case, counter_sp;
reg [3:0]  counter_out;
reg [7:0]  input_A  [0:7];
reg [7:0]  input_B  [0:7];
reg [55:0] vedic    [0:4];
reg [55:0] pip_reg  [0:1];
reg [1:0]  cin      [0:1];

reg         sign;
wire [10:0] exponent_A, exponent_B;
reg  [11:0] exponent;
reg  [111:0] mantissa_mul [0:1];
reg  [55:0]  mantissa_A, mantissa_B;

parameter INIT = 3'd0, READ_DATA = 3'd1, SPECIAL = 3'd2, EVAL = 3'd3, NORMAL = 3'd4, OUTPUT = 3'd5;

assign READY = (state == OUTPUT) && counter_out > 0;

assign exponent_A = {input_A[7][6:0], input_A[6][7:4]};
assign exponent_B = {input_B[7][6:0], input_B[6][7:4]};

always @(*) begin
    case(state)
        INIT:        n_state = ENABLE ? READ_DATA : INIT;
        READ_DATA:   n_state = counter_read == 5'd16 ? SPECIAL : READ_DATA;
        SPECIAL:     n_state = counter_sp ? (special_case ? OUTPUT : EVAL) : SPECIAL;
        EVAL:        n_state = counter_eval == 5'd12 ? NORMAL : EVAL;
        NORMAL:      n_state = counter_nor == 1'b1 ? OUTPUT : NORMAL;
        OUTPUT:      n_state = counter_out == 4'd7 ? INIT : OUTPUT;
    endcase
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        state <= INIT;
    end 
    else begin
        state <= n_state;
    end
end

// counter_read[4:0]
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        counter_read <= 5'd0;
    end 
    else if (ENABLE || state == READ_DATA) begin
        if (counter_read < 5'd16) begin
            counter_read <= counter_read + 1'b1;
        end
    end 
    else if (state == OUTPUT) begin
        counter_read <= 5'd0;
    end
end

// special_case
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        counter_sp <= 1'b0;
    end 
    else if (state == INIT) begin
        counter_sp <= 1'b0;
    end 
    else if (state == SPECIAL) begin
        if (counter_sp == 0) begin
            counter_sp <= 1'b1;
        end
    end
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        special_case <= 1'b0;
    end 
    else if (state == INIT) begin
        special_case <= 1'b0;
    end 
    else if (state == SPECIAL) begin
        if (exponent_A == 11'd2047 || exponent_B == 11'd2047) begin
            special_case <= 1'b1;
        end 
        else if ({exponent_A, mantissa_A[51:0]} == 63'd0 || {exponent_B, mantissa_B[51:0]} == 63'd0) begin
            special_case <= 1'b1;
        end
    end
end

// counter_eval[4:0]
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        counter_eval <= 5'd0;
    end 
    else if (state == INIT) begin
        counter_eval <= 5'd0;
    end 
    else if (state == EVAL) begin
        if (counter_eval < 5'd12) begin
            counter_eval <= counter_eval + 1'b1;
        end
    end
end

// counter_nor
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        counter_nor <= 1'b0;
    end 
    else if (state == INIT) begin
        counter_nor <= 1'b0;
    end 
    else if (state == NORMAL) begin
        if (counter_nor == 0) begin
            counter_nor <= 1'b1;
        end
    end
end

// counter_out[3:0]
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        counter_out <= 4'd0;
    end 
    else if (state == INIT) begin
        counter_out <= 4'd0;
    end 
    else if (state == OUTPUT) begin
        if (counter_out < 4'd7) begin
            counter_out <= counter_out + 1'b1;
        end
    end
end

// sign
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        sign <= 1'b0;
    end 
    else if (state == INIT) begin
        sign <= 1'b0;
    end 
    else if (state == SPECIAL) begin
        if (exponent_A == 11'd2047 && mantissa_A[51:0] != 52'd0) begin // A == NaN -> Ans = A Ans[51] = 1m pri:A>B
            sign <= input_A[7][7];
        end 
        else if (exponent_B == 11'd2047 && mantissa_B[51:0] != 52'd0) begin // B == NaN -> Ans = B Ans[51] = 1
            sign <= input_B[7][7];
        end 
        else if (exponent_A == 11'd2047 && mantissa_A[51:0] == 52'd0) begin // A == INF
            if (exponent_B == 11'd0 && mantissa_B[51:0] == 52'd0) begin // A == INF && B == 0 -> Ans = NaN
                sign <= 1;
            end 
            else begin
                sign <= input_A[7][7] ^ input_B[7][7];
            end
        end 
        else if (exponent_B == 11'd2047 && mantissa_B[51:0] == 52'd0) begin // B == INF
            if (exponent_A == 11'd0 && mantissa_A[51:0] == 52'd0) begin // A == 0 && B == INF -> Ans = NaN
                sign <= 1;
            end 
            else begin
                sign <= input_A[7][7] ^ input_B[7][7];
            end
        end 
        else begin
            sign <= input_A[7][7] ^ input_B[7][7];
        end
    end 
    else if (state == EVAL) begin
        if (counter_eval == 5'd0) begin
            sign <= input_A[7][7] ^ input_B[7][7];
        end
    end
end

// exponent[11:0] 11+1
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        exponent <= 12'd0;
    end 
    else if (state == INIT) begin
        exponent <= 12'd0;
    end 
    else if (state == SPECIAL) begin
        if (exponent_A == 11'd2047 || exponent_B == 11'd2047) begin
            exponent <= 12'd2047;
        end
    end 
    else if (state == EVAL) begin
        if (counter_eval == 5'd0) begin
            exponent <= exponent_A + exponent_B - 12'd1023;
        end
    end 
    else if (state == NORMAL) begin
        if (counter_nor == 1'b0) begin
            exponent <= mantissa_mul[0][105] ? exponent + 1 : exponent;
        end
    end
end

// mantissa_mul
always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        mantissa_mul[0] <= 112'd0;
        mantissa_mul[1] <= 112'd0;
    end 
    else if (state == INIT) begin
        mantissa_mul[0] <= 112'd0;
        mantissa_mul[1] <= 112'd0;
    end 
    else if (state == SPECIAL) begin
        if (exponent_A == 11'd2047 && mantissa_A[51:0] != 52'd0) begin // A == NaN -> Ans = A Ans[51] = 1m pri:A>B
            mantissa_mul[0] <= {7'd1, mantissa_A[50:0], 54'd0};
        end 
        else if (exponent_B == 11'd2047 && mantissa_B[51:0] != 52'd0) begin // B == NaN -> Ans = B Ans[51] = 1
            mantissa_mul[0] <= {7'd1, mantissa_B[50:0], 54'd0};
        end 
        else if (exponent_A == 11'd2047 && mantissa_A[51:0] == 52'd0) begin // A == INF
            if (exponent_B == 11'd0 && mantissa_B[51:0] == 52'd0) begin // A == INF && B == 0 -> Ans = NaN
                mantissa_mul[0] <= {7'd1, mantissa_A[50:0], 54'd0};
            end
        end 
        else if (exponent_B == 11'd2047 && mantissa_B[51:0] == 52'd0) begin // B == INF
            if (exponent_A == 11'd0 && mantissa_A[51:0] == 52'd0) begin // A == 0 && B == INF -> Ans = NaN
                mantissa_mul[0] <= {7'd1, mantissa_B[50:0], 54'd0};
            end
        end
    end 
    else if (state == EVAL) begin
        if (counter_eval == 5'd1) begin
            mantissa_mul[0][13:0]  <= vedic[0][13:0];
            mantissa_mul[0][69:56] <= vedic[0][41:28];
        end 
        else if (counter_eval == 5'd3) begin
            mantissa_mul[0][27:14] <= pip_reg[1][13:0];
            mantissa_mul[0][55:28] <= vedic[3][27:0] + {13'd0, cin[0][0] | cin[0][1], pip_reg[1][27:14]};
            mantissa_mul[0][83:70] <= pip_reg[1][41:28];
            mantissa_mul[0][111:84] <= vedic[3][55:28] + {13'd0, cin[1][0] | cin[1][1], pip_reg[1][55:42]};
        end 
        else if (counter_eval == 5'd5) begin
            mantissa_mul[1][13:0]  <= vedic[0][13:0];
            mantissa_mul[1][69:56] <= vedic[0][41:28];
        end 
        else if (counter_eval == 5'd7) begin
            mantissa_mul[1][27:14] <= pip_reg[1][13:0];
            mantissa_mul[1][55:28] <= vedic[3][27:0] + {13'd0, cin[0][0] | cin[0][1], pip_reg[1][27:14]};
            mantissa_mul[1][83:70] <= pip_reg[1][41:28];
            mantissa_mul[1][111:84] <= vedic[3][55:28] + {13'd0, cin[1][0] | cin[1][1], pip_reg[1][55:42]};
        end 
        else if (counter_eval == 5'd9) begin
            mantissa_mul[0][27:0] <= vedic[0][27:0];
        end 
        else if (counter_eval == 5'd11) begin
            mantissa_mul[0][55:28] <= pip_reg[1][27:0];
            mantissa_mul[0][111:56] <= vedic[3] + {27'd0, cin[0][0] | cin[0][1], pip_reg[1][55:28]};
        end
    end 
    else if (state == NORMAL) begin
        if (counter_nor == 1'b0) begin //normalization
            mantissa_mul[0] <= mantissa_mul[0][105] ? (mantissa_mul[0] << 1) : (mantissa_mul[0] << 2);
        end 
        else if (counter_nor == 1'b1) begin //rounding
            if (mantissa_mul[0][53]) begin
                mantissa_mul[0][105:54] <= mantissa_mul[0][105:54] + 1'b1;
            end
        end
    end
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        for (i = 0; i < 4; i = i + 1) begin
            vedic[i] <= 56'd0;
        end
    end 
    else if (state == EVAL) begin
        if (counter_eval == 5'd0) begin
            vedic[0][27:0] <= mantissa_A[13:0] * mantissa_B[13:0];
            vedic[1][27:0] <= mantissa_A[13:0] * mantissa_B[27:14];
            vedic[2][27:0] <= mantissa_A[27:14] * mantissa_B[13:0];
            vedic[3][27:0] <= mantissa_A[27:14] * mantissa_B[27:14];
            vedic[0][55:28] <= mantissa_A[13:0] * mantissa_B[41:28];
            vedic[1][55:28] <= mantissa_A[13:0] * mantissa_B[55:42];
            vedic[2][55:28] <= mantissa_A[27:14] * mantissa_B[41:28];
            vedic[3][55:28] <= mantissa_A[27:14] * mantissa_B[55:42];
        end 
        else if (counter_eval == 5'd4) begin
            vedic[0][27:0] <= mantissa_A[41:28] * mantissa_B[13:0];
            vedic[1][27:0] <= mantissa_A[41:28] * mantissa_B[27:14];
            vedic[2][27:0] <= mantissa_A[55:42] * mantissa_B[13:0];
            vedic[3][27:0] <= mantissa_A[55:42] * mantissa_B[27:14];
            vedic[0][55:28] <= mantissa_A[41:28] * mantissa_B[41:28];
            vedic[1][55:28] <= mantissa_A[41:28] * mantissa_B[55:42];
            vedic[2][55:28] <= mantissa_A[55:42] * mantissa_B[41:28];
            vedic[3][55:28] <= mantissa_A[55:42] * mantissa_B[55:42];
        end 
        else if (counter_eval == 5'd8) begin
            vedic[0] <= mantissa_mul[0][55:0];
            vedic[1] <= mantissa_mul[0][111:56];
            vedic[2] <= mantissa_mul[1][55:0];
            vedic[3] <= mantissa_mul[1][111:56];
        end
    end
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        pip_reg[0] <= 56'd0;
        pip_reg[1] <= 56'd0;
    end 
    else if (state == EVAL) begin
        if (counter_eval == 5'd1 || counter_eval == 5'd5) begin
            {cin[0][0], pip_reg[0][27:0]}  <= vedic[1][27:0] + vedic[2][27:0];
            {cin[1][0], pip_reg[0][55:28]} <= vedic[1][55:28] + vedic[2][55:28];
        end 
        else if (counter_eval == 5'd2 || counter_eval == 5'd6) begin
            {cin[0][1], pip_reg[1][27:0]}  <= vedic[0][27:14] + pip_reg[0][27:0];
            {cin[1][1], pip_reg[1][55:28]} <= vedic[0][55:42] + pip_reg[0][55:28];
        end 
        else if (counter_eval == 5'd9) begin
            {cin[0][0], pip_reg[0]} <= vedic[1] + vedic[2];
        end 
        else if (counter_eval == 5'd10) begin
            {cin[0][1], pip_reg[1]} <= vedic[0][55:28] + pip_reg[0];
        end
    end
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        for (i = 0; i < 8; i = i + 1) begin
            input_A[i] <= 0;
        end
        for (i = 0; i < 8; i = i + 1) begin
            input_B[i] <= 0;
        end
    end 
    else if (ENABLE) begin
        if (counter_read < 5'd8) begin
            input_A[counter_read] <= DATA_IN;
        end 
        else if (counter_read < 5'd16) begin
            input_B[counter_read - 8] <= DATA_IN;
        end
    end
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        mantissa_A <= 56'd0;
        mantissa_B <= 56'd0;
    end 
    else if (state == INIT) begin
        mantissa_A <= 56'd0;
        mantissa_B <= 56'd0;
    end 
    else if (state == READ_DATA) begin
        if (counter_read == 5'd16) begin
            mantissa_A <= {4'd1, input_A[6][3:0], input_A[5], input_A[4], input_A[3], input_A[2], input_A[1], input_A[0]};
            mantissa_B <= {4'd1, input_B[6][3:0], input_B[5], input_B[4], input_B[3], input_B[2], input_B[1], input_B[0]};
        end
    end
end

always @(posedge CLK or posedge RESET) begin
    if (RESET) begin
        DATA_OUT <= 8'd0;
    end 
    else if (state == OUTPUT) begin
        case (counter_out)
            4'd0: DATA_OUT <= mantissa_mul[0][61:54];
            4'd1: DATA_OUT <= mantissa_mul[0][69:62];
            4'd2: DATA_OUT <= mantissa_mul[0][77:70];
            4'd3: DATA_OUT <= mantissa_mul[0][85:78];
            4'd4: DATA_OUT <= mantissa_mul[0][93:86];
            4'd5: DATA_OUT <= mantissa_mul[0][101:94];
            4'd6: DATA_OUT <= {exponent[3:0], mantissa_mul[0][105:102]};
            4'd7: DATA_OUT <= {sign, exponent[10:4]};
        endcase
    end
end

endmodule
