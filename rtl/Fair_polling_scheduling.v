`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/13 18:01:59
// Design Name: 
// Module Name: Fair_polling_scheduling
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: including schedule fifo and 4 -> 1 fair polling
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module Fair_polling_scheduling(
    input                                       i_clk,
    input                                       i_rst_n,
    /*schedule fifo interface*/
    input         [`DISPATCH_WIDTH-1 : 0]       i_schedule_fifo1_din,
    input                                       i_schedule_fifo1_wr_en,
    output                                      o_schedule_fifo1_full,

    input         [`DISPATCH_WIDTH-1 : 0]       i_schedule_fifo2_din,
    input                                       i_schedule_fifo2_wr_en,
    output                                      o_schedule_fifo2_full,

    input         [`DISPATCH_WIDTH-1 : 0]       i_schedule_fifo3_din,
    input                                       i_schedule_fifo3_wr_en,
    output                                      o_schedule_fifo3_full,

    input         [`DISPATCH_WIDTH-1 : 0]       i_schedule_fifo4_din,
    input                                       i_schedule_fifo4_wr_en,
    output                                      o_schedule_fifo4_full,
    /*crossbar interface*/
    output                                      o_cb_wr_en,
    output        [`DISPATCH_WIDTH-1 : 0]       o_cb_din,
    output        [1 : 0]                       o_cb_sel
    );

//fair polling
reg [1:0] schedule_fifo_sel;
reg sf_rd_en;
wire [`DISPATCH_WIDTH-1:0] sf_dout;
wire sf1_rd_en, sf2_rd_en, sf3_rd_en, sf4_rd_en;
wire [`DISPATCH_WIDTH-1:0] sf1_dout, sf2_dout, sf3_dout, sf4_dout;
wire sf1_empty, sf2_empty, sf3_empty, sf4_empty;

reg [2:0] state;
reg [1:0] RR; //公平轮询寄存器

reg cb_wr_en;
reg [`DISPATCH_WIDTH-1:0] cb_din;
reg [1:0] cb_sel;

assign o_cb_sel = cb_sel;
assign o_cb_din = cb_din;
assign o_cb_wr_en = cb_wr_en;


//schedule fifo
schedule_fifo schedule_fifo1 (
  .clk(i_clk),                  // input wire clk
  .srst(~i_rst_n),                // input wire srst
  .din(i_schedule_fifo1_din),                  // input wire [31 : 0] din
  .wr_en(i_schedule_fifo1_wr_en),              // input wire wr_en
  .rd_en(sf1_rd_en),              // input wire rd_en
  .dout(sf1_dout),                // output wire [31 : 0] dout
  .full(o_schedule_fifo1_full),                // output wire full
  .empty(sf1_empty)              // output wire empty
);

schedule_fifo schedule_fifo2 (
  .clk(i_clk),                  // input wire clk
  .srst(~i_rst_n),                // input wire srst
  .din(i_schedule_fifo2_din),                  // input wire [31 : 0] din
  .wr_en(i_schedule_fifo2_wr_en),              // input wire wr_en
  .rd_en(sf2_rd_en),              // input wire rd_en
  .dout(sf2_dout),                // output wire [31 : 0] dout
  .full(o_schedule_fifo2_full),                // output wire full
  .empty(sf2_empty)              // output wire empty
);

schedule_fifo schedule_fifo3 (
  .clk(i_clk),                  // input wire clk
  .srst(~i_rst_n),                // input wire srst
  .din(i_schedule_fifo3_din),                  // input wire [31 : 0] din
  .wr_en(i_schedule_fifo3_wr_en),              // input wire wr_en
  .rd_en(sf3_rd_en),              // input wire rd_en
  .dout(sf3_dout),                // output wire [31 : 0] dout
  .full(o_schedule_fifo3_full),                // output wire full
  .empty(sf3_empty)              // output wire empty
);

schedule_fifo schedule_fifo4 (
  .clk(i_clk),                  // input wire clk
  .srst(~i_rst_n),                // input wire srst
  .din(i_schedule_fifo4_din),                  // input wire [31 : 0] din
  .wr_en(i_schedule_fifo4_wr_en),              // input wire wr_en
  .rd_en(sf4_rd_en),              // input wire rd_en
  .dout(sf4_dout),                // output wire [31 : 0] dout
  .full(o_schedule_fifo4_full),                // output wire full
  .empty(sf4_empty)              // output wire empty
);

assign sf_dout = (schedule_fifo_sel == 'd0) ? sf1_dout :
                 (schedule_fifo_sel == 'd1) ? sf2_dout :
                 (schedule_fifo_sel == 'd2) ? sf3_dout : sf4_dout;

assign sf1_rd_en = (schedule_fifo_sel == 'd0) && sf_rd_en;
assign sf2_rd_en = (schedule_fifo_sel == 'd1) && sf_rd_en;
assign sf3_rd_en = (schedule_fifo_sel == 'd2) && sf_rd_en;
assign sf4_rd_en = (schedule_fifo_sel == 'd3) && sf_rd_en;


always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state <= 'd0;
        RR <= 'd0; 
        sf_rd_en <= 1'b0;
        cb_wr_en <= 1'b0;
        cb_din <= 'd0;
        cb_sel <= 'd0;
        schedule_fifo_sel <= 'd0;
    end
    else begin
        case (state)
            'd0: begin //决定轮询顺序
                cb_wr_en <= 1'b0; //每次轮询初始不写
                sf_rd_en <= 1'b0; //每次轮询初始不读
                schedule_fifo_sel <= schedule_fifo_sel;
                case (RR)
                    'd0: begin
                        if (~sf1_empty) begin
                            schedule_fifo_sel <= 'd0;//选中第一个sf
                            sf_rd_en <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~sf2_empty) begin
                            schedule_fifo_sel <= 'd1;
                            sf_rd_en <= 1'b1;
                            state <= 'd1;
                        end
                        else if (~sf3_empty) begin
                            schedule_fifo_sel <= 'd2;
                            sf_rd_en <= 1'b1;
                            state <= 'd1;
                        end
                        else if (~sf4_empty) begin
                            schedule_fifo_sel <= 'd3;
                            sf_rd_en <= 1'b1;
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果四个fifo都是空的，则一直困在此状态
                        end
                    end 
                    'd1: begin
                        if (~sf2_empty) begin//选中第二个sf
                            schedule_fifo_sel <= 'd1;
                            sf_rd_en <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~sf3_empty) begin
                            schedule_fifo_sel <= 'd2;
                            sf_rd_en <= 1'b1;
                            state <= 'd1;
                        end
                        else if (~sf4_empty) begin
                            schedule_fifo_sel <= 'd3;
                            sf_rd_en <= 1'b1;
                            state <= 'd1;
                        end
                        else if (~sf1_empty) begin
                            schedule_fifo_sel <= 'd0;
                            sf_rd_en <= 1'b1; 
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0;
                        end
                    end 
                    'd2: begin
                        if (~sf3_empty) begin//选中第三个sf
                            schedule_fifo_sel <= 'd2;
                            sf_rd_en <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~sf4_empty) begin
                            schedule_fifo_sel <= 'd3;
                            sf_rd_en <= 1'b1;
                            state <= 'd1;
                        end
                        else if (~sf1_empty) begin
                            schedule_fifo_sel <= 'd0;
                            sf_rd_en <= 1'b1; 
                            state <= 'd1;
                        end
                        else if (~sf2_empty) begin
                            schedule_fifo_sel <= 'd1;
                            sf_rd_en <= 1'b1; 
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0;
                        end
                    end 
                    'd3: begin
                        if (~sf4_empty) begin
                            schedule_fifo_sel <= 'd3;//选中第四个sf
                            sf_rd_en <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~sf1_empty) begin
                            schedule_fifo_sel <= 'd0;
                            sf_rd_en <= 1'b1; 
                            state <= 'd1;
                        end
                        else if (~sf2_empty) begin
                            schedule_fifo_sel <= 'd1;
                            sf_rd_en <= 1'b1; 
                            state <= 'd1;
                        end
                        else if (~sf3_empty) begin
                            schedule_fifo_sel <= 'd2;
                            sf_rd_en <= 1'b1; 
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0;
                        end
                    end
                endcase    
            end
            'd1: begin
                RR <= RR + 1'b1; //轮询参数加1
                sf_rd_en <= 1'b0; //每次只读一个数据
                state <= 'd2;
            end 
            'd2: begin //开始读数据包并且开始写入corssbar
                casez (sf_dout[3:0])
                    4'b00zz: cb_sel <= 'd0;
                    4'b01zz: cb_sel <= 'd1;
                    4'b10zz: cb_sel <= 'd2;
                    4'b11zz: cb_sel <= 'd3; 
                endcase
                // cb_sel <= sf_dout[3:0]; //选中crossbar交叉节点
                cb_din <= sf_dout;
                cb_wr_en <= 1'b1; //写使能
                state <= 'd0;
            end
        endcase
    end
end

endmodule
