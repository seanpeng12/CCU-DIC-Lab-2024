//------------------------------------------------------//
//- Digital IC Design 2024                              //
//-                                                     //
//- Final Project: FP_MUL                               //
//------------------------------------------------------//
`timescale 1ns/10ps

module FP_MUL(CLK, RESET, ENABLE, DATA_IN, DATA_OUT, READY);

input         CLK; //clock signal
input         RESET; //sync. RESET=1
input         ENABLE; //input data sequence when ENABLE =1
input  [7:0]  DATA_IN; //input data sequence
output [7:0]  DATA_OUT; //ouput data sequence
output        READY; //output data is READY when READY=1


parameter fp_latency = 3;

// I/O Ports
reg [7:0] DATA_OUT;
reg READY;

// Internal Registers
reg [4:0] counter_in;
reg [63:0] input_A, input_B;
reg in_data_rdy;
reg [63:0] output_Z;
reg [3:0] counter_out;
reg [31:0] fp_count;

reg sign_A, sign_B, sign_Z;
reg [10:0] exp_A, exp_B, exp_Z;
reg [52:0] frac_A, frac_B, frac_Z;
reg [105:0] product;
reg rounding_bit, guard_bit, sticky_bit;

// State Machine
reg [2:0] state, next_state;

// State Definitions
parameter IDLE           = 3'b000;
parameter LOAD_A         = 3'b001;
parameter LOAD_B         = 3'b010;
parameter CALC           = 3'b011;
parameter NORMALIZE_CALC = 3'b100;
parameter ROUND          = 3'b101;
parameter ROUND_1        = 3'b110;
parameter OUTPUT         = 3'b111;

// State Machine Implementation
always @(posedge CLK) begin
    if (RESET) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    case (state)
        IDLE: begin
            if (ENABLE) begin
                next_state = LOAD_A;
            end else begin
                next_state = IDLE;
            end
        end
        LOAD_A: begin
            if (counter_in < 8) begin
                next_state = LOAD_A;
            end else begin
                next_state = LOAD_B;
            end
        end
        LOAD_B: begin
            if (counter_in < 8) begin
                next_state = LOAD_B;
            end else begin
                next_state = CALC;
            end
        end
        CALC: begin
            if(counter_calc < 54) begin
                next_state = CALC;
            end else begin
                next_state = NORMALIZE_CALC;
            end
        end
        NORMALIZE_CALC: begin
            next_state = ROUND;
        end
        ROUND: begin
            next_state = ROUND_1;
        end
        ROUND_1: begin
            next_state = OUTPUT;
        end
        OUTPUT: begin
            if (counter_out < 8) begin
                next_state = OUTPUT;
            end else begin
                next_state = IDLE;
            end
        end
        default: next_state = IDLE;
    endcase
end

// Data Path
// Input sequence counter
always @(posedge CLK) begin 
    if (RESET) begin 
        counter_in <= 0; 
    end else if ((state == LOAD_A || state == LOAD_B) && counter_in < 8) begin 
        counter_in <= counter_in + 1; 
    end else begin 
        counter_in <= 0; 
    end 
end 

// Loading input A
always @(posedge CLK) begin 
    if (RESET) begin 
        exp_A <= 0; 
        frac_A <= 0; 
    end else if (state == LOAD_A && counter_in == 8) begin 
        exp_A <= input_A[62:52]; 
        frac_A <= {1'b1, input_A[51:0]}; 
    end 
end 

// Loading input B
always @(posedge CLK) begin 
    if (RESET) begin 
        exp_B <= 0; 
        frac_B <= 0; 
    end else if (state == LOAD_B && counter_in == 8) begin 
        exp_B <= input_B[62:52]; 
        frac_B <= {1'b1, input_B[51:0]}; 
    end 
end 

// Calculate exponent Z
always @(posedge CLK) begin 
    if (RESET) begin 
        exp_Z <= 0; 
    end else if (state == CALC) begin 
        exp_Z <= exp_A + exp_B - 1023; 
    end 
end 

// Multiplication process
reg [5:0] counter_calc;

always @(posedge CLK) begin
    if (RESET) begin
        counter_calc <= 0;
    end else if (state == CALC && counter_calc < 53) begin
        counter_calc <= counter_calc + 1;
    end else begin
        counter_calc <= 0;
    end
end

reg [52:0] multiplier;

always @(posedge CLK) begin 
    if (RESET) begin 
        product <= 106'b0; 
        multiplier <= 53'd0;
    end else if (state == CALC) begin 
        if (counter_calc == 0) begin 
            if (frac_B[0]) begin 
                product <= frac_A; 
            end else begin 
                product <= 0; 
            end 
            multiplier <= frac_B;
        end else if (counter_calc > 0 && counter_calc < 53) begin 
            if (multiplier[counter_calc]) begin 
                product <= product + (frac_A << counter_calc); 
            end 
        end 
    end else if (state == NORMALIZE_CALC && product[105] == 0) begin 
        product <= product << 1; 
    end else if (state == ROUND) begin 
        product[104:53] <= product[104:53] + product[52]; 
    end 
end 

// Output handling
always @(posedge CLK) begin 
    if (RESET) begin 
        output_Z <= 0; 
    end else if (state == ROUND_1) begin 
        output_Z <= {sign_Z, exp_Z, product[104:53]}; 
    end 
end 

// counter_out
always @(posedge CLK) begin 
    if (RESET) begin 
        counter_out <= 0; 
    end else if (state == OUTPUT && counter_out < 8) begin 
        counter_out <= counter_out + 1; 
    end else begin 
        counter_out <= 0; 
    end 
end 

//OUTPUT
always @(posedge CLK) begin 
    if (RESET) begin 
        DATA_OUT <= 0; 
    end else if (state == OUTPUT && counter_out < 8) begin 
        case (counter_out) 
            0: DATA_OUT <= output_Z[7:0]; 
            1: DATA_OUT <= output_Z[15:8]; 
            2: DATA_OUT <= output_Z[23:16]; 
            3: DATA_OUT <= output_Z[31:24]; 
            4: DATA_OUT <= output_Z[39:32]; 
            5: DATA_OUT <= output_Z[47:40]; 
            6: DATA_OUT <= output_Z[55:48]; 
            7: DATA_OUT <= output_Z[63:56]; 
            default: DATA_OUT <= 0; 
        endcase 
    end 
end

// Ready signal
always @(posedge CLK) begin
    if (RESET) begin
        READY <= 0;
    end else if (state == OUTPUT) begin
        READY <= 1;
    end else begin
        READY <= 0;
    end
end
 
endmodule