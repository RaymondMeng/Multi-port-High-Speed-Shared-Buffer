`timescale 1ns / 1ps

`include "defines.v"

module rd_convert_port2pram(
    input                                                                        i_rst_n,

    input                                                                        i_sel,

    input                                                                        i_rd_req,
    input  [`PRAM_NUM-1:0]                                                       i_rd_ack,
    input  [`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH-1:0]                            i_rd_pd,
    
    input  [`PRAM_NUM-1:0]                                                       i_rd_done,
    input  [`PRAM_NUM*`DATA_FRAME_NUM-1:0]                                       i_rd_data,
    input  [`PRAM_NUM-1:0]                                                       i_rd_clk,

    input  [`PRAM_NUM-1:0]                                                       i_rd_data_vld,

    output reg [`PRAM_NUM-1:0]                                                   o_rd_req,
    output reg                                                                   o_rd_ack,
    output reg [`PRAM_NUM*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)-1:0]            o_rd_pd,

    output reg                                                                   o_rd_done,
    output reg [`DATA_FRAME_NUM-1:0]                                             o_rd_data,
    output reg                                                                   o_rd_clk,
    output reg                                                                   o_rd_data_vld
);

always @(*) begin : read_decode
    integer i;
    if (~i_rst_n) begin 
        o_rd_req = 'd0;
        o_rd_ack = 'd0;
        o_rd_pd = 'd0;
        o_rd_done = 'd0;
        o_rd_data = 'd0;
        o_rd_clk = 'd0;
        o_rd_data_vld = 'd0;
    end
    else begin 
        for (i = 0; i < 32; i = i + 1) begin 
            if (i_sel == i) begin
                o_rd_req[i] = i_rd_req;
                o_rd_ack = i_rd_ack[i];
                o_rd_pd[i*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+:(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)] = i_rd_pd;
                o_rd_done = i_rd_done[i];
                o_rd_data = i_rd_data[i*`DATA_FRAME_NUM+:`DATA_FRAME_NUM];
                o_rd_clk = i_rd_clk[i];
                o_rd_data_vld = i_rd_data_vld[i];
            end
            else begin 
                o_rd_req[i] = 'd0;
                o_rd_ack = o_rd_ack;
                o_rd_pd[i*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+:(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)] = 'd0;
                o_rd_done = o_rd_done;
                o_rd_data = o_rd_data;
                o_rd_clk = o_rd_clk;
                o_rd_data_vld = o_rd_data_vld;
            end
        end
    end
end

endmodule
