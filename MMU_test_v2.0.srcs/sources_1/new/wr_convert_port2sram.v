`timescale 1ns / 1ps

`include "defines.v"

/*
`define PRAM_NUM 32                              // PRAM数量
`define PORT_NUM 16                              // 端口数量
`define PORT_NUM_WIDTH 4                         // 表示端口号的位数
`define PRAM_NUM_WIDTH 5                         // 表示PRAM号的位数
`define MEM_ADDR_WIDTH 11                        // 物理地址位宽
`define VT_ADDR_WIDTH 16                         // 虚拟地址位宽
`define DATA_DEEPTH_WIDTH 7                      // 数据深度位宽
`define DATA_FRAME_NUM_WIDTH 7                   // 单个数据包帧数量位宽
`define DATA_FRAME_NUM 128                       // 信源位宽
`define PRAM_DEPTH_WIDTH 12                      // PRAM最大深度表示位宽
*/

module wr_convert_port2sram(
    input                                  i_clk,

    input                                  i_wr_req,
    input                                  i_wr_en,
    input  [`VT_ADDR_WIDTH-1:0]            i_wr_vt_addr,
    input  [`DATA_FRAME_NUM-1:0]           i_wr_data,
    input                                  i_wr_done,

    input  [`PRAM_NUM-1:0]                 i_wr_ack,                      

    output reg [`PRAM_NUM-1:0]                 o_wr_req,
    output reg [`PRAM_NUM-1:0]                 o_wr_en,
    output reg [`PRAM_NUM*`MEM_ADDR_WIDTH-1:0] o_wr_phy_addr,
    output reg [`PRAM_NUM*`DATA_FRAME_NUM-1:0] o_wr_data,
    output reg [`PRAM_NUM-1:0]                 o_wr_done,

    output                                     o_wr_ack
);

assign o_wr_ack = i_wr_ack[i_wr_vt_addr[15:11]];

always @(posedge i_clk) begin : write_decode
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
        if (i == i_wr_vt_addr[15:11]) begin 
            o_wr_req[i] <= i_wr_req;
            o_wr_en[i] <= i_wr_en;
            o_wr_phy_addr[i*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH] <= i_wr_vt_addr[10:0];
            o_wr_data[i*`DATA_FRAME_NUM+:`DATA_FRAME_NUM] <= i_wr_data;
            o_wr_done[i] <= i_wr_done;
        end
        else begin 
            o_wr_req[i] <= 'd0;
            o_wr_en[i] <= 'd0;
            o_wr_phy_addr[i*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH] <= 'd0;
            o_wr_data[i*`DATA_FRAME_NUM+:`DATA_FRAME_NUM] <= 'd0;
            o_wr_done[i] <= 'd0;
        end
    end
end

endmodule
