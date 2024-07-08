`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2024 10:27:37 AM
// Design Name: 
// Module Name: rd_convert_port2pram
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

module rd_convert_port2pram(
    input                                                                        i_clk,

    input                                                                        i_rd_req,
    input                                                                        i_rd_ready,
    input  [`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH-1:0]                            i_rd_pd,
    
    input  [`PRAM_NUM-1:0]                                                       i_rd_done,

    output reg [`PRAM_NUM-1:0]                                                   o_rd_req,
    output reg [`PRAM_NUM-1:0]                                                   o_rd_ready,
    output reg [`PRAM_NUM*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)-1:0]            o_rd_pd,

    output                                                                       o_rd_done
);

assign o_rd_done = i_rd_done[i_rd_pd[22:18]];

always @(posedge i_clk) begin : read_decode
    integer i;
    for (i = 0; i < 32; i = i + 1) begin 
        if (i_rd_pd[22:18] == i) begin
            o_rd_req[i] <= i_rd_req;
            o_rd_ready[i] <= i_rd_ready;
            o_rd_pd[i*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+:(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)] <= i_rd_pd;
        end
        else begin 
            o_rd_req[i] <= 'd0;
            o_rd_ready[i] <= 'd0;
            o_rd_pd[i*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+:(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)] <= 'd0;
        end
    end
end

endmodule
