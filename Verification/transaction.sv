class transaction extends uvm_sequence_item;
    `uvm_object_utils(transaction)

    rand bit [2:0]                  opcode;
    rand bit [alu_pkg::WIDTH-1:0]   num1;
    rand bit [alu_pkg::WIDTH-1:0]   num2;
    bit [alu_pkg::WIDTH-1:0]        result;
    bit                             carry_out;

    constraint legal_opcode {
        opcode inside {alu_pkg::ALU_ADD, alu_pkg::ALU_SUB, alu_pkg::ALU_AND,
                       alu_pkg::ALU_OR,  alu_pkg::ALU_XOR};
    }

    function new(string name = "transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("opcode=%0d num1=%0d num2=%0d result=%0d carry_out=%0b",
                          opcode, num1, num2, result, carry_out);
    endfunction
endclass
