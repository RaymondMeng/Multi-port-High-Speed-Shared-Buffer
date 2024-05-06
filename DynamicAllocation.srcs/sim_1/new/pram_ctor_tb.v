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
reg sys_rst;
reg [15:0] chip_apply_sig;
reg [15:0] mem_apply_sig;
reg [127:0] apply_num;

initial begin
    sys_rst = 1'b0;
    sys_clk = 1'b0;
    #5
    sys_rst = 1'b1;
    #5
    chip_apply_sig = 16'hffff;
    mem_apply_sig = 16'hab10;
    apply_num = 128'he0f0_30d0_c0b0_1020_3050_4060_7080_90a0;
end

always #5 sys_clk = ~sys_clk;

pram_ctor pram_ctor_u0 (
    .i_chip_apply_sig(chip_apply_sig),
    .i_clk(sys_clk),
    .i_rst_n(sys_rst),
    .i_mem_apply_sig(mem_apply_sig),
    .i_mem_apply_num(apply_num)
);

endmodule
