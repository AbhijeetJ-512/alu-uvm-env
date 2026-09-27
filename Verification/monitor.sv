class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    virtual alu_if vif;
    uvm_analysis_port#(transaction) ap;

    bit [2:0]                    prev_opcode;
    bit [alu_pkg::WIDTH-1:0]     prev_num1;
    bit [alu_pkg::WIDTH-1:0]     prev_num2;
    bit                           have_prev;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_error("MONITOR", "unable to access interface")
    endfunction

    // Pairs each result with the instruction driven one cycle earlier
    // (Review Focus #3): have_prev is only set after the first post-reset
    // edge this task processes, so the very first result sampled — which
    // has no corresponding driven instruction yet — never becomes a
    // transaction. have_prev is also cleared whenever vif.rst_n is low, so
    // pairing is gated on reset by construction rather than relying on
    // 2-state 'bit' fields happening to truncate an undriven bus to 0
    // (which would coincidentally match alu.v's reset value).
    task run_phase(uvm_phase phase);
        transaction tr;
        have_prev = 1'b0;

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) begin
                have_prev = 1'b0;
            end else begin
                if (have_prev) begin
                    tr = transaction::type_id::create("tr");
                    tr.opcode    = prev_opcode;
                    tr.num1      = prev_num1;
                    tr.num2      = prev_num2;
                    // tr.result/carry_out are 2-state: copying X/Z would
                    // silently become 0 (== the reserved-opcode expected
                    // value), so flag it here before it is lost.
                    if ($isunknown({vif.result, vif.carry_out}))
                        `uvm_error("MONITOR",
                            $sformatf("DUT output is X/Z while out of reset: result=%b carry_out=%b",
                                      vif.result, vif.carry_out))
                    tr.result    = vif.result;
                    tr.carry_out = vif.carry_out;
                    ap.write(tr);
                end
                prev_opcode = vif.opcode;
                prev_num1   = vif.num1;
                prev_num2   = vif.num2;
                have_prev   = 1'b1;
            end
        end
    endtask
endclass
