`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/19 18:33:44
// Design Name: 
// Module Name: Crossbar_switching_fabric
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: cross node index
//
//           dest_pot 0 ~ 3  4 ~ 7  8 ~ 11  12 ~ 15
//                    col1   col2    col3    col4
//           line1      0      1       2       3
//           line2      4      5       6       7
//           line3      8      9       10      11
//           line4      12     13      14      15
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module Crossbar_switching_fabric(
    input                                      i_clk,
    input                                      i_rst_n,

    input           [`DISPATCH_WIDTH-1:0]      i_cb_l1_din,
    input           [1:0]                      i_cb_l1_sel,
    input                                      i_cb_l1_wr_en,

    input           [`DISPATCH_WIDTH-1:0]      i_cb_l2_din,
    input           [1:0]                      i_cb_l2_sel,
    input                                      i_cb_l2_wr_en,

    input           [`DISPATCH_WIDTH-1:0]      i_cb_l3_din,
    input           [1:0]                      i_cb_l3_sel,
    input                                      i_cb_l3_wr_en,

    input           [`DISPATCH_WIDTH-1:0]      i_cb_l4_din,
    input           [1:0]                      i_cb_l4_sel,
    input                                      i_cb_l4_wr_en,

    //input                                      i_cb_c1_ready,
    output          [4:0]                      o_cb_c1_queue_sel,
    output          [`DISPATCH_WIDTH-1:0]      o_cb_c1_dout,
    output                                     o_cb_c1_dat_valid,

    //input                                      i_cb_c2_ready,
    output          [4:0]                      o_cb_c2_queue_sel,
    output          [`DISPATCH_WIDTH-1:0]      o_cb_c2_dout,
    output                                     o_cb_c2_dat_valid,

    //input                                      i_cb_c3_ready,
    output          [4:0]                      o_cb_c3_queue_sel,
    output          [`DISPATCH_WIDTH-1:0]      o_cb_c3_dout,
    output                                     o_cb_c3_dat_valid,

    //input                                      i_cb_c4_ready,
    output          [4:0]                      o_cb_c4_queue_sel,
    output          [`DISPATCH_WIDTH-1:0]      o_cb_c4_dout,
    output                                     o_cb_c4_dat_valid
    );

// reg l1_node_rd_en, l2_node_rd_en, l3_node_rd_en, l4_node_rd_en;
// reg [`DISPATCH_WIDTH-1:0] l1_cross_node_dout, l2_cross_node_dout, l3_cross_node_dout, l4_cross_node_dout;
// reg [`DISPATCH_WIDTH-1:0] cb_c1_dout, cb_c2_dout, cb_c3_dout, cb_c4_dout;
// reg [4:0] cb_c1_queue_sel, cb_c2_queue_sel, cb_c3_queue_sel, cb_c4_queue_sel;
// reg cb_c1_dat_valid, cb_c2_dat_valid, cb_c3_dat_valid, cb_c4_dat_valid;

wire [`DISPATCH_WIDTH-1:0] cross_node_din [`PORT_NUM-1:0]; //总共16个crossbar节点
wire [`PORT_NUM-1:0] cross_node_wr_en ; //16个
reg [`PORT_NUM-1:0] cross_node_rd_en; //16个
wire [`DISPATCH_WIDTH-1:0] cross_node_dout [`PORT_NUM-1:0]; //16个
wire [`PORT_NUM-1:0] full; //16个
wire [`PORT_NUM-1:0] empty; //16个

reg [2:0] state [`CROSSBAR_DIMENSION-1:0]; //4个
reg [1:0] RR [`CROSSBAR_DIMENSION-1:0]; //公平轮询寄存器
reg [`CROSSBAR_DIMENSION-1:0] node_col_rd_en;
reg [`DISPATCH_WIDTH-1:0] cross_col_fifo_dout [`CROSSBAR_DIMENSION-1:0];
reg [`DISPATCH_WIDTH-1:0] cb_col_dout [`CROSSBAR_DIMENSION-1:0];
reg [1:0] cb_col_fifo_sel [`CROSSBAR_DIMENSION-1:0];
/* |  4 ~ 2   |   1 ~ 0   | */
/* | priority | dest_port | */
reg [4:0] cb_col_queue_sel [`CROSSBAR_DIMENSION-1:0]; 
reg [`CROSSBAR_DIMENSION-1:0] cb_col_dat_valid;

assign o_cb_c1_queue_sel = cb_col_queue_sel[0];
assign o_cb_c2_queue_sel = cb_col_queue_sel[1];
assign o_cb_c3_queue_sel = cb_col_queue_sel[2];
assign o_cb_c4_queue_sel = cb_col_queue_sel[3];

assign o_cb_c1_dat_valid = cb_col_dat_valid[0];
assign o_cb_c2_dat_valid = cb_col_dat_valid[1];
assign o_cb_c3_dat_valid = cb_col_dat_valid[2];
assign o_cb_c4_dat_valid = cb_col_dat_valid[3];

assign o_cb_c1_dout = cb_col_dout[0];
assign o_cb_c2_dout = cb_col_dout[1];
assign o_cb_c3_dout = cb_col_dout[2];
assign o_cb_c4_dout = cb_col_dout[3];

//line 1
assign cross_node_din[0]  = (i_cb_l1_sel == 'd0) ? i_cb_l1_din : 'dz;
assign cross_node_din[1]  = (i_cb_l1_sel == 'd1) ? i_cb_l1_din : 'dz;
assign cross_node_din[2]  = (i_cb_l1_sel == 'd2) ? i_cb_l1_din : 'dz;
assign cross_node_din[3]  = (i_cb_l1_sel == 'd3) ? i_cb_l1_din : 'dz;

assign cross_node_wr_en[0]  = (i_cb_l1_sel == 'd0) ? i_cb_l1_wr_en : 'dz;
assign cross_node_wr_en[1]  = (i_cb_l1_sel == 'd1) ? i_cb_l1_wr_en : 'dz;
assign cross_node_wr_en[2]  = (i_cb_l1_sel == 'd2) ? i_cb_l1_wr_en : 'dz;
assign cross_node_wr_en[3]  = (i_cb_l1_sel == 'd3) ? i_cb_l1_wr_en : 'dz;

//line 2
assign cross_node_din[4]  = (i_cb_l2_sel == 'd0) ? i_cb_l2_din : 'dz;
assign cross_node_din[5]  = (i_cb_l2_sel == 'd1) ? i_cb_l2_din : 'dz;
assign cross_node_din[6]  = (i_cb_l2_sel == 'd2) ? i_cb_l2_din : 'dz;
assign cross_node_din[7]  = (i_cb_l2_sel == 'd3) ? i_cb_l2_din : 'dz;

assign cross_node_wr_en[4]  = (i_cb_l2_sel == 'd0) ? i_cb_l2_wr_en : 'dz;
assign cross_node_wr_en[5]  = (i_cb_l2_sel == 'd1) ? i_cb_l2_wr_en : 'dz;
assign cross_node_wr_en[6]  = (i_cb_l2_sel == 'd2) ? i_cb_l2_wr_en : 'dz;
assign cross_node_wr_en[7]  = (i_cb_l2_sel == 'd3) ? i_cb_l2_wr_en : 'dz;

//line 3
assign cross_node_din[8]  = (i_cb_l3_sel == 'd0) ? i_cb_l3_din : 'dz;
assign cross_node_din[9]  = (i_cb_l3_sel == 'd1) ? i_cb_l3_din : 'dz;
assign cross_node_din[10] = (i_cb_l3_sel == 'd2) ? i_cb_l3_din : 'dz;
assign cross_node_din[11] = (i_cb_l3_sel == 'd3) ? i_cb_l3_din : 'dz;

assign cross_node_wr_en[8]  = (i_cb_l3_sel == 'd0) ? i_cb_l3_wr_en : 'dz;
assign cross_node_wr_en[9]  = (i_cb_l3_sel == 'd1) ? i_cb_l3_wr_en : 'dz;
assign cross_node_wr_en[10] = (i_cb_l3_sel == 'd2) ? i_cb_l3_wr_en : 'dz;
assign cross_node_wr_en[11] = (i_cb_l3_sel == 'd3) ? i_cb_l3_wr_en : 'dz;

//line 4
assign cross_node_din[12] = (i_cb_l4_sel == 'd0) ? i_cb_l4_din : 'dz;
assign cross_node_din[13] = (i_cb_l4_sel == 'd1) ? i_cb_l4_din : 'dz;
assign cross_node_din[14] = (i_cb_l4_sel == 'd2) ? i_cb_l4_din : 'dz;
assign cross_node_din[15] = (i_cb_l4_sel == 'd3) ? i_cb_l4_din : 'dz;

assign cross_node_wr_en[12] = (i_cb_l4_sel == 'd0) ? i_cb_l4_wr_en : 'dz;
assign cross_node_wr_en[13] = (i_cb_l4_sel == 'd1) ? i_cb_l4_wr_en : 'dz;
assign cross_node_wr_en[14] = (i_cb_l4_sel == 'd2) ? i_cb_l4_wr_en : 'dz;
assign cross_node_wr_en[15] = (i_cb_l4_sel == 'd3) ? i_cb_l4_wr_en : 'dz;

//16个cross node
genvar i;
generate
    for (i = 0; i < 16; i=i+1) begin : cross_nodebuffer_inst
        cross_node_buffer cross_node_buffer_inst (
            .clk(i_clk),                  // input wire clk
            .srst(~i_rst_n),                // input wire srst
            .din(cross_node_din[i]),                  // input wire [31 : 0] din
            .wr_en(cross_node_wr_en[i]),              // input wire wr_en
            .rd_en(cross_node_rd_en[i]),              // input wire rd_en
            .dout(cross_node_dout[i]),                // output wire [31 : 0] dout
            .full(full[i]),                // output wire full
            .empty(empty[i])              // output wire empty
        );
    end
endgenerate

//select one of column-cross-node fifos
genvar k;
generate
    for (k = 0; k < 4; k = k + 1) begin: cross_col_fifo_dout_inst
        always @(*) begin
            if (~i_rst_n) begin
                cross_col_fifo_dout[k] = 'd0;
            end
            else begin
                cross_col_fifo_dout[k] = (cb_col_fifo_sel[k] == 'd0) ? cross_node_dout[k] :
                                          (cb_col_fifo_sel[k] == 'd1) ? cross_node_dout[4+k] :
                                          (cb_col_fifo_sel[k] == 'd2) ? cross_node_dout[8+k] : cross_node_dout[12+k];
            end
        end
    end
endgenerate

genvar j;
generate
    for (j = 0; j < 4; j = j + 1) begin: state_machine_fair_polling
        always @(posedge i_clk or negedge i_rst_n) begin
            if (!i_rst_n) begin
                state[j] <= 'd0;
                RR[j] <= 'd0; 
                cb_col_dout[j] <= 'd0;
                cb_col_queue_sel[j] <= 'd0;
                cb_col_fifo_sel[j] <= 'd0;
                cb_col_dat_valid[j] <= 1'b0;
                cross_node_rd_en[j] <= 1'b0; //每次轮询初始不读
                cross_node_rd_en[j+4] <= 1'b0; //每次轮询初始不读
                cross_node_rd_en[j+8] <= 1'b0; //每次轮询初始不读
                cross_node_rd_en[j+12] <= 1'b0;
            end
            else begin
                cb_col_queue_sel[j] <= cb_col_queue_sel[j];
                cb_col_fifo_sel[j] <= cb_col_fifo_sel[j];
                cb_col_dout[j] <= cb_col_dout[j];
                cross_node_rd_en[j] <= 1'b0; //每次轮询初始不读
                cross_node_rd_en[j+4] <= 1'b0; //每次轮询初始不读
                cross_node_rd_en[j+8] <= 1'b0; //每次轮询初始不读
                cross_node_rd_en[j+12] <= 1'b0; //每次轮询初始不读
                cb_col_dat_valid[j] <= 1'b0; //输出有效
                case (state[j])
                    'd0: begin //决定轮询顺序
                        case (RR[j])
                            'd0: begin
                                if (~empty[j]) begin
                                    cb_col_fifo_sel[j] <= 'd0;
                                    cross_node_rd_en[j] <= 1'b1; //拉高使能
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+4]) begin
                                    cb_col_fifo_sel[j] <= 'd1;
                                    cross_node_rd_en[j+4] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+8]) begin
                                    cb_col_fifo_sel[j] <= 'd2;
                                    cross_node_rd_en[j+8] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+12]) begin
                                    cb_col_fifo_sel[j] <= 'd3;
                                    cross_node_rd_en[j+12] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else begin
                                    state[j] <= 'd0; //考虑边界情况，如果四个fifo都是空的，则一直困在此状态
                                end
                            end 
                            'd1: begin
                                if (~empty[j+4]) begin
                                    cb_col_fifo_sel[j] <= 'd1;
                                    cross_node_rd_en[j+4] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+8]) begin
                                    cb_col_fifo_sel[j] <= 'd2;
                                    cross_node_rd_en[j+8] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+12]) begin
                                    cb_col_fifo_sel[j] <= 'd3;
                                    cross_node_rd_en[j+12] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j]) begin
                                    cb_col_fifo_sel[j] <= 'd0;
                                    cross_node_rd_en[j] <= 1'b1; //拉高使能
                                    state[j] <= 'd1;
                                end
                                else begin
                                    state[j] <= 'd0;
                                end
                            end 
                            'd2: begin
                                if (~empty[j+8]) begin
                                    cb_col_fifo_sel[j] <= 'd2;
                                    cross_node_rd_en[j+8] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+12]) begin
                                    cb_col_fifo_sel[j] <= 'd3;
                                    cross_node_rd_en[j+12] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j]) begin
                                    cb_col_fifo_sel[j] <= 'd0;
                                    cross_node_rd_en[j] <= 1'b1; //拉高使能
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+4]) begin
                                    cb_col_fifo_sel[j] <= 'd1;
                                    cross_node_rd_en[j+4] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else begin
                                    state[j] <= 'd0;
                                end
                            end 
                            'd3: begin
                                if (~empty[j+12]) begin
                                    cb_col_fifo_sel[j] <= 'd3;
                                    cross_node_rd_en[j+12] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j]) begin
                                    cb_col_fifo_sel[j] <= 'd0;
                                    cross_node_rd_en[j] <= 1'b1; //拉高使能
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+4]) begin
                                    cb_col_fifo_sel[j] <= 'd1;
                                    cross_node_rd_en[j+4] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else if (~empty[j+8]) begin
                                    cb_col_fifo_sel[j] <= 'd2;
                                    cross_node_rd_en[j+8] <= 1'b1;
                                    state[j] <= 'd1;
                                end
                                else begin
                                    state[j] <= 'd0;
                                end
                            end
                        endcase    
                    end
                    'd1: begin
                        RR[j] <= RR[j] + 1'b1; //轮询参数加1
                        state[j] <= 'd2;
                    end 
                    'd2: begin //出crossbar
                                                        //priority                   //dest_port
                        cb_col_queue_sel[j] <= {cross_col_fifo_dout[j][6:4], cross_col_fifo_dout[j][1:0]};
                        cb_col_dout[j] <= cross_col_fifo_dout[j]; //fifo数据寄存一拍输出
                        cb_col_dat_valid[j] <= 1'b1; //输出有效
                        state[j] <= 'd0;
                    end
                endcase
            end
        end
    end
endgenerate

endmodule
