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
// Revision 1.0 - finish basic function
// Revision 2.0 - finish 2nd version
// Additional Comments: 该模块实现存储器的接口主要是request-ready形式，request和addr和data一同输入，
//                      下一周期ready响应，并且写入下一个数据的请求，如果ready被拉低则传输
//                      上一周期相同的地址和数据
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module Port_SGDMA #(
    parameter port=0 //指定这个是哪个端口，用于初始化数据
) (
    input                           i_clk,
    input                           i_rst_n,       
    output                          o_rd_en,       //读取使能
    input     [`DATA_DWIDTH-1:0]    i_dat,         //读取到的数据
    input                           i_empty,       //读port_input_fifo空信号
    input                           i_sop, //TODO:sop和eop需要和fifo读出同步,和rd_en&
    input                           i_eop, //这个需不需要？

    /*crossbar interface*/
    output    [`DISPATCH_WIDTH-1:0] o_cb_din,      //写入crossbar数据
    output                          o_cb_wr_en,    //crossbar写使能
    input                           i_cb_full,     //crossbar写满信号

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
    output                          o_mmu_wr_req,         //mmu存储请求
    output    [`PRAM_NUM_WIDTH-1:0] o_sram_sel,           //申请sram片区号
    output                          o_mmu_wr_en,          //sram写使能
    output    [`ADDR_WIDTH-1:0]     o_mmu_wr_addr,        //存储请求地址
    output    [`DATA_DWIDTH-1:0]    o_mmu_wr_dat,         //存储数据
    output                          o_mmu_wr_done,        //存储完成标志位
    input                           i_mmu_wr_ready,       //写请求响应

    /*freelist interface*/
    input                           i_mmu_malloc_done,    //mmu内存分配完成
    input                           i_fp_wr_en,           //空闲地址队列写使能
    input     [`ADDR_WIDTH-1:0]     i_fp_wr_dat,          //空闲地址队列写数据
    //input                           i_aply_valid,         //填充请求响应信号
    //output                          o_fp_list_full      ,
    output                          o_aply_req,           //申请填充freelist
    output    [6:0]                 o_length,             //申请空闲地址长度
    
    input                           locked                //125MHz时钟使能信号
);

reg [3:0] state;
reg fifo_rd_en;
            //不算包头的字节数
/*| 21 ~ 18  | 17 ~ 7 |  6 ~ 4   |   3 ~ 0   | */
/*| src_port | length | priority | dest_port | */
reg [`DATA_DWIDTH-1:0] pack_head;
//reg [3:0] dest_port;
//reg [10:0] length;
reg [6:0] unit_cnt, cnt_temp;
reg [`ADDR_WIDTH-1:0] first_unit_addr;
reg [`DATA_DWIDTH-1:0] unit_pre_1_dat, unit_pre_2_dat, unit_pre_3_dat; //定义第n-1,n-2,n-3个数据
wire [6:0] unit_cnt_wire;

assign unit_cnt_wire = (i_dat[17:7] >> 4) + (|(i_dat[17:7] % 16)) + 'd1; //直接作为值拼接也是可以的

//crossbar buffer defines
reg [3:0] sel;
reg [`DISPATCH_WIDTH-1:0] cb_din;
reg cb_wr_en;
wire cb_full;
wire [`DISPATCH_WIDTH-1:0] cb_dat;

assign cb_dat = {first_unit_addr, cnt_temp, pack_head[6:0]}; //crossbar32位包调度数据

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
reg mmu_wr_en;
reg mmu_wr_done;
reg [`ADDR_WIDTH-1:0] mmu_wr_addr, mmu_wr_addr_reg;
reg [`DATA_DWIDTH-1:0] o_mmu_wr_dat_reg, mmu_wr_dat, mmu_pre_1_dat;

assign o_mmu_wr_done = mmu_wr_done;
assign o_mmu_wr_addr = mmu_wr_addr;
assign o_mmu_wr_dat = mmu_wr_dat; //改，根据ready信号写
assign o_mmu_wr_req = mmu_wr_req;
assign mmu_wr_ready = i_mmu_wr_ready;
assign o_mmu_wr_en = ~i_empty ? mmu_wr_en : 1'b0;

assign o_sram_sel = port;


//free pointer list defines
reg [`ADDR_WIDTH-1:0] free_ptr_din;
reg fp_wr_en, fp_rd_en, init_vld;
reg [`ADDR_WIDTH-1:0] fp_pre_1_dat, fp_pre_2_dat, fp_pre_3_dat;
wire [`ADDR_WIDTH-1:0] free_ptr_dout;
wire fp_list_full, fp_list_empty, fp_list_almost_empty;
reg aply_req;
reg [6:0] length;
wire fp_rd_en_wire;

assign fp_rd_en_wire = (i_empty|fp_list_empty) ? 1'b0 : fp_rd_en;
assign o_aply_req = aply_req;
assign o_length = length;

assign o_rd_en = (i_empty|fp_list_empty) ? 1'b0 : fifo_rd_en;

//TODO 补充注释以及完善写mmu，应该先读fp_ptr_dout，判断是否为同一个片区，如果跨片需要重新申请，否则连续写入MMU
/*                                            包数据解析及数据调度状态机 
**  |-------------------------------------------mmu write interface----------------------------------------------| 
**  |  mmu_wr_req   |    mmu_wr_ready   |    mmu_wr_addr   |    mmu_wr_en   |  mmu_wr_dat  |     mmu_wr_done     |
**  |    请求存储    |     写请求响应     |    请求存储地址   |   sram写使能   |    包数据     |  mmu存储完成标志位   |
*/
/*状态机实现功能：cnt包信元计数√、包与包之间的衔接√、发送长度√、crossbar发送、边界情况（如果fifo空或者满，状态如何跳转）*/
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        /*初始化*/
        fifo_rd_en <= 1'b0;
        pack_head <= 'd0;
        //dest_port <= 'd0;
        //length <= 'd0;
        unit_cnt <= 'd0;
        state <= 'd0;
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
        mmu_wr_en <= 1'b0;
        aply_req <= 1'b0;
        mmu_wr_done <= 1'b0;
    end
    else begin 
        pack_head <= pack_head;
        first_unit_addr <= first_unit_addr;
        mmu_wr_req <= 1'b0;
        mmu_wr_en <= 1'b0;
        mmu_wr_dat <= mmu_wr_dat;
        mmu_wr_addr <= mmu_wr_addr;
        fifo_rd_en <= 1'b0;
        fp_rd_en <= 1'b0;
        // aply_req <= 1'b0;
        length <= length;
        unit_cnt <= unit_cnt;
        cnt_temp <= cnt_temp;
        cb_wr_en <= 1'b0;
        mmu_wr_done <= 1'b0;
        case (state)
            //开始读取输入fifo的数据
            'd0: begin
                state <= (~locked||(i_empty|fp_list_empty)) ? 'd0 : 'd1;
            end
            'd1: begin
                mmu_wr_req <= 1'b1;
                state <= 'd2;
            end
            'd2: begin
                state <= 'd3;
                // /*读空闲指针链表*/
                /*TODO:包长度给地址生成模块,用于填充freelist*/
            end
            'd3: begin //包头写入mmu
                if (mmu_wr_ready) begin
                    fifo_rd_en <= 1'b1;
                    fp_rd_en <= 1'b1;
                    state <= 'd4;
                end
                else begin
                    state <= 'd3;
                end
            end
            'd4: begin //使能  
                // //crossbar write
                // cb_wr_en <= ~cb_full ? 1'b1 : 1'b0;
                // cb_din <= cb_dat; //此刻cb_dat已更新
                fifo_rd_en <= 1'b1;
                fp_rd_en <= 1'b1;
                state <= 'd5;
            end
            'd5: begin //读取包头
                fifo_rd_en <= (i_empty|fp_list_empty) ? 1'b0 : 1'b1;
                fp_rd_en <= (i_empty|fp_list_empty) ? 1'b0 : 1'b1;
                mmu_wr_dat <= i_dat;
                mmu_wr_en <= 1'b1;
                mmu_wr_addr <= free_ptr_dout;
                //first_unit_addr <= free_ptr_dout;
                // aply_req <= 1'b1; //申请
                //pack_head <= i_dat;
                length <= (i_dat[17:7] >> 4) + (|(i_dat[17:7] % 16)) + 'd1; //加包头的长度
                unit_cnt <= (i_dat[17:7] >> 4) + (|(i_dat[17:7] % 16)); //包长度
                //cnt_temp <= (i_dat[17:7] >> 4) + 1'b1;
                cb_din <= {free_ptr_dout, unit_cnt_wire, i_dat[6:0]}; //30位 16 7 7    空闲地址  数量  目的端口号
                cb_wr_en <= 1'b1;
                state <= 'd6;
            end
            'd6: begin //读取数据
                if (unit_cnt == 'd2) begin
                    mmu_wr_dat <= i_dat;
                    mmu_wr_en <= 1'b1;
                    mmu_wr_addr <= free_ptr_dout;
                    unit_cnt <= unit_cnt - 1'b1; //包长度
                    state <= 'd7;
                end
                else begin
                    mmu_wr_dat <= i_dat;
                    mmu_wr_en <= 1'b1;
                    mmu_wr_addr <= free_ptr_dout;
                    fifo_rd_en <= 1'b1;
                    fp_rd_en <= 1'b1;
                    unit_cnt <= unit_cnt - 1'b1; //包长度
                    state <= 'd6;
                end
            end
            'd7: begin //等到最后一个数据传完，拉低wr_en
                mmu_wr_dat <= i_dat;
                mmu_wr_en <= 1'b1;
                mmu_wr_addr <= free_ptr_dout;
                state <= 'd8;
            end
            'd8: begin
                state <= 'd0;
                mmu_wr_done <= 1'b1;
            end
        endcase
    end
end

// /*TODO: cnt包信元计数√、包与包之间的衔接√、crossbar发送、边界情况（如果fifo空或者满，状态如何跳转）*/
// always @(posedge i_clk or negedge i_rst_n) begin
//     if (!i_rst_n) begin
//         /*初始化*/
//         fifo_rd_en <= 1'b0;
//         pack_head <= 'd0;
//         //dest_port <= 'd0;
//         //length <= 'd0;
//         unit_cnt <= 'd0;
//         state <= 'd1;
//         cb_wr_en <= 1'b0;
//         cb_din <= 'd0;
//         //sel <= 'd0;
//         fp_rd_en <= 1'b0;
//         cnt_temp <= 'd0;
//         first_unit_addr <= 'd0;
//         mmu_wr_addr <= 'd0;
//         mmu_wr_dat <= 'd0; //数据写入用组合
//         mmu_wr_req <= 1'b0;
//         unit_pre_1_dat <= 'd0;
//         unit_pre_2_dat <= 'd0;
//         fp_pre_1_dat <= 'd0;
//         fp_pre_2_dat <= 'd0;
//         mmu_wr_en <= 1'b0;
//         mmu_wr_done <= 1'b0;
//         // aply_req <= 1'b0;
//     end
//     else begin 
//         if (fifo_rd_en) begin
//             /*寄存三个周期数据*/
//             unit_pre_1_dat <= i_dat; //第n-1个数据
//             unit_pre_2_dat <= unit_pre_1_dat; //第n-2个数据
//             /*寄存三周期地址*/
//             fp_pre_1_dat <= free_ptr_dout; //写入指定地址（free_ptr_dout从free_list中取到）第n-1个数据
//             fp_pre_2_dat <= fp_pre_1_dat; //第n-2个数据
//         end
//         else begin
//             /*寄存三个周期数据*/
//             unit_pre_1_dat <= unit_pre_1_dat; //第n-1个数据
//             unit_pre_2_dat <= unit_pre_2_dat; //第n-2个数据
//             //unit_pre_3_dat <= unit_pre_3_dat; //第n-3个数据
//             /*寄存三周期地址*/
//             fp_pre_1_dat <= fp_pre_1_dat; //写入指定地址（free_ptr_dout从free_list中取到）第n-1个数据
//             fp_pre_2_dat <= fp_pre_2_dat; //第n-2个数据
//         end
//         cnt_temp <= cnt_temp;
//         pack_head <= pack_head;
//         first_unit_addr <= first_unit_addr;
//         mmu_wr_req <= 1'b0;
//         case (state)
//             //开始读取输入fifo的数据
//             'd1: begin
//                 fifo_rd_en <= (i_empty|fp_list_empty) ? 1'b0 : 1'b1;
//                 fp_rd_en <= (i_empty|fp_list_empty) ? 1'b0 : 1'b1; //读取freeptr
//                 state <= (i_empty|fp_list_empty) ? 'd1 : 'd2;
//             end
//             'd2: begin
//                 state <= 'd3;
//                 /*读空闲指针链表*/
//                 /*TODO:包长度给地址生成模块,用于填充freelist*/
//             end
//             'd3: begin //包头写入mmu
//                 pack_head <= i_dat; //取到包头
//                 //sel <= i_dat[3:0]; //目的端口号用于选择crossbar buffer
//                 unit_cnt <= (i_dat[17:7] >> 3) + 1'b1; //包长度(可能不准确验证一下)
//                 cnt_temp <= (i_dat[17:7] >> 3) + 1'b1; //注意符号优先级
//                 first_unit_addr <= free_ptr_dout;
//                 //mmu write
//                 mmu_wr_dat <= i_dat; //写入数据
//                 mmu_wr_addr <= free_ptr_dout; //写入地址
//                 mmu_wr_req <= 1'b1; //写入请求
//                 state <= 'd4;
//             end
//             'd4: begin //写入mmu的第一个数据     
//                 //停一拍等待ready回应
//                 mmu_wr_dat <= i_dat; //写入数据
//                 mmu_wr_req <= 1'b1; //写入请求
//                 mmu_wr_addr <= free_ptr_dout; //写入地址
//                 unit_cnt <= unit_cnt - 1'b1;
//                 //crossbar write
//                 cb_wr_en <= ~cb_full ? 1'b1 : 1'b0;
//                 cb_din <= cb_dat; //此刻cb_dat已更新
//                 state <= 'd5;
//             end
//             'd5: begin //判断mmu能不能写入
//                 if (mmu_wr_ready) begin //上一个写入成功
//                     fp_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1); //小于4之后不再读取fifo，包同步之后，该包读取结束，下面同理
//                     fifo_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1);
//                     //mmu write
//                     mmu_wr_dat <= i_dat; //写入数据
//                     mmu_wr_req <= ((unit_cnt == 'd0) || (i_empty|fp_list_empty)) ? 1'b0 : 1'b1; //写入请求 不能单靠cnt来完成req信号置位
//                     mmu_wr_addr <= free_ptr_dout; //写入地址
//                     unit_cnt <= unit_cnt - 1'b1;
//                     state <= ((unit_cnt == 'd0) || (i_empty|fp_list_empty)) ? 'd1 : 'd5; //如果包存储完跳转到1
//                 end
//                 else begin //没写成功
//                     //拉低使能
//                     fp_rd_en <= 1'b0;
//                     fifo_rd_en <= 1'b0;
//                     //mmu write
//                     mmu_wr_dat <= unit_pre_1_dat; //写入数据
//                     mmu_wr_req <= 1'b1; //写入请求
//                     mmu_wr_addr <= fp_pre_1_dat; //写入地址
//                     unit_cnt <= unit_cnt;
//                     state <= 'd6;
//                 end
//             end
//             'd6: begin //mmu无法写入一直请求
//                 if (mmu_wr_ready) begin
//                     fp_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1);
//                     fifo_rd_en <= (unit_cnt < 'd3) ? 1'b0 : ((i_empty|fp_list_empty) ? 1'b0 : 1'b1);
//                     //mmu write
//                     mmu_wr_dat <= unit_pre_1_dat; //写入数据
//                     mmu_wr_req <= 1'b1; //写入请求
//                     mmu_wr_addr <= fp_pre_1_dat; //写入地址
//                     unit_cnt <= unit_cnt - 1'b1;
//                     state <= ((unit_cnt == 'd0) || (i_empty|fp_list_empty)) ? 'd1 : 'd5; //如果包存储完跳转到1
//                 end
//                 else begin
//                     fp_rd_en <= 1'b0;
//                     fifo_rd_en <= 1'b0;
//                     //mmu write
//                     mmu_wr_dat <= unit_pre_2_dat; //写入数据 如果该状态写入成功后，下一个状态写入的数据应该是上上周期的数据，直接连接mmu_wr_dat
//                     mmu_wr_req <= 1'b1; //写入请求
//                     mmu_wr_addr <= fp_pre_2_dat; //写入地址
//                     unit_cnt <= unit_cnt;
//                     state <= 'd6;
//                 end
//             end
//         endcase
//     end
// end

// reg malloc_done_r;
// wire comb_malloc_done;
// always @(posedge i_clk) begin
//     malloc_done_r <= i_mmu_malloc_done;
// end
// assign comb_malloc_done = ~i_mmu_malloc_done & malloc_done_r;

//申请填充freelist 三段式
reg [2:0] aply_state, aply_state_n;
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        aply_state <= 'd0;
    end
    else begin
        aply_state <= aply_state_n; 
    end
end

always @(*) begin
    if (~i_rst_n) begin
        aply_req = 1'b0;
        aply_state_n = 'd0;
    end
    else begin
        aply_req = 1'b0;
        case (aply_state)
            'd0: begin
                aply_state_n = (state == 'd5) ? 'd1 : 'd0;
            end
            'd1: begin //开始请求存储
                aply_req = 1'b1;
                aply_state_n = 'd2;
            end
            'd2: begin
                if (i_mmu_malloc_done) begin
                    aply_state_n = 'd0;
                end
                else begin
                    aply_state_n = 'd2;
                    aply_req = 'd1;
                end
            end
        endcase
    end
end


//  
// assign comb_malloc_done = i_mmu_malloc_done ? 1'b1 : 1'b0;

reg [6:0] cnt; //初始化填充128个
//初始化自由指针fifo
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        free_ptr_din <= 'd0;
        fp_wr_en <= 1'b0;
        cnt <= 'd0;
        init_vld <= 1'b0;
    end
    else begin
        if (~fp_list_full && locked) begin
            if (cnt < 'd127) begin
                fp_wr_en <= (cnt=='d126) ? i_fp_wr_en : 1'b1; //初始化完成后fp的写使能交给mmu
                free_ptr_din <= (cnt=='d126) ? i_fp_wr_dat : {port, 4'b0000, cnt}; //这里用cnt模拟地址输入，初始化完成后fp的写数据交给mmu
                cnt <= cnt + 1'b1;
                init_vld <= (cnt=='d126) ? 1'b1 : 1'b0;
            end
            else begin
                cnt <= cnt;
                free_ptr_din <= i_fp_wr_dat;
                init_vld <= init_vld;
                fp_wr_en <= i_fp_wr_en;
            end
        end
        else begin
            free_ptr_din <= free_ptr_din;
            fp_wr_en <= 1'b0;
            cnt <= 'd0;
            init_vld <= 1'b0;
        end
    end
end


//自由指针FIFO  宽度和深度待定 如何补充free pointer? 现在是256×16
free_ptr_list free_ptr_list_inst (
  .clk(i_clk),                    // input wire clk
  .srst(~i_rst_n),                  // input wire srst
  .din(free_ptr_din),                    // input wire [16 : 0] din
  .wr_en(fp_wr_en),                // input wire wr_en
  .rd_en(fp_rd_en_wire),                // input wire rd_en
  .dout(free_ptr_dout),                  // output wire [16 : 0] dout
  .full(fp_list_full),                  // output wire full
  .empty(fp_list_empty),                // output wire empty
  .almost_empty(fp_list_almost_empty)  // output wire almost_empty
);

endmodule