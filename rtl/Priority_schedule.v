`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/14 11:06
// Design Name: 
// Module Name: priority_schedule
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 优先级调度模块主要是针对crossbar的每一列输出，
//              也即四个端口的包调度数据，该模块有针对四个端口调度的功能，
//              调度完缓存,暴露缓存接口
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module priority_schedule (
    input                                  i_clk,
    input                                  i_rst_n,
    
    input       [4:0]                      i_queue_sel,  //bit4 ~ 2: priority     bit1 ~ 0: dest_port低两位
    input       [`DISPATCH_WIDTH-1:0]      i_cb_col_dat,
    input                                  i_cb_col_dat_valid,
    //out of queue cache interface
    input                                  i_ooqc1_rd_en,
    output      [`DISPATCH_WIDTH-1:0]      o_ooqc1_rd_dat, //数据包括首地址和长度
    output                                 o_ooqc1_rd_empty,

    input                                  i_ooqc2_rd_en,
    output      [`DISPATCH_WIDTH-1:0]      o_ooqc2_rd_dat, //数据包括首地址和长度
    output                                 o_ooqc2_rd_empty,

    input                                  i_ooqc3_rd_en,
    output      [`DISPATCH_WIDTH-1:0]      o_ooqc3_rd_dat, //数据包括首地址和长度
    output                                 o_ooqc3_rd_empty,

    input                                  i_ooqc4_rd_en,
    output      [`DISPATCH_WIDTH-1:0]      o_ooqc4_rd_dat, //数据包括首地址和长度
    output                                 o_ooqc4_rd_empty
);
//优先级队列号：0~31
//0~7:端口一的8个优先级队列
//8~15:端口二的8个优先级队列
//16~23:端口三的8个优先级队列
//24~31:端口四的8个优先级队列
// wire [`DISPATCH_WIDTH-1:0] pq_din [31:0];
wire [31:0] pq_wr_en;
wire [31:0] pq_rd_en;
wire [`DISPATCH_WIDTH-1:0] pq_dout [31:0];
wire [31:0] pq_empty, pq_full;
wire [4:0] data_count [31:0];

//out-of-queue cache 
wire [`DISPATCH_WIDTH-1:0] ooqc_din [3:0];
wire [3:0] ooqc_wr_en;
wire [3:0] ooqc_rd_en;
wire [`DISPATCH_WIDTH-1:0] ooqc_dout [3:0];
wire [3:0] ooqc_full, ooqc_empty;

//pq_wr_en的选择赋值
assign pq_wr_en[0] = (i_queue_sel==5'b000_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[1] = (i_queue_sel==5'b001_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[2] = (i_queue_sel==5'b010_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[3] = (i_queue_sel==5'b011_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[4] = (i_queue_sel==5'b100_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[5] = (i_queue_sel==5'b101_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[6] = (i_queue_sel==5'b110_00) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[7] = (i_queue_sel==5'b111_00) ? i_cb_col_dat_valid : 1'b0;

assign pq_wr_en[8]  = (i_queue_sel==5'b000_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[9]  = (i_queue_sel==5'b001_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[10] = (i_queue_sel==5'b010_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[11] = (i_queue_sel==5'b011_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[12] = (i_queue_sel==5'b100_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[13] = (i_queue_sel==5'b101_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[14] = (i_queue_sel==5'b110_01) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[15] = (i_queue_sel==5'b111_01) ? i_cb_col_dat_valid : 1'b0;

assign pq_wr_en[16] = (i_queue_sel==5'b000_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[17] = (i_queue_sel==5'b001_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[18] = (i_queue_sel==5'b010_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[19] = (i_queue_sel==5'b011_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[20] = (i_queue_sel==5'b100_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[21] = (i_queue_sel==5'b101_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[22] = (i_queue_sel==5'b110_10) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[23] = (i_queue_sel==5'b111_10) ? i_cb_col_dat_valid : 1'b0;

assign pq_wr_en[24] = (i_queue_sel==5'b000_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[25] = (i_queue_sel==5'b001_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[26] = (i_queue_sel==5'b010_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[27] = (i_queue_sel==5'b011_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[28] = (i_queue_sel==5'b100_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[29] = (i_queue_sel==5'b101_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[30] = (i_queue_sel==5'b110_11) ? i_cb_col_dat_valid : 1'b0;
assign pq_wr_en[31] = (i_queue_sel==5'b111_11) ? i_cb_col_dat_valid : 1'b0;


//包含四个端口的32块fifo 32bit×32深度
genvar i;
generate
    for (i = 0; i < 32; i = i + 1) begin: priority_queue
        priority_queue priority_queue_inst (
            .clk(i_clk),                  // input wire clk
            .srst(~i_rst_n),                // input wire srst
            .din(i_cb_col_dat),                  // input wire [31 : 0] din
            .wr_en(pq_wr_en[i]),              // input wire wr_en
            .rd_en(pq_rd_en[i]),              // input wire rd_en
            .dout(pq_dout[i]),                // output wire [31 : 0] dout
            .full(pq_full[i]),                // output wire full
            .empty(pq_empty[i]),              // output wire empty
            .data_count(data_count[i])    // output wire [4 : 0] data_count
        );
    end
endgenerate

wire [2:0] pq_sel [3:0];
wire [3:0] cache_en;

//例化4次，4个端口
genvar j;
generate
    for (j = 0; j < 4; j = j + 1) begin : Priority_strategy
        Priority_strategy Priority_strategy_inst(
            .i_clk                        (i_clk),
            .i_rst_n                      (i_rst_n),
            .i_pq_empty                   (pq_empty[j*8 + 7 : j*8]),
            .o_pq_rd_en                   (pq_rd_en[j*8 + 7 : j*8]),
            .o_pq_sel                     (pq_sel[j]),
            .o_cache_en                   (cache_en[j]),
            .i_queue_cnt                  ({data_count[8*j+7], data_count[8*j+6], data_count[8*j+5], data_count[8*j+4], data_count[8*j+3], data_count[8*j+2], data_count[8*j+1], data_count[8*j]})
        );
    end
endgenerate

assign ooqc_din[0] = (pq_sel[0] == 'd0) ? pq_dout[0] :
                     (pq_sel[0] == 'd1) ? pq_dout[1] :
                     (pq_sel[0] == 'd2) ? pq_dout[2] :
                     (pq_sel[0] == 'd3) ? pq_dout[3] :
                     (pq_sel[0] == 'd4) ? pq_dout[4] :
                     (pq_sel[0] == 'd5) ? pq_dout[5] :
                     (pq_sel[0] == 'd6) ? pq_dout[6] : pq_dout[7];

assign ooqc_din[1] = (pq_sel[1] == 'd0) ? pq_dout[8] :
                     (pq_sel[1] == 'd1) ? pq_dout[9] :
                     (pq_sel[1] == 'd2) ? pq_dout[10] :
                     (pq_sel[1] == 'd3) ? pq_dout[11] :
                     (pq_sel[1] == 'd4) ? pq_dout[12] :
                     (pq_sel[1] == 'd5) ? pq_dout[13] :
                     (pq_sel[1] == 'd6) ? pq_dout[14] : pq_dout[15];

assign ooqc_din[2] = (pq_sel[2] == 'd0) ? pq_dout[16] :
                     (pq_sel[2] == 'd1) ? pq_dout[17] :
                     (pq_sel[2] == 'd2) ? pq_dout[18] :
                     (pq_sel[2] == 'd3) ? pq_dout[19] :
                     (pq_sel[2] == 'd4) ? pq_dout[20] :
                     (pq_sel[2] == 'd5) ? pq_dout[21] :
                     (pq_sel[2] == 'd6) ? pq_dout[22] : pq_dout[23];

assign ooqc_din[3] = (pq_sel[3] == 'd0) ? pq_dout[24] :
                     (pq_sel[3] == 'd1) ? pq_dout[25] :
                     (pq_sel[3] == 'd2) ? pq_dout[26] :
                     (pq_sel[3] == 'd3) ? pq_dout[27] :
                     (pq_sel[3] == 'd4) ? pq_dout[28] :
                     (pq_sel[3] == 'd5) ? pq_dout[29] :
                     (pq_sel[3] == 'd6) ? pq_dout[30] : pq_dout[31];


assign ooqc_rd_en[0] = i_ooqc1_rd_en;
assign ooqc_rd_en[1] = i_ooqc2_rd_en;
assign ooqc_rd_en[2] = i_ooqc3_rd_en;
assign ooqc_rd_en[3] = i_ooqc4_rd_en;

assign o_ooqc1_rd_dat = ooqc_dout[0];
assign o_ooqc2_rd_dat = ooqc_dout[1];
assign o_ooqc3_rd_dat = ooqc_dout[2];
assign o_ooqc4_rd_dat = ooqc_dout[3];

assign o_ooqc1_rd_empty = ooqc_empty[0];
assign o_ooqc2_rd_empty = ooqc_empty[1];
assign o_ooqc3_rd_empty = ooqc_empty[2];
assign o_ooqc4_rd_empty = ooqc_empty[3];

//out-of-queue cache width:32 depth:64
genvar k;
generate
    for (k = 0; k < 4; k = k + 1) begin: out_of_queue_cache
        out_of_queue_cache out_of_queue_cache_inst(
            .clk(i_clk),                  // input wire clk
            .srst(~i_rst_n),                // input wire srst
            .din(ooqc_din[k]),                  // input wire [31 : 0] din
            .wr_en(cache_en[k]),              // input wire wr_en
            .rd_en(ooqc_rd_en[k]),              // input wire rd_en
            .dout(ooqc_dout[k]),                // output wire [31 : 0] dout
            .full(ooqc_full[k]),                // output wire full
            .empty(ooqc_empty[k])              // output wire empty
        );
    end
endgenerate

// reg mmu1_rd_req, mmu2_rd_req, mmu3_rd_req, mmu4_rd_req;
// reg mmu1_aply_dat, mmu2_aply_dat, mmu3_aply_dat, mmu4_aply_dat;

// assign o_mmu1_rd_req = mmu1_rd_req;
// assign o_mmu2_rd_req = mmu2_rd_req;
// assign o_mmu3_rd_req = mmu3_rd_req;
// assign o_mmu4_rd_req = mmu4_rd_req;

// assign o_mmu1_aply_dat = mmu1_aply_dat;
// assign o_mmu2_aply_dat = mmu2_aply_dat;
// assign o_mmu3_aply_dat = mmu3_aply_dat;
// assign o_mmu4_aply_dat = mmu4_aply_dat;

/*TODO*/


endmodule