`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/30 21:38:03
// Design Name: 
// Module Name: interconnect_arbi2pram_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module interconnect_arbi2pram_tb();
reg [4:0]  sel_mem;
reg [4:0]  sel_chip;

reg [6:0]  mem_apply_num;

wire [31:0] chip_apply_sig_port;
wire [31:0] mem_apply_num_vld_port;
wire [223:0] mem_apply_num_port;

interconnect_arbi2pram u1 (
    .chip_apply_req(1'b1),
    .chip_apply_sig(chip_apply_sig_port),
    .sel_chip_apply_port_num(sel_chip),
    .sel_mem_apply_port_num(sel_mem),
    .mem_apply_req(1'b1),
    .mem_apply_num(mem_apply_num),
    .mem_apply_sig(mem_apply_num_vld_port),
    .mem_apply_num_port(mem_apply_num_port)
);

initial begin
    sel_chip = 5'd0;
    sel_mem = 5'd17;
    #10
    sel_chip = 5'd1;
    #10
    sel_chip = 5'd10;
    #10
    sel_chip = 5'd17;
    #10
    sel_chip = 5'd31;
    #10
    sel_chip = 5'd0;
    sel_mem = 5'd26;
    mem_apply_num = 8'd88;
    #10
    sel_chip = 5'd1;
    #10
    sel_chip = 5'd10;
    sel_mem = 5'd30;
    mem_apply_num = 8'd77;
    #10
    sel_chip = 5'd17;
    #10
    sel_chip = 5'd31;
end

endmodule
