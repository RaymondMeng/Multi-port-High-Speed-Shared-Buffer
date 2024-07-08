`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/19 21:40:11
// Design Name: 
// Module Name: interconnect_pram2arbi_16
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
`include "defines.v"

module interconnect_pram2arbi_16(
    input  [`PRAM_NUM_WIDTH-1:0] mem_apply_port,

    input  [`PRAM_NUM-1:0] mem_malloc_done,
    output reg             mem_apply_done,

    input  [`PRAM_NUM-1:0] data_vld,
    output reg             mem_addr_vld,

    input  [`PRAM_NUM-1:0] mem_malloc_clk,
    output reg             data_vld_clk,

    input  [`VT_ADDR_WIDTH*`PRAM_NUM-1:0] mem_vt_addr_port,
    output reg [`VT_ADDR_WIDTH-1:0] mem_vt_addr,

    input  [`PRAM_NUM-1:0] mem_refuse,
    output reg             mem_apply_refuse
    );

integer i;
always @(mem_apply_port) begin
    for (i=0; i<32; i=i+1) begin : addr_sel
        if (i==mem_apply_port) begin 
            mem_vt_addr = mem_vt_addr_port[16*i+:16];
            mem_addr_vld = data_vld[i];
            mem_apply_done = mem_malloc_done[i];
            data_vld_clk = mem_malloc_clk[i];
        end
        else begin 
            mem_vt_addr = 16'd0;
            mem_addr_vld = 'd0;
            mem_apply_done = 'd0;
            data_vld_clk = 'd0;
        end
    end
end

endmodule
