// Forward declaration: random_seq below references the `coverage` class
// (Task 8) as a variable type, but testbench.sv's `include order (Task 11)
// puts sequence.sv before coverage.sv — without this, that reference would
// be an undeclared-type compile error. This is the standard SV idiom for
// exactly that situation (see plan's pre-flight scan ruling).
typedef class coverage;

class corner_case_seq extends uvm_sequence#(transaction);
    `uvm_object_utils(corner_case_seq)

    function new(string name = "corner_case_seq");
        super.new(name);
    endfunction

    task send(bit [2:0] opcode, bit [alu_pkg::WIDTH-1:0] num1, bit [alu_pkg::WIDTH-1:0] num2);
        transaction tr;
        tr = transaction::type_id::create("tr");
        start_item(tr);
        tr.opcode = opcode;
        tr.num1   = num1;
        tr.num2   = num2;
        finish_item(tr);
    endtask

    virtual task body();
        bit [2:0] ops[5];
        bit [alu_pkg::WIDTH-1:0] zero, max, low, high;
        int i;

        ops[0] = alu_pkg::ALU_ADD;
        ops[1] = alu_pkg::ALU_SUB;
        ops[2] = alu_pkg::ALU_AND;
        ops[3] = alu_pkg::ALU_OR;
        ops[4] = alu_pkg::ALU_XOR;

        zero = '0;
        max  = '1;
        low  = {{(alu_pkg::WIDTH-1){1'b0}}, 1'b1};
        high = max - low;

        for (i = 0; i < 5; i = i + 1) begin
            send(ops[i], zero, zero);
            send(ops[i], max,  max);
            send(ops[i], low,  high);
            send(ops[i], high, low);
        end

        send(alu_pkg::ALU_SUB, max,  zero);
        send(alu_pkg::ALU_SUB, zero, max);

        send(3'b101, zero, zero);
        send(3'b110, zero, zero);
        send(3'b111, zero, zero);
    endtask
endclass

class exhaustive_seq extends uvm_sequence#(transaction);
    `uvm_object_utils(exhaustive_seq)

    function new(string name = "exhaustive_seq");
        super.new(name);
    endfunction

    // Intended for alu_pkg::WIDTH <= 8 only (see spec) — the loop counters
    // are plain ints specifically so they don't wrap at WIDTH bits (Review
    // Focus #4); at larger widths this task is simply not invoked (Task 11).
    virtual task body();
        bit [2:0]        ops[5];
        int               i;
        int unsigned      a, b;
        int unsigned      max_val;
        transaction       tr;

        ops[0] = alu_pkg::ALU_ADD;
        ops[1] = alu_pkg::ALU_SUB;
        ops[2] = alu_pkg::ALU_AND;
        ops[3] = alu_pkg::ALU_OR;
        ops[4] = alu_pkg::ALU_XOR;

        max_val = (1 << alu_pkg::WIDTH) - 1;

        for (i = 0; i < 5; i = i + 1) begin
            for (a = 0; a <= max_val; a = a + 1) begin
                for (b = 0; b <= max_val; b = b + 1) begin
                    tr = transaction::type_id::create("tr");
                    start_item(tr);
                    tr.opcode = ops[i];
                    tr.num1   = a[alu_pkg::WIDTH-1:0];
                    tr.num2   = b[alu_pkg::WIDTH-1:0];
                    finish_item(tr);
                end
            end
        end
    endtask
endclass

class random_seq extends uvm_sequence#(transaction);
    `uvm_object_utils(random_seq)

    function new(string name = "random_seq");
        super.new(name);
    endfunction

    virtual task body();
        coverage      cov_h;
        transaction   tr;
        int unsigned  count;
        int unsigned  max_transactions;
        real          cov_pct;

        max_transactions = 20000;
        count   = 0;
        cov_pct = 0.0;
        cov_h   = null;

        if (!uvm_config_db#(coverage)::get(null, "", "cov_h", cov_h))
            `uvm_warning("RANDOM_SEQ", "coverage handle not found; falling back to a fixed 500-item run")

        // Each operand is skewed to ~25% per coverage value class (the dist
        // ranges below are exactly coverage.sv's zero/max/low/high bins):
        // `:=` weights the single value, `:/` spreads the same total weight
        // across a whole range. Plain uniform randomize() would almost never
        // hit the zero/max singletons at WIDTH>8, so op_x_operands (and the
        // cov_pct >= 100.0 exit below) could never realistically close.
        forever begin
            tr = transaction::type_id::create("tr");
            start_item(tr);
            if (!tr.randomize() with {
                  num1 dist { 0                                                        := 1,
                              {alu_pkg::WIDTH{1'b1}}                                   := 1,
                              [1 : (1 << (alu_pkg::WIDTH-1)) - 1]                      :/ 1,
                              [(1 << (alu_pkg::WIDTH-1)) : {alu_pkg::WIDTH{1'b1}} - 1] :/ 1 };
                  num2 dist { 0                                                        := 1,
                              {alu_pkg::WIDTH{1'b1}}                                   := 1,
                              [1 : (1 << (alu_pkg::WIDTH-1)) - 1]                      :/ 1,
                              [(1 << (alu_pkg::WIDTH-1)) : {alu_pkg::WIDTH{1'b1}} - 1] :/ 1 };
                })
                `uvm_error("RANDOM_SEQ", "randomize failed")
            finish_item(tr);
            count = count + 1;

            if (cov_h != null)
                cov_pct = cov_h.cg.get_coverage();

            if (cov_h != null && cov_pct >= 100.0)
                break;
            if (cov_h == null && count >= 500)
                break;
            if (count >= max_transactions)
                break;
        end

        `uvm_info("RANDOM_SEQ",
                  $sformatf("issued %0d transactions, coverage=%0.2f%%", count, cov_pct),
                  UVM_LOW)
    endtask
endclass
