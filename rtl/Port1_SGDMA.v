`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/10 20:43:57
// Design Name: 
// Module Name: defines
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: global defines
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module Port1_SGDMA (
    input                           i_clk,
    input                           i_rst_n,
    output                          o_rd_en,
    input     [`DATA_WIDTH-1:0]     i_dat,
    input                           i_empty,
    input                           i_sop, //TODO:sop和eop需要和fifo读出同步,和rd_en&
    input                           i_eop
);

reg [3:0] state;
reg fifo_rd_en;

/* | 17 ~ 7 |  6 ~ 4   |   3 ~ 0   | */
/* | length | priority | dest_port | */
reg [`DATA_WIDTH-1:0] pack_head;
reg [`DATA_WIDTH-1:0] pack_dat;
reg [3:0] dest_port;
reg [10:0] length;
reg [7:0] unit_cnt, cnt_temp;
reg [`ADDR_WIDTH-1:0] first_unit_addr;

//crossbar buffer defines
wire [31:0] cb11_din, cb12_din, cb13_din, cb14_din;
wire cb11_wr_en, cb11_rd_en, cb12_wr_en, cb12_rd_en, cb13_rd_en, cb13_wr_en, cb14_wr_en, cb14_rd_en;
wire [31:0] cb11_dout, cb12_dout, cb13_dout, cb14_dout;
wire cb_full, cb11_full, cb11_empty, cb12_empty, cb12_full, cb13_full, cb13_empty, cb14_full, cb14_empty;

reg [3:0] sel;
reg [31:0] cb_din;
reg cb_wr_en, cb_rd_en;
// wire [31:0] cb_dout;
wire cb_empty;

assign o_rd_en = fifo_rd_en;

assign cb11_din = (sel == 'd0) & cb_din;
assign cb12_din = (sel == 'd1) & cb_din;
assign cb13_din = (sel == 'd2) & cb_din;
assign cb14_din = (sel == 'd3) & cb_din;

assign cb11_wr_en = (sel == 'd0) & cb_wr_en;
assign cb12_wr_en = (sel == 'd1) & cb_wr_en;
assign cb13_wr_en = (sel == 'd2) & cb_wr_en;
assign cb14_wr_en = (sel == 'd3) & cb_wr_en;

assign cb_full = (sel == 'd0) ? cb11_full : 
                 (sel == 'd1) ? cb12_full : 
                 (sel == 'd2) ? cb13_full : cb14_full;/*TODO*/

//mmu write defines
reg mmu_wr_req; //写请求
wire mmu_wr_ready;
reg [`ADDR_WIDTH-1:0] mmu_wr_addr;
reg [`DATA_WIDTH-1:0] mmu_wr_dat;

//free pointer list defines
reg [`ADDR_WIDTH-1:0] free_ptr_din;
reg fp_wr_en, fp_rd_en;
wire [`ADDR_WIDTH-1:0] free_ptr_dout;
wire fp_list_full, fp_list_empty, fp_list_almost_empty;

/*TODO: 如何描述一个包存储的指针链表，用一个变量表示，数据从哪出来*/

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        /*初始化*/
        fifo_rd_en <= 1'b0;
        pack_head <= 'd0;
        dest_port <= 'd0;
        length <= 'd0;
        unit_cnt <= 'd0;
        state <= 'd1;
        cb_wr_en <= 1'b0;
        cb_din <= 'd0;
        sel <= 'd0;
        fp_rd_en <= 1'b0;
        cnt_temp <= 'd0;
    end
    else begin 
        case (state)
            //开始读取输入fifo的数据
            'd1: begin
                if (!i_empty) begin
                    fifo_rd_en <= 1'b1;
                    state <= 'd2;                    
                end
            end
            'd2: begin
                //pack_head <= i_dat; //取到包头
                sel <= i_dat[3:0]; //目的端口号用于选择crossbar buffer
                unit_cnt <= i_dat[17:7] >> 3 + 1'b1; //包长度(可能不准确验证一下)
                cnt_temp <= i_dat[17:7] >> 3 + 1'b1; //取到第一个信元数据
                /*TODO:包长度给地址生成模块,用于填充freelist*/

                /*读空闲指针链表*/
                if (!fp_list_empty) begin
                    fp_rd_en <= 1'b1;
                end
                state <= 'd3;
            end
            'd3: begin //读取数据，组织转发帧
                fp_rd_en <= 1'b0; //非连续读取
                mmu_wr_addr <= free_ptr_dout; //写入指定地址（free_ptr_dout从free_list中取到）
                mmu_wr_dat <= i_dat; //写入数据
                mmu_wr_req <= 1'b1; //写入请求
                fifo_rd_en <= 1'b0; //fifo读取暂停一周期用于判断ready
                state <= 'd4;
                //pack_dat <= i_dat; //读取包数据
                if (unit_cnt == cnt_temp) begin //取到第一个信元数据的地址
                    first_unit_addr <= free_ptr_dout;
                end
            end
            'd4: begin
                if (mmu_wr_ready & (~i_empty)) begin //ready拉高后开始读取下一帧
                    fifo_rd_en <= 1'b1;
                    fp_rd_en <= (unit_cnt == 'd1) ? 1'b0 : 1'b1; //最后一次不要拉高，不然会和下一包传输冲突
                    unit_cnt <= unit_cnt - 1'b1;
                end
                mmu_wr_req <= 1'b0; //两周期一次包存储
                //包存储完跳到状态5，否则一直循环34
                if (unit_cnt == 'd1) begin
                    state <= 'd2; //直接跳过1去2
                    /*转发调度:状态机里读写用同一组信号，同时组合逻辑判断写入哪个buffer*/
                    if (!cb_full) begin
                        cb_wr_en <= 1'b1; //crossbar buffer写使能
                        cb_din <= {{7{0}}, cnt_temp, first_unit_addr};//存储完最后一个信元发送包调度数据
                    end
                end
                else begin
                    state <= 'd3;
                end
            end
        endcase
    end
end

//存储指针FIFO 16个 宽度和深度待定,暂时32位
crossbar_buffer crossbar_buf_11 (
  .clk(i_clk),      // input wire clk
  .srst(~i_rst_n),    // input wire srst
  .din(cb11_din),      // input wire [31 : 0] din
  .wr_en(cb11_wr_en),  // input wire wr_en
  .rd_en(cb11_rd_en),  // input wire rd_en
  .dout(cb11_dout),    // output wire [31 : 0] dout
  .full(cb11_full),    // output wire full
  .empty(cb11_empty)  // output wire empty
);

crossbar_buffer crossbar_buf_12 (
  .clk(i_clk),      // input wire clk
  .srst(~i_rst_n),    // input wire srst
  .din(cb12_din),      // input wire [31 : 0] din
  .wr_en(cb12_wr_en),  // input wire wr_en
  .rd_en(cb12_rd_en),  // input wire rd_en
  .dout(cb12_dout),    // output wire [31 : 0] dout
  .full(cb12_full),    // output wire full
  .empty(cb12_empty)  // output wire empty
);

crossbar_buffer crossbar_buf_13 (
  .clk(i_clk),      // input wire clk
  .srst(~i_rst_n),    // input wire srst
  .din(cb13_din),      // input wire [31 : 0] din
  .wr_en(cb13_wr_en),  // input wire wr_en
  .rd_en(cb13_rd_en),  // input wire rd_en
  .dout(cb13_dout),    // output wire [31 : 0] dout
  .full(cb13_full),    // output wire full
  .empty(cb13_empty)  // output wire empty
);

crossbar_buffer crossbar_buf_14 (
  .clk(i_clk),      // input wire clk
  .srst(~i_rst_n),    // input wire srst
  .din(cb14_din),      // input wire [31 : 0] din
  .wr_en(cb14_wr_en),  // input wire wr_en
  .rd_en(cb14_rd_en),  // input wire rd_en
  .dout(cb14_dout),    // output wire [31 : 0] dout
  .full(cb14_full),    // output wire full
  .empty(cb14_empty)  // output wire empty
);

//自由指针FIFO  宽度和深度待定 如何补充free pointer?
free_ptr_list free_ptr_list_inst (
  .clk(i_clk),                    // input wire clk
  .srst(~i_rst_n),                  // input wire srst
  .din(free_ptr_din),                    // input wire [31 : 0] din
  .wr_en(fp_wr_en),                // input wire wr_en
  .rd_en(fp_rd_en),                // input wire rd_en
  .dout(free_ptr_dout),                  // output wire [31 : 0] dout
  .full(fp_list_full),                  // output wire full
  .empty(fp_list_empty),                // output wire empty
  .almost_empty(fp_list_almost_empty)  // output wire almost_empty
);

endmodule