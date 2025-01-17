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
always @(posedge CLK) begin
    if (RESET) begin
        counter_in <= 0;
        in_data_rdy <= 0;
        input_A <= 0;
        input_B <= 0;
        sign_A <= 0;
        exp_A <= 0;
        frac_A <= 0;
        sign_B <= 0;
        exp_B <= 0;
        frac_B <= 0;
        sign_Z <= 0;
        exp_Z <= 0;
        frac_Z <= 0;
        fp_count <= 0;
        READY <= 0;
        DATA_OUT <= 0;
        counter_out <= 0;
        output_Z <= 0;
        product <= 0;
        rounding_bit <= 0;
        guard_bit <= 0;
        sticky_bit <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (ENABLE) begin
                    in_data_rdy <= 0;
                    READY <= 0;
                    counter_in <= 1;
                    input_A <= {DATA_IN, input_A[63:8]};
                end
            end
            LOAD_A: begin
                if (counter_in < 8) begin
                    input_A <= {DATA_IN, input_A[63:8]};
                    counter_in <= counter_in + 1;
                end else begin
                    counter_in <= 1;
                    input_B <= {DATA_IN, input_B[63:8]};
                end
            end
            LOAD_B: begin
                if (counter_in < 8) begin
                    input_B <= {DATA_IN, input_B[63:8]};
                    counter_in <= counter_in + 1;
                end else begin
                    in_data_rdy <= 1;
                    sign_A <= input_A[63];
                    exp_A <= input_A[62:52];
                    frac_A <= {1'b1, input_A[51:0]};
                    sign_B <= input_B[63];
                    exp_B <= input_B[62:52];
                    frac_B <= {1'b1, input_B[51:0]};
                end
            end
            CALC: begin
                sign_Z <= sign_A ^ sign_B;
                product <= frac_A * frac_B;
                exp_Z <= exp_A + exp_B - 1023;
            end
            NORMALIZE_CALC: begin
                if (product[105] == 0) begin
                    product <= product << 1;
                    exp_Z <= exp_Z - 1;
                end
                frac_Z <= product[104:52];
                guard_bit <= product[51];
                rounding_bit <= product[50];
                sticky_bit <= |product[49:0];
            end
            ROUND: begin
                if (guard_bit && (rounding_bit || sticky_bit || frac_Z[0])) begin
                    frac_Z <= frac_Z + 1;
                end
            end
            ROUND_1: begin
                if (frac_Z[52]) begin
                    frac_Z <= frac_Z >> 1;
                    exp_Z <= exp_Z + 1;
                end
                output_Z <= {sign_Z, exp_Z, frac_Z[51:0]};
                fp_count <= 0;
            end
            OUTPUT: begin
                if (fp_count < fp_latency) begin
                    fp_count <= fp_count + 1;
                end else begin
                    if (counter_out < 8) begin
                        DATA_OUT <= output_Z[63 - 8 * counter_out -: 8];
                        counter_out <= counter_out + 1;
                        READY <= 1;
                    end else begin
                        READY <= 0;
                        counter_out <= 0;
                    end
                end
            end
        endcase
    end
end

endmodule
