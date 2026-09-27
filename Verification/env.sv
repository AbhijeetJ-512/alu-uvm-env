class env extends uvm_env;
    `uvm_component_utils(env)

    agent       a;
    scoreboard  s;
    coverage    cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a   = agent::type_id::create("a", this);
        s   = scoreboard::type_id::create("s", this);
        cov = coverage::type_id::create("cov", this);

        uvm_config_db#(coverage)::set(null, "*", "cov_h", cov);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a.m.ap.connect(s.recv);
        a.m.ap.connect(cov.analysis_export);
    endfunction
endclass
