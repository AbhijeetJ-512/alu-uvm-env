// uvm_ext.sv - two additions to the UVM environment, made WITHOUT touching the original sources (selected by UVM factory overrides on the command line).
// 1. random_seq_vl: a tool-portable twin of random_seq (Verification/sequence.sv).
//
// Why: random_seq draws the operands with `dist { ... := ..., ... :/ ... }`. Verilator 5.052's constraint solver rejects that
// randomize() call (it returns 0, the sequence reports "randomize failed" for every item and sends unrandomised, all-zero operands).
// This class produces the same stimulus distribution procedurally: each operand falls in one of the four coverage value classes
// of coverage.sv (zero, max, low half, high half) with equal probability, and the opcode is one of the five legal ones with equal
// probability. The simulator's constraint solver is not used at all: Verilator 5.052 also rejects randomize(opcode) on the
// transaction's own constraint (`opcode inside {package parameters}`), so the legal-opcode rule is re-stated here as a table.
// Select it with the UVM factory override
//     +uvm_set_type_override=random_seq,random_seq_vl
// (scripts/run_uvm.sh --ext ext/random_seq_vl.sv --plus +uvm_set_type_override=random_seq,random_seq_vl).
class random_seq_vl extends random_seq;   // must extend random_seq: the test creates a random_seq handle through the factory
    `uvm_object_utils(random_seq_vl)

    function new(string name = "random_seq_vl");
        super.new(name);
    endfunction

    // one operand drawn from the four value classes of coverage.sv with equal probability
    function bit [alu_pkg::WIDTH-1:0] pick();
        bit [alu_pkg::WIDTH-1:0] maxv;
        int unsigned             half;
        maxv = '1;
        half = 1 << (alu_pkg::WIDTH - 1);
        case ($urandom_range(3, 0))
            0:       pick = '0;
            1:       pick = maxv;
            2:       pick = alu_pkg::WIDTH'($urandom_range(half - 1, 1));
            default: pick = alu_pkg::WIDTH'($urandom_range(maxv - 1, half));
        endcase
    endfunction

    virtual task body();
        transaction tr;
        int unsigned count;
        bit [2:0]    ops[5];
        ops[0] = alu_pkg::ALU_ADD;  ops[1] = alu_pkg::ALU_SUB;  ops[2] = alu_pkg::ALU_AND;
        ops[3] = alu_pkg::ALU_OR;   ops[4] = alu_pkg::ALU_XOR;
        `uvm_info("RANDOM_SEQ_VL", $sformatf("starting: random operands over the four value classes, WIDTH=%0d, 20000 items", alu_pkg::WIDTH), UVM_LOW)
        for (count = 0; count < 20000; count = count + 1) begin
            tr = transaction::type_id::create("tr");
            start_item(tr);
            tr.opcode = ops[$urandom_range(4, 0)];
            tr.num1 = pick();
            tr.num2 = pick();
            finish_item(tr);
        end
        `uvm_info("RANDOM_SEQ_VL", $sformatf("issued %0d transactions", count), UVM_LOW)
    endtask
endclass

// corner_case_seq_vl - closes a hole that the mutation campaign (scripts/mutate_alu.py, mutant A06) found in the original environment:
// corner_case_seq exercises the reserved opcodes (101, 110, 111) ONLY with both operands zero, so a DUT that returns num1 (or any
// function of the operands that is 0 at 0) for a reserved opcode passes every check. This subclass runs the original body and then
// sends every reserved opcode with non-zero operand pairs, where the expected result is still 0 and the carry still 0.
// Select it with +uvm_set_type_override=corner_case_seq,corner_case_seq_vl
class corner_case_seq_vl extends corner_case_seq;
    `uvm_object_utils(corner_case_seq_vl)

    function new(string name = "corner_case_seq_vl");
        super.new(name);
    endfunction

    virtual task body();
        bit [alu_pkg::WIDTH-1:0] pairs[6][2];
        bit [alu_pkg::WIDTH-1:0] maxv, one;
        super.body();
        maxv = '1;
        one  = 1;
        pairs[0] = '{one,  '0};
        pairs[1] = '{'0,   one};
        pairs[2] = '{maxv, maxv};
        pairs[3] = '{maxv, one};
        pairs[4] = '{one,  maxv};
        pairs[5] = '{{1'b1, {(alu_pkg::WIDTH-1){1'b0}}}, {{(alu_pkg::WIDTH-1){1'b0}}, 1'b1}};
        `uvm_info("CORNER_SEQ_VL", "extension: reserved opcodes with non-zero operands", UVM_LOW)
        for (int op = 5; op <= 7; op++)
            for (int p = 0; p < 6; p++)
                send(3'(op), pairs[p][0], pairs[p][1]);
    endtask
endclass
