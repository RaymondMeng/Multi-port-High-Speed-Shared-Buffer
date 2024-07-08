`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/19 13:15:37
// Design Name: 
// Module Name: interconnect_pram2arbi
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

module interconnect_pram2arbi(
    input  [`PORT_NUM_WIDTH-1:0] mem_malloc_port,
    
    input  [`VT_ADDR_WIDTH-1:0]           mem_vt_addr,
    output reg [`VT_ADDR_WIDTH*`PORT_NUM-1:0] mem_vt_addr_port,

    input                  mem_addr_vld,
    output reg [`PORT_NUM-1:0] data_vld,

    input                  mem_malloc_done,
    output reg [`PORT_NUM-1:0] mem_apply_done,

    input                  data_vld_clk,
    output reg [`PORT_NUM-1:0] mem_malloc_clk               
);

integer i;
always @(mem_malloc_port) begin
    for (i=0; i<16; i=i+1) begin : addr_distribute
        if (i==mem_malloc_port) begin 
            mem_vt_addr_port[16*i+:16] = mem_vt_addr;
            data_vld[i] = data_vld;
            mem_apply_done[i] = mem_malloc_done;
            mem_malloc_clk[i] = data_vld_clk;
        end
        else begin 
            mem_vt_addr_port[16*i+:16] = 16'd0;
            data_vld[i] = 'd0;
            mem_apply_done[i] = 'd0;
            mem_malloc_clk[i] = 'd0;
        end
    end
end

endmodule
