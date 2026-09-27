class coverage extends uvm_subscriber #(transaction);
    `uvm_component_utils(coverage)

    transaction tr;

    covergroup cg;
        option.per_instance = 1;

        op_cp: coverpoint tr.opcode {
            bins add      = {alu_pkg::ALU_ADD};
            bins sub      = {alu_pkg::ALU_SUB};
            bins b_and    = {alu_pkg::ALU_AND};
            bins b_or     = {alu_pkg::ALU_OR};
            bins b_xor    = {alu_pkg::ALU_XOR};
            bins reserved[] = {[5:7]};
        }

        num1_cp: coverpoint tr.num1 {
            bins zero = {0};
            bins max  = {{alu_pkg::WIDTH{1'b1}}};
            bins low  = {[1 : (1 << (alu_pkg::WIDTH-1)) - 1]};
            bins high = {[(1 << (alu_pkg::WIDTH-1)) : {alu_pkg::WIDTH{1'b1}} - 1]};
        }

        num2_cp: coverpoint tr.num2 {
            bins zero = {0};
            bins max  = {{alu_pkg::WIDTH{1'b1}}};
            bins low  = {[1 : (1 << (alu_pkg::WIDTH-1)) - 1]};
            bins high = {[(1 << (alu_pkg::WIDTH-1)) : {alu_pkg::WIDTH{1'b1}} - 1]};
        }

        carry_cp: coverpoint tr.carry_out;

        // `intersect {}` takes opcode *values* (IEEE 1800 19.6.1), not bin
        // names: [5:7] selects the reserved[] bins, and
        // [ALU_AND:ALU_XOR] (= [2:4]) selects the b_and/b_or/b_xor bins.
        op_x_operands: cross op_cp, num1_cp, num2_cp {
            ignore_bins reserved_ops = binsof(op_cp) intersect {[5:7]};
        }

        op_x_carry: cross op_cp, carry_cp {
            ignore_bins logical_ops_and_reserved =
                binsof(op_cp) intersect {[alu_pkg::ALU_AND:alu_pkg::ALU_XOR], [5:7]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();
    endfunction

    function void write(transaction t);
        tr = t;
        cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE", $sformatf("Functional coverage = %0.2f%%", cg.get_coverage()), UVM_LOW)
    endfunction
endclass
