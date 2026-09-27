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

    // Register the inputs on clock edges
    reg [2:0]         opcode_r;
    reg [WIDTH-1:0]   num1_r;
    reg [WIDTH-1:0]   num2_r;

    wire subtract = (opcode_r == OP_SUB);
    wire [WIDTH-1:0] operand2  = num2_r ^ {WIDTH{subtract}};
    wire [WIDTH:0]   adder_out = {1'b0, num1_r} + {1'b0, operand2} + subtract;

    always @(*) begin
        case (opcode_r)
            OP_ADD, OP_SUB: begin
                result = adder_out[WIDTH-1:0];
                carry_out = adder_out[WIDTH];
            end
            OP_AND:  begin result = num1_r & num2_r; carry_out = 1'b0; end
            OP_OR :  begin result = num1_r | num2_r; carry_out = 1'b0; end
            OP_XOR:  begin result = num1_r ^ num2_r; carry_out = 1'b0; end
            default: begin result = {WIDTH{1'b0}}; carry_out = 1'b0; end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opcode_r <= 3'b0;
            num1_r   <= {WIDTH{1'b0}};
            num2_r   <= {WIDTH{1'b0}};
        end else begin
            opcode_r <= opcode;
            num1_r   <= num1;
            num2_r   <= num2;
        end
    end

endmodule
