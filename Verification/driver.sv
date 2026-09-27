class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    virtual alu_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_error("DRIVER", "unable to access interface")
    endfunction

    task run_phase(uvm_phase phase);
        transaction tr;

        @(posedge vif.clk);
        forever begin
            seq_item_port.get_next_item(tr);
            vif.opcode <= tr.opcode;
            vif.num1   <= tr.num1;
            vif.num2   <= tr.num2;
            seq_item_port.item_done();
            @(posedge vif.clk);
        end
    endtask
endclass
