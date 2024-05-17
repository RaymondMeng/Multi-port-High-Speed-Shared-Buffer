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
// Dependencies: 从输入FIFO中读取数据，并且读取freelist中的空闲地址，将包数据存入sram中，并且将包调度数据送入crossbar中调度
//               cnt包信元计数√、包与包之间的衔接√、crossbar发送、边界情况（如果fifo空或者满，状态如何跳转）
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.0 - finish basic function 2024.5.17
// Additional Comments: 该模块实现存储器的接口主要是request-ready形式，request和addr和data一同输入，
//                      下一周期ready响应，并且写入下一个数据的请求，如果ready被拉低则传输
//                      上一周期相同的地址和数据
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
    input                           i_eop, //这个需不需要？

    /*crossbar interface*/
    output    [`DISPATCH_WIDTH-1:0] o_cb_din,
    output                          o_cb_wr_en,
    input                           i_cb_full,     

    // output    [`DISPATCH_WIDTH-1:0] o_cb12_din,
    // output                          o_cb12_wr_en,
    // input                           i_cb12_full,

    // output    [`DISPATCH_WIDTH-1:0] o_cb13_din,
    // output                          o_cb13_wr_en,
    // input                           i_cb13_full,

    // output    [`DISPATCH_WIDTH-1:0] o_cb14_din,
    // output                          o_cb14_wr_en,
    // input                           i_cb14_full,    

    /*mmu interface*/
    output                          o_mmu_wr_req,
    output    [`ADDR_WIDTH-1:0]     o_mmu_wr_addr,
    output    [`DATA_WIDTH-1:0]     o_mmu_wr_dat,
    input                           i_mmu_wr_ready
);

reg [3:0] state;
reg fifo_rd_en;

/* | 17 ~ 7 |  6 ~ 4   |   3 ~ 0   | */
/* | length | priority | dest_port | */
reg [`DATA_WIDTH-1:0] pack_head;
//reg [3:0] dest_port;
//reg [10:0] length;
reg [7:0] unit_cnt, cnt_temp;
reg [`ADDR_WIDTH-1:0] first_unit_addr;
reg [`DATA_WIDTH-1:0] unit_pre_1_dat, unit_pre_2_dat, unit_pre_3_dat; //定义第n-1,n-2,n-3个数据

//crossbar buffer defines
reg [3:0] sel;
reg [`DISPATCH_WIDTH-1:0] cb_din;
reg cb_wr_en;
wire cb_full;
wire [`DISPATCH_WIDTH-1:0] cb_dat;

assign cb_dat = {first_unit_addr, cnt_temp, pack_head[6:0]}; //crossbar32位包调度数据
assign o_rd_en = fifo_rd_en;

// assign o_cb11_din = (sel == 'd0) & cb_din;
// assign o_cb12_din = (sel == 'd1) & cb_din;
// assign o_cb13_din = (sel == 'd2) & cb_din;
// assign o_cb14_din = (sel == 'd3) & cb_din;
// assign o_cb11_wr_en = (sel == 'd0) & cb_wr_en;
// assign o_cb12_wr_en = (sel == 'd1) & cb_wr_en;
// assign o_cb13_wr_en = (sel == 'd2) & cb_wr_en;
// assign o_cb14_wr_en = (sel == 'd3) & cb_wr_en;
// assign cb_full = (sel == 'd0) ? i_cb11_full : 
//                  (sel == 'd1) ? i_cb12_full : 
//                  (sel == 'd2) ? i_cb13_full : i_cb14_full;/*TODO*/

assign o_cb_din = cb_din;
assign o_cb_wr_en = cb_wr_en;
assign cb_full = i_cb_full;

//mmu write defines
reg mmu_wr_req; //写请求
wire mmu_wr_ready;
reg [`ADDR_WIDTH-1:0] mmu_wr_addr, mmu_wr_addr_reg;
reg [`DATA_WIDTH-1:0] o_mmu_wr_dat_reg, mmu_wr_dat, mmu_pre_1_dat;

assign o_mmu_wr_addr = mmu_wr_addr_reg;
assign o_mmu_wr_dat = o_mmu_wr_dat_reg; //改，根据ready信号写
assign o_mmu_wr_req = mmu_wr_req;
assign mmu_wr_ready = i_mmu_wr_ready;

//free pointer list defines
reg [`ADDR_WIDTH-1:0] free_ptr_din;
reg fp_wr_en, fp_rd_en, init_vld;
reg [`ADDR_WIDTH-1:0] fp_pre_1_dat, fp_pre_2_dat, fp_pre_3_dat;
wire [`ADDR_WIDTH-1:0] free_ptr_dout;
wire fp_list_full, fp_list_empty, fp_list_almost_empty;

always @(*) begin
    if (!i_rst_n) begin
        o_mmu_wr_dat_reg = 'd0;
    end
    else begin
        o_mmu_wr_dat_reg = (mmu_wr_ready || (state == 'd4)) ? mmu_wr_dat : o_mmu_wr_dat_reg;
    end
end

always @(*) begin
    if (!i_rst_n) begin
        mmu_wr_addr_reg = 'd0;
    end
    else begin
        mmu_wr_addr_reg = (mmu_wr_ready || (state == 'd4)) ? mmu_wr_addr : mmu_wr_addr_reg;
    end
end

/*TODO: cnt包信元计数√、包与包之间的衔接√、crossbar发送、边界情况（如果fifo空或者满，状态如何跳转）*/
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        /*初始化*/
        fifo_rd_en <= 1'b0;
        pack_head <= 'd0;
        //dest_port <= 'd0;
        //length <= 'd0;
        unit_cnt <= 'd0;
        state <= 'd1;
        cb_wr_en <= 1'b0;
        cb_din <= 'd0;
        //sel <= 'd0;
        fp_rd_en <= 1'b0;
        cnt_temp <= 'd0;
        first_unit_addr <= 'd0;
        mmu_wr_addr <= 'd0;
        mmu_wr_dat <= 'd0; //数据写入用组合
        mmu_wr_req <= 1'b0;
        unit_pre_1_dat <= 'd0;
        unit_pre_2_dat <= 'd0;
        fp_pre_1_dat <= 'd0;
        fp_pre_2_dat <= 'd0;
    end
    else begin 
        if (fifo_rd_en) begin
            /*寄存三个周期数据*/
            unit_pre_1_dat <= i_dat; //第n-1个数据
            unit_pre_2_dat <= unit_pre_1_dat; //第n-2个数据
            /*寄存三周期地址*/
            fp_pre_1_dat <= free_ptr_dout; //写入指定地址（free_ptr_dout从free_list中取到）第n-1个数据
            fp_pre_2_dat <= fp_pre_1_dat; //第n-2个数据
        end
        else begin
            /*寄存三个周期数据*/
            unit_pre_1_dat <= unit_pre_1_dat; //第n-1个数据
            unit_pre_2_dat <= unit_pre_2_dat; //第n-2个数据
            //unit_pre_3_dat <= unit_pre_3_dat; //第n-3个数据
            /*寄存三周期地址*/
            fp_pre_1_dat <= fp_pre_1_dat; //写入指定地址（free_ptr_dout从free_list中取到）第n-1个数据
            fp_pre_2_dat <= fp_pre_2_dat; //第n-2个数据
        end
        cnt_temp <= cnt_temp;
        pack_head <= pack_head;
        first_unit_addr <= first_unit_addr;
        mmu_wr_req <= 1'b0;
        case (state)
            //开始读取输入fifo的数据
            'd1: begin
                fifo_rd_en <= (i_empty|fp_list_empty) ? 1'b0 : 1'b1;
                fp_rd_en <= (i_empty|fp_list_empty) ? 1'b0 : 1'b1; //读取freeptr
                state <= (i_empty|fp_list_empty) ? 'd1 : 'd2;
            end
            'd2: begin
                state <= 'd3;
                /*读空闲指针链表*/
                /*TODO:包长度给地址生成模块,用于填充freelist*/
            end
            'd3: begin //包头写入mmu
                pack_head <= i_dat; //取到包头
                //sel <= i_dat[3:0]; //目的端口号用于选择crossbar buffer
                unit_cnt <= (i_dat[17:7] >> 3) + 1'b1; //包长度(可能不准确验证一下)
                cnt_temp <= (i_dat[17:7] >> 3) + 1'b1; //注意符号优先级
                first_unit_addr <= free_ptr_dout;
                //mmu write
                mmu_wr_dat <= i_dat; //写入数据
                mmu_wr_addr <= free_ptr_dout; //写入地址
                mmu_wr_req <= 1'b1; //写入请求
                state <= 'd4;
            end
            'd4: begin //写入mmu的第一个数据     
                //停一拍等待ready回应
                mmu_wr_dat <= i_dat; //写入数据
                mmu_wr_req <= 1'b1; //写入请求
                mmu_wr_addr <= free_ptr_dout; //写入地址
                unit_cnt <= unit_cnt - 1'b1;
                //crossbar write
                cb_wr_en <= ~cb_full ? 1'b1 : 1'b0;
                cb_din <= cb_dat; //此刻cb_dat已更新
                state <= 'd5;
            end
            'd5: begin //判断mmu能不能写入
                if (mmu_wr_ready) begin //上一个写入成功
                    fp_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1); //小于4之后不再读取fifo，包同步之后，该包读取结束，下面同理
                    fifo_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1);
                    //mmu write
                    mmu_wr_dat <= i_dat; //写入数据
                    mmu_wr_req <= ((unit_cnt == 'd0) || (i_empty|fp_list_empty)) ? 1'b0 : 1'b1; //写入请求 不能单靠cnt来完成req信号置位
                    mmu_wr_addr <= free_ptr_dout; //写入地址
                    unit_cnt <= unit_cnt - 1'b1;
                    state <= ((unit_cnt == 'd0) || (i_empty|fp_list_empty)) ? 'd1 : 'd5; //如果包存储完跳转到1
                end
                else begin //没写成功
                    //拉低使能
                    fp_rd_en <= 1'b0;
                    fifo_rd_en <= 1'b0;
                    //mmu write
                    mmu_wr_dat <= unit_pre_1_dat; //写入数据
                    mmu_wr_req <= 1'b1; //写入请求
                    mmu_wr_addr <= fp_pre_1_dat; //写入地址
                    unit_cnt <= unit_cnt;
                    state <= 'd6;
                end
            end
            'd6: begin //mmu无法写入一直请求
                if (mmu_wr_ready) begin
                    fp_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1);
                    fifo_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1);
                    //mmu write
                    mmu_wr_dat <= unit_pre_1_dat; //写入数据
                    mmu_wr_req <= 1'b1; //写入请求
                    mmu_wr_addr <= fp_pre_1_dat; //写入地址
                    unit_cnt <= unit_cnt - 1'b1;
                    state <= ((unit_cnt == 'd0) || (i_empty|fp_list_empty)) ? 'd1 : 'd5; //如果包存储完跳转到1
                end
                else begin
                    fp_rd_en <= 1'b0;
                    fifo_rd_en <= 1'b0;
                    //mmu write
                    mmu_wr_dat <= unit_pre_2_dat; //写入数据 如果该状态写入成功后，下一个状态写入的数据应该是上上周期的数据，直接连接mmu_wr_dat
                    mmu_wr_req <= 1'b1; //写入请求
                    mmu_wr_addr <= fp_pre_2_dat; //写入地址
                    unit_cnt <= unit_cnt;
                    state <= 'd6;
                end
            end
        endcase
    end
end

reg [6:0] cnt;

//模拟写自由指针fifo
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        free_ptr_din <= 'd0;
        fp_wr_en <= 1'b0;
        cnt <= 'd0;
        //init_vld <= 1'b0;
    end
    else begin
        if (~fp_list_full) begin
            fp_wr_en <= 1'b1;
            free_ptr_din <= cnt; //这里用cnt模拟地址输入
            cnt <= cnt + 1'b1;
            //init_vld <= (cnt=='d10) ? 1'b1 : 1'b0;
        end
        else begin
            free_ptr_din <= free_ptr_din;
            fp_wr_en <= 1'b0;
            cnt <= cnt;
            //init_vld <= 1'b0;
        end
    end
end

//自由指针FIFO  宽度和深度待定 如何补充free pointer? 现在是256×32
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