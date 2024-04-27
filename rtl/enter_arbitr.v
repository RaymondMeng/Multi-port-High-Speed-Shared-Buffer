`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// team: 极链缘起 
// Engineer: mengcheng
// 
// Create Date: 2024/03/10 20:37:21
// Design Name: high speed multi-port shared buffer
// Module Name: enter_arbitr
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: read four fifo data cyclically
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:  need verification
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module enter_arbitr(
    input                                           clk,      
    input                                           rst_n,  

    /*fifo1 interface*/
    input                                           i_fifo1_empty,
    input               [`DATA_WIDTH-1:0]           i_fifo1_data,
    output                                          o_fifo1_rd_en,

    /*fifo2 interface*/
    input                                           i_fifo2_empty,
    input               [`DATA_WIDTH-1:0]           i_fifo2_data,
    output                                          o_fifo2_rd_en,

    /*fifo3 interface*/
    input                                           i_fifo3_empty,
    input               [`DATA_WIDTH-1:0]           i_fifo3_data,
    output                                          o_fifo3_rd_en,

    /*fifo4 interface*/
    input                                           i_fifo4_empty,
    input               [`DATA_WIDTH-1:0]           i_fifo4_data,
    output                                          o_fifo4_rd_en,

    /*DataBuffer fifo interface*/
    input                                           i_DBfifo_rd_en,
    output                                          o_DBfifo_empty,
    output              [`DATA_WIDTH-1:0]           o_DBfifo_data

    // /*serial data output control*/
    // output              [`DATA_WIDTH-1:0]           o_sdata,
    // output                                          o_data_valid
    );

reg [10:0] dat_num; //单位是字节


`ifdef PACKET_SWITCH

reg [2:0] state;
reg [1:0] RR; //公平轮询寄存器
parameter IDLE = 3'b100, s0 = 3'b000, s1 = 3'b001, s2 = 3'b011, s3 = 3'b010, s4 = 3'b110, s5 = 3'b111;

wire [`DATA_WIDTH-1:0] i_fifo_data;
reg fifo_rd_en;
reg [7:0] unit_cnt; //最多128个64位信元
reg [1:0] sel; //片选 ，选择哪个fifo读
reg [`DATA_WIDTH-1:0] sdata;
reg sdata_wr_en, ptr_wr_en;

// reg [`DATA_WIDTH/4-1:0] ptr_dat; //16位指针
// reg [`DATA_WIDTH/4-1:0] ptr_dat_temp; //16位指针临时变量

reg [`DATA_WIDTH-1:0]   DBfifo_din;

/* | 17 ~ 7 |  6 ~ 4   |   3 ~ 0   | */
/* | length | priority | dest_port | */
reg [`DATA_WIDTH-1:0]   pkg_head; 

/* | 18 ~ 15 | 14 ~ 7 |  6 ~ 4   |  3 ~ 0    | */
/* | in_port | length | priority | dest_port | */
/*           64bit nums                        */
wire [`DATA_WIDTH-1:0]   pkg_head_update; //更新之后的包头数据结构

wire DBfifo_full, DBfifo_almost_full;
reg DBfifo_wr_en;

//直接一段式
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        state <= s0;
        RR <= 'd0;
        sdata_wr_en <= 1'b0;
    end
    else begin
        case (state)
            s0: begin //决定轮询顺序
                case (RR)
                    2'd0: begin
                        if (~i_fifo1_empty) begin //从fifo1开始轮询
                            sel <= 'd0; //选中第一个FIFO
                            fifo_rd_en <= 1'b1; //读使能拉高
                            state <= s1; //跳转s1
                        end
                        else if (~i_fifo2_empty) begin
                            sel <= 'd1;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo3_empty) begin
                            sel <= 'd2;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo4_empty) begin
                            sel <= 'd3;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                    end
                    2'd1: begin
                        if (~i_fifo2_empty) begin
                            sel <= 'd1;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo3_empty) begin
                            sel <= 'd2;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo4_empty) begin
                            sel <= 'd3;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo1_empty) begin //从fifo1开始轮询
                            sel <= 'd0; //选中第一个FIFO
                            fifo_rd_en <= 1'b1; //读使能拉高
                            state <= s1; //跳转s1
                        end
                    end
                    2'd2: begin
                        if (~i_fifo3_empty) begin
                            sel <= 'd2;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo4_empty) begin
                            sel <= 'd3;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo1_empty) begin //从fifo1开始轮询
                            sel <= 'd0; //选中第一个FIFO
                            fifo_rd_en <= 1'b1; //读使能拉高
                            state <= s1; //跳转s1
                        end
                        else if (~i_fifo2_empty) begin
                            sel <= 'd1;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                    end
                    2'd3: begin
                        if (~i_fifo4_empty) begin
                            sel <= 'd3;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo1_empty) begin //从fifo1开始轮询
                            sel <= 'd0; //选中第一个FIFO
                            fifo_rd_en <= 1'b1; //读使能拉高
                            state <= s1; //跳转s1
                        end
                        else if (~i_fifo2_empty) begin
                            sel <= 'd1;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                        else if (~i_fifo3_empty) begin
                            sel <= 'd2;
                            fifo_rd_en <= 1'b1;
                            state <= s1;
                        end
                    end
                endcase
            end
            s1: begin //轮询参数变化
                RR <= RR + 1;
                state <= s2;
            end
            /* 开始读包数据 */
            s2: begin //读包头更改数据写入databuffer  这里可能时序不太好，仿真看看如果不行继续拆分状态
                pkg_head <= i_fifo_data;
                unit_cnt <= i_fifo_data[17:7] >> 3;//包中64bit信元的个数
                //pkg_head_update <= {, i_fifo_data[17:7] >> 3, i_fifo_data[6:0]};
                if (~DBfifo_full) begin //写入包头进databuffer
                    DBfifo_wr_en <= 1'b1; //写入data buffer fifo使能
                    DBfifo_din <= pkg_head_update; //data buffer fifo寄存数据
                end
                state <= s3;
            end
            s3: begin //循环读包数据并写入databuffer
                if (unit_cnt == 'd2) begin //读完包的倒数第二个信元，跳入下个状态
                    state <= s4;
                end
                unit_cnt <= unit_cnt - 1'b1;
                if (~DBfifo_full) begin
                    DBfifo_wr_en <= 1'b1; //写入data buffer fifo使能
                    DBfifo_din <= i_fifo_data; //data buffer fifo寄存数据
                end
            end
            s4: begin //读最后一个数据，关闭fifo读取
                unit_cnt <= unit_cnt - 1'b1; //dat_num结果为0
                if (~DBfifo_full) begin
                    DBfifo_wr_en <= 1'b1;
                    DBfifo_din <= i_fifo_data;
                end
                fifo_rd_en <= 1'b0; //关闭fifo读取使能
                state <= s5;
            end
            s5: begin //关闭db fifo写使能
                DBfifo_wr_en <= 1'b0; //关闭data buffer fifo写使能
                state <= s0;
            end
        endcase
    end
end

//这里可能时序不太好，仿真看看如果不行继续拆分状态
assign pkg_head_update = {sel, unit_cnt, i_fifo_data[6:0]};

port_input_fifo data_buffer_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(DBfifo_din),                  // input wire [63 : 0] din
  .wr_en(DBfifo_wr_en),              // input wire wr_en
  .rd_en(i_DBfifo_rd_en),              // input wire rd_en
  .dout(o_DBfifo_data),                // output wire [63 : 0] dout
  .full(DBfifo_full),                // output wire full
  .almost_full(DBfifo_almost_full),  // output wire almost_full
  .empty(o_DBfifo_empty)              // output wire empty
);

assign o_fifo1_rd_en = fifo_rd_en & (sel == 'd0);
assign o_fifo2_rd_en = fifo_rd_en & (sel == 'd1);
assign o_fifo3_rd_en = fifo_rd_en & (sel == 'd2);
assign o_fifo4_rd_en = fifo_rd_en & (sel == 'd3);

assign i_fifo_data = (sel == 'd0) ? i_fifo1_data :
                     (sel == 'd1) ? i_fifo2_data :
                     (sel == 'd2) ? i_fifo3_data : i_fifo4_data;




`endif

endmodule
