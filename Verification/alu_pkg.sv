package alu_pkg;
    parameter int WIDTH = 8;

    parameter bit [2:0] ALU_ADD = 3'b000;
    parameter bit [2:0] ALU_SUB = 3'b001;
    parameter bit [2:0] ALU_AND = 3'b010;
    parameter bit [2:0] ALU_OR  = 3'b011;
    parameter bit [2:0] ALU_XOR = 3'b100;
endpackage
