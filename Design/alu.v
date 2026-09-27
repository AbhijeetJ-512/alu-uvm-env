module alu #(
    parameter WIDTH = 8
)(
    input  wire               clk,
    input  wire                rst_n,
    input  wire [2:0]          opcode,
    input  wire [WIDTH-1:0]    num1,
    input  wire [WIDTH-1:0]    num2,
    output reg  [WIDTH-1:0]    result,
    output reg                 carry_out
);

    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_AND = 3'b010;
    localparam OP_OR  = 3'b011;
    localparam OP_XOR = 3'b100;

    wire subtract = (opcode == OP_SUB);
    wire [WIDTH-1:0] operand2  = num2 ^ {WIDTH{subtract}};
    wire [WIDTH:0]   adder_out = {1'b0, num1} + {1'b0, operand2} + subtract;

    reg [WIDTH-1:0] result_comb;
    reg             carry_comb;

    always @(*) begin
        case (opcode)
            OP_ADD, OP_SUB: begin
                result_comb = adder_out[WIDTH-1:0];
                carry_comb  = adder_out[WIDTH];
            end
            OP_AND:  begin result_comb = num1 & num2; carry_comb = 1'b0; end
            OP_OR :  begin result_comb = num1 | num2; carry_comb = 1'b0; end
            OP_XOR:  begin result_comb = num1 ^ num2; carry_comb = 1'b0; end
            default: begin result_comb = {WIDTH{1'b0}}; carry_comb = 1'b0; end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result    <= {WIDTH{1'b0}};
            carry_out <= 1'b0;
        end else begin
            result    <= result_comb;
            carry_out <= carry_comb;
        end
    end

endmodule
