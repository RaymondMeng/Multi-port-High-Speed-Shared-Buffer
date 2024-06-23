`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/01 17:20:07
// Design Name: 
// Module Name: pram_ctor_tb
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


module pram_ctor_tb();

reg sys_clk;
reg sys_clk_half;
reg sys_rst;
reg [15:0] chip_apply_sig;
reg [15:0] mem_apply_sig;
reg [111:0] apply_num;

reg [15:0] read_apply_sig;
reg [22:0] pd;

initial begin
    sys_rst = 1'b0;
    sys_clk = 1'b1;
    sys_clk_half = 1'b1;
    #10
    sys_rst = 1'b1;
    #5
    chip_apply_sig = 16'hf00f;
    mem_apply_sig = 16'hab10;
    apply_num = 111'h1020_3050_4060_7080_90a0;
    #50
    read_apply_sig = 16'hff00;
    pd = {5'd16, 11'h1dd, 7'd33};
end

always #5 sys_clk = ~sys_clk;
always #10 sys_clk_half = ~sys_clk_half;

pram_ctor #(
    .PRAM_NUMBER(5)
)
pram_ctor_u0 (
    .i_chip_apply_sig(chip_apply_sig),
    .i_clk(sys_clk),
    .i_rst_n(sys_rst),
    // .i_clk_125(sys_clk_half),
    .i_mem_apply_sig(mem_apply_sig),
    .i_mem_apply_num(apply_num),

    .i_read_apply_sig(read_apply_sig),
    .i_pd(pd)
);

endmodule