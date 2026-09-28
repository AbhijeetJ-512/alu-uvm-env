class test extends uvm_test;
    `uvm_component_utils(test)

    env            e;
    virtual alu_if vif;

    function new(string name = "test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
        if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_fatal("TEST", "unable to access interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        corner_case_seq corner;
        exhaustive_seq  exh;
        random_seq      rnd;
        real            cov_pct;
        int unsigned    total;

        phase.raise_objection(this);

        `uvm_info("TEST", $sformatf("=== starting, WIDTH=%0d ===", alu_pkg::WIDTH), UVM_LOW)

        `uvm_info("TEST", "phase 1/2: corner_case_seq", UVM_LOW)
        corner = corner_case_seq::type_id::create("corner");
        corner.start(e.a.seqr);

        if (alu_pkg::WIDTH <= 8) begin
            `uvm_info("TEST", "phase 2/2: exhaustive_seq (WIDTH<=8)", UVM_LOW)
            exh = exhaustive_seq::type_id::create("exh");
            exh.start(e.a.seqr);
        end else begin
            `uvm_info("TEST", "phase 2/2: random_seq (WIDTH>8)", UVM_LOW)
            rnd = random_seq::type_id::create("rnd");
            rnd.start(e.a.seqr);
        end

        `uvm_info("TEST", "all sequences complete, draining pipeline before checking", UVM_LOW)

        // Drain the pipeline before checking. The last instruction is driven
        // on the posedge the final sequence returns on; the DUT registers its
        // result on the next posedge, and the monitor publishes that
        // (instruction, result) pair on the posedge after — so the final 2
        // instructions only reach the scoreboard/coverage on the next 2
        // posedges. Exactly 2: a 3rd posedge would make the monitor re-publish
        // the still-held last instruction as a spurious extra transaction.
        // The negedge then moves past the 2nd posedge's time slot, since this
        // process and the monitor both wake on that posedge in unspecified
        // order and the monitor's final write must land before counts are read.
        repeat (2) @(posedge vif.clk);
        @(negedge vif.clk);

        cov_pct = e.cov.cg.get_coverage();
        total   = e.s.pass_count + e.s.fail_count;

        `uvm_info("TEST",
            $sformatf("Final coverage=%0.2f%% pass=%0d fail=%0d",
                       cov_pct, e.s.pass_count, e.s.fail_count),
            UVM_LOW)

        if (total == 0)
            `uvm_error("TEST", "scoreboard checked 0 transactions - the environment produced no checkable output")
        if (e.s.fail_count > 0)
            `uvm_error("TEST", $sformatf("%0d of %0d scoreboard checks failed", e.s.fail_count, total))
        if (cov_pct < 95.0)
            `uvm_warning("TEST", $sformatf("functional coverage %0.2f%% is below the 95%% goal", cov_pct))

        `uvm_info("TEST", "=== done ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass
