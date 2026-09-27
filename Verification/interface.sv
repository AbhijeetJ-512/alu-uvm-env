interface alu_if;
    import alu_pkg::WIDTH;

    logic               clk;
    logic               rst_n;
    logic [2:0]          opcode;
    logic [WIDTH-1:0]    num1;
    logic [WIDTH-1:0]    num2;
    logic [WIDTH-1:0]    result;
    logic                carry_out;
endinterface : alu_if
