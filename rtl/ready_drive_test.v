`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: mengcheng
// 
// Create Date: 2024/05/13 14:11:50
// Design Name: 
// Module Name: ready_drive_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 用于测试port1_SGDMA模块
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module ready_drive_test(
    input                           i_clk,
    input                           i_rst_n,
    input                           i_mmu_wr_req,
    input    [`ADDR_WIDTH-1 : 0]    i_mmu_wr_addr,
    input    [`DATA_DWIDTH-1 : 0]   i_mmu_wr_dat,
    output                          o_mmu_wr_ready
    );

reg mmu_wr_ready;
reg [4:0] cnt;

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        mmu_wr_ready <= 1'b0;
    end
    else if (i_mmu_wr_req) begin
        mmu_wr_ready <= 1'b1;
    end
    else begin
        mmu_wr_ready <= 1'b0;
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        cnt <= 'd0;
    end
    else begin
        cnt <= cnt + 1'b1;
    end
end

assign o_mmu_wr_ready = mmu_wr_ready;
// //更改连续几次ready信号的高低
// generate
//     for (genvar i = 0; i < 16; i = i+1) begin
//         assign o_mmu_wr_ready[i] = mmu_wr_ready;
//     end
// endgenerate


endmodule
