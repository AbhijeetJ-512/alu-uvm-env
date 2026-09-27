class alu_config extends uvm_object;
    `uvm_object_utils(alu_config)

    function new(string name = "alu_config");
        super.new(name);
    endfunction

    uvm_active_passive_enum is_active = UVM_ACTIVE;
endclass
