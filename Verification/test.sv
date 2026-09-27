class test extends uvm_test;
    `uvm_component_utils(test)

    env e;

    function new(string name = "test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        corner_case_seq corner;
        exhaustive_seq  exh;
        random_seq      rnd;

        phase.raise_objection(this);

        corner = corner_case_seq::type_id::create("corner");
        corner.start(e.a.seqr);

        if (alu_pkg::WIDTH <= 8) begin
            exh = exhaustive_seq::type_id::create("exh");
            exh.start(e.a.seqr);
        end else begin
            rnd = random_seq::type_id::create("rnd");
            rnd.start(e.a.seqr);
        end

        `uvm_info("TEST",
            $sformatf("Final coverage=%0.2f%% pass=%0d fail=%0d",
                       e.cov.cg.get_coverage(), e.s.pass_count, e.s.fail_count),
            UVM_LOW)

        phase.drop_objection(this);
    endtask
endclass
