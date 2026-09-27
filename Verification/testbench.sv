`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "alu_pkg.sv"
import alu_pkg::*;

`include "interface.sv"
`include "transaction.sv"
`include "sequence.sv"
`include "driver.sv"
`include "monitor.sv"
`include "coverage.sv"
`include "scoreboard.sv"
`include "config.sv"
`include "agent.sv"
`include "env.sv"
`include "test.sv"

module alu_tb_top;

    alu_if vif();

    initial begin
        vif.clk = 0;
        forever #10 vif.clk = ~vif.clk;
    end

    initial begin
        vif.rst_n = 0;
        #20 vif.rst_n = 1;
    end

    alu #(.WIDTH(alu_pkg::WIDTH)) dut (
        .clk       (vif.clk),
        .rst_n     (vif.rst_n),
        .opcode    (vif.opcode),
        .num1      (vif.num1),
        .num2      (vif.num2),
        .result    (vif.result),
        .carry_out (vif.carry_out)
    );

    initial begin
        uvm_config_db#(virtual alu_if)::set(null, "*", "vif", vif);
        run_test("test");
    end

endmodule
