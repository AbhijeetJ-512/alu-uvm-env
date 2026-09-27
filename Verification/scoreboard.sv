class scoreboard extends uvm_component;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp#(transaction, scoreboard) recv;

    int unsigned pass_count;
    int unsigned fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        recv = new("recv", this);
        pass_count = 0;
        fail_count = 0;
    endfunction

    // Deliberately independent of the RTL's shared-adder implementation
    // (Review Focus #2): uses native subtraction and a plain comparison,
    // not the invert-and-carry-in trick, so a bug in that trick would be
    // caught here rather than silently reproduced.
    virtual function void write(transaction tr);
        bit [alu_pkg::WIDTH-1:0] exp_result;
        bit                       exp_carry;

        case (tr.opcode)
            alu_pkg::ALU_ADD: {exp_carry, exp_result} = {1'b0, tr.num1} + {1'b0, tr.num2};
            alu_pkg::ALU_SUB: begin
                exp_result = tr.num1 - tr.num2;
                exp_carry  = (tr.num1 >= tr.num2);
            end
            alu_pkg::ALU_AND: begin exp_result = tr.num1 & tr.num2; exp_carry = 1'b0; end
            alu_pkg::ALU_OR : begin exp_result = tr.num1 | tr.num2; exp_carry = 1'b0; end
            alu_pkg::ALU_XOR: begin exp_result = tr.num1 ^ tr.num2; exp_carry = 1'b0; end
            default:          begin exp_result = '0; exp_carry = 1'b0; end
        endcase

        if (exp_result === tr.result && exp_carry === tr.carry_out) begin
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
            `uvm_error("SCOREBOARD",
                $sformatf("MISMATCH opcode=%0d num1=%0d num2=%0d expected(result=%0d carry=%0b) actual(result=%0d carry=%0b)",
                           tr.opcode, tr.num1, tr.num2, exp_result, exp_carry, tr.result, tr.carry_out))
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD",
            $sformatf("Total=%0d Pass=%0d Fail=%0d", pass_count + fail_count, pass_count, fail_count),
            UVM_LOW)
    endfunction
endclass
