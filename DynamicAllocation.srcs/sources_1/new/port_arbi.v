`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/21 23:06:27
// Design Name: 
// Module Name: port_arbi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 该模块位于端口侧，空闲链表大小为两到三个数据包，在空闲链表不满时（一个数据包占用后），
//              该模块开始工作，根据一定策略向PRAM_CTOR模块发送内存分配申请。
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

/*
`define PRAM_NUM 32                              // PRAM数量
`define PORT_NUM 16                              // 端口数量
`define PRAM_NUM_WIDTH 5                         // 表示端口号的位数
`define MEM_ADDR_WIDTH 11                        // 物理地址位宽
`define DATA_FRAME_NUM_WIDTH 7                   // 单个数据包帧数量位宽
`define DATA_FRAME_NUM 128                       // 信源位宽
*/

module port_arbi #(
    PRIORITY_PRAM_NUM = 0,
    PORT_NUM = 0
)(
    input          i_clk,
    input          i_rst_n,

    // pram交互信号
    input  [`PRAM_NUM - 1:0]                          i_pram_state,               // pram工作状态
    input                                             i_pram_apply_mem_done,      // pram分配结束标志位
    input                                             i_pram_apply_mem_refuse,    // 在mem_apply状态拒绝提供空闲地址
    input  [`PRAM_NUM * `DATA_FRAME_NUM_WIDTH - 1:0]  i_pram_free_space,          // pram剩余空间（低于128的部分）
    input  [`PORT_NUM - 1:0]                          i_bigger_than_64,           // 32片pram剩余空间大于128的标志位

    input                                             i_data_vld,                 // 输出数据有效位（作为FIFO的使能信号）
    input [`PRAM_NUM_WIDTH + `MEM_ADDR_WIDTH - 1:0]   i_mem_vt_addr,              // 分配内存的虚拟地址

    output reg [`PRAM_NUM_WIDTH - 1:0]                o_pram_mem_apply_port_num,  // 目标pram号，输出至接口模块进行分配
    output reg                                        o_pram_mem_apply_req,       // 数据请求信号
    output reg [`DATA_FRAME_NUM_WIDTH - 1:0]          o_pram_mem_apply_num,       // 缓存申请数量

    input                                             i_pram_chip_apply_success,  // pram片申请成功信号
    input                                             i_pram_chip_apply_fail,     // pram片申请失败信号

    output reg                                        o_pram_chip_apply_req,      // pram片申请信号
    output reg [`PRAM_NUM_WIDTH - 1:0]                o_pram_chip_port_num,       // 申请的pram号   

    input  i_mem_malloc_clk,
    output o_mem_malloc_clk,   

    // free list交互信号
    input                                             i_mem_req,                  // 端口发起内存申请
    input  [`DATA_FRAME_NUM_WIDTH - 1:0]              i_mem_apply_num,            // 申请内存数量

    output                                            o_data_vld,                 // 输出数据有效位（作为FIFO的使能信号）
    output [`PRAM_NUM_WIDTH + `MEM_ADDR_WIDTH - 1:0]  o_mem_vt_addr               // 分配内存的虚拟地址
);

// 状态信息标志位
reg inner_mem_enough;                         // 端口域内存充足
reg outer_mem_enough;                         // 其他端口域内存充足
reg exist_idle_chip;                          // 存在空闲芯片
reg scheme_done;                              // 调度结束标志位

// 计算完成标志位，用于控制调度方式同时载入
reg compute_inner_done;                       // 内部空间比较完成
reg scan_chip_done;                           // 芯片状态计算完成
reg compute_outer_done;                       // 外部空间比较完成

reg [`PRAM_NUM_WIDTH - 1:0] inner_arbi_res;   // 内部仲裁结果寄存器（申请目标pram号）
reg [`PRAM_NUM_WIDTH - 1:0] outer_arbi_res;   // 外部仲裁结果寄存器
reg [`PRAM_NUM_WIDTH - 1:0] pram_chip_port_num;    // 申请pram所使用的端口号

reg inner_mem_enough_reg;                     // 标志位寄存器     
reg outer_mem_enough_reg;                         
reg exist_idle_chip_reg;                          

reg [`PRAM_NUM - 1:0]                          pram_state_reg;                        // pram状态寄存器
reg [`DATA_FRAME_NUM_WIDTH - 1:0]              mem_apply_num_reg;                     // 内存申请数量寄存器
reg [`PRAM_NUM * `DATA_FRAME_NUM_WIDTH - 1:0]  pram_free_space_reg;                   // pram剩余空间寄存器
reg [`PRAM_NUM - 1:0]                          bigger_than_64_reg;                   // pram剩余空间大于128标志位

wire [`PRAM_NUM - 1:0]                          inner_bigger_than_64_reg;             // 端口域内pram剩余空间大于128标志位
wire [`PRAM_NUM - 1:0]                          outer_bigger_than_64_reg;             // 端口域外pram剩余空间大于128标志位

// 模块内寄存器
reg [(`PRAM_NUM_WIDTH + `DATA_FRAME_NUM_WIDTH) - 1:0]     arbi_res;              // 仲裁结果寄存器，pram号加申请数量的组合
// reg [4:0]                                                 arbi_pram_num;         // 仲裁所使用pram的数量
reg [`PRAM_NUM - 1:0]                                     port_belong_pram;      // 端口所属pram寄存器，置1为该端口所属，0为非所属

reg       error_flag;                         // 错误标志位

// 调度器
wire [3:0] priority_set;                       // 0~15 -> 16~31

// 计数器
reg [7:0] timeout_cnt;                        //超时计数器（暂定）

/* FSM */
reg [8:0] state;
reg [8:0] next_state;

localparam S_RST        = 9'b000_000_001;       // 复位模块中所有寄存器，相当于重启模块
localparam S_IDLE       = 9'b000_000_010;       // 恢复至空闲状态，部分寄存器会保留
localparam S_LOAD       = 9'b000_000_100;       // 将PRAM信息以及待存储数据包信息计入寄存器
localparam S_COMPUTE    = 9'b000_001_000;       // 计算所需要的信息，如端口域剩余空间和总剩余空间等，并给出存储策略（计算完后将满足条件的信息记在寄存器中）
localparam S_ABRI_ALONE = 9'b000_010_000;       // 根据计算信息直接载入待输出寄存器
localparam S_ARBI_SHARE = 9'b000_100_000;       // 抉择共享策略（在外部空间足够，内部空间不足，且无空闲chip时进入该状态）
localparam S_APPLY_CHIP = 9'b001_000_000;       // 内部空间不足且有未启用的芯片
localparam S_APPLY_MEM  = 9'b010_000_000;       // 申请内存状态
localparam S_DONE       = 9'b100_000_000;       // 申请内存结束，回到IDLE状态

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)
        state <= S_RST;
    else
        state <= next_state;
end

always @(*) begin 
    case(state)
        S_RST:
            if (i_mem_req)
                next_state = S_LOAD;
            else
                next_state = S_RST;
        S_IDLE:
            if (i_mem_req)
                next_state = S_LOAD;
            else
                next_state = S_IDLE;
        S_LOAD:
            next_state = S_COMPUTE;
        S_COMPUTE:
            if (inner_mem_enough == 1'b1)
                next_state = S_ABRI_ALONE;                                               // 之后通过时序控制，控制三个标志位同时写入，三个计算过程，在计算完成后，将标志位置高
            else if (exist_idle_chip == 1'b1)
                next_state = S_APPLY_CHIP;
            else if (outer_mem_enough == 1'b1)
                next_state = S_ARBI_SHARE;
            else
                next_state = S_COMPUTE;
        S_ABRI_ALONE:
            if (scheme_done)
                next_state<= S_APPLY_MEM;
            else
                next_state = S_ABRI_ALONE;
        S_APPLY_CHIP:
            if (scheme_done && i_pram_chip_apply_success && ~error_flag)
                next_state = S_APPLY_MEM;
            else if ((scheme_done && i_pram_chip_apply_fail) || error_flag)
                next_state = S_LOAD;
            else
                next_state = S_APPLY_CHIP;
        S_ARBI_SHARE:
            if (scheme_done)
                next_state = S_APPLY_MEM;
            else
                next_state = S_ARBI_SHARE;
        S_APPLY_MEM:
            if (i_pram_apply_mem_done)
                next_state = S_DONE;
            else if (i_pram_apply_mem_refuse)
                next_state = S_LOAD; 
            else
                next_state = S_APPLY_MEM;
        S_DONE:
            next_state = S_IDLE;
        default:
            next_state = S_IDLE;
    endcase
end

assign o_mem_malloc_clk = i_mem_malloc_clk;
assign priority_set = PRIORITY_PRAM_NUM;

// port_belong_pram 端口号对应的pram一定所属该端口下
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n)
        port_belong_pram <= 32'b0;
    else if (next_state == S_LOAD)
        port_belong_pram[PORT_NUM] <= 1'b1;                                    // 保证域端口号相对应的pram始终存在于该端口域下
    else if (state == S_APPLY_CHIP && i_pram_chip_apply_success && ~i_pram_chip_apply_fail)
        port_belong_pram[pram_chip_port_num] <= 1'b1;
    else
        port_belong_pram <= port_belong_pram;
end

// pram_state_reg、mem_apply_num_reg、pram_free_space_reg、bigger_than_128_reg四个寄存器在LOAD状态载入pram状态信息
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n) begin
        pram_state_reg <= 32'd0;
        mem_apply_num_reg <= 7'd0;
        pram_free_space_reg <= 224'd0;
        bigger_than_64_reg <= 32'd0;
    end
    else if (next_state == S_LOAD) begin 
        pram_state_reg <= i_pram_state;
        mem_apply_num_reg <= i_mem_apply_num;
        pram_free_space_reg <= i_pram_free_space;
        bigger_than_64_reg <= i_bigger_than_64; 
    end
    else begin
        pram_state_reg <= pram_state_reg;
        mem_apply_num_reg <= mem_apply_num_reg;
        pram_free_space_reg <= pram_free_space_reg;
        bigger_than_64_reg <= bigger_than_64_reg;
    end
end

/* 申请域仲裁：端口域内申请、空闲pram申请、端口域外申请 */
assign inner_bigger_than_64_reg = port_belong_pram & bigger_than_64_reg;
assign outer_bigger_than_64_reg = (~port_belong_pram) & bigger_than_64_reg;

// 内部空间计算，以及计算完成标志位寄存器置位
always @(i_clk or i_rst_n) begin 
    if (~i_rst_n) begin 
        inner_mem_enough_reg = 1'd0;
        inner_arbi_res = 5'd0;
        compute_inner_done = 1'd0;
    end
    else if (next_state == S_COMPUTE && compute_inner_done == 1'b0) begin
        if (|inner_bigger_than_64_reg) begin 
            case(priority_set) 
                4'd0: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[16] ? 5'd16 :
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 5'd0;
                end
                4'd1: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 5'd0;
                end
                4'd2: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 : 5'd0;
                end
                4'd3: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 : 5'd0;
                end
                4'd4: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 : 5'd0;
                end
                4'd5: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 : 5'd0;
                end
                4'd6: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 : 5'd0;
                end
                4'd7: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 : 5'd0;
                end
                4'd8: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 : 5'd0;
                end
                4'd9: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 : 5'd0;
                end
                4'd10: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 : 5'd0;
                end
                4'd11: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 : 5'd0;
                end
                4'd12: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 : 5'd0;
                end
                4'd13: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 : 5'd0;
                end
                4'd14: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 : 5'd0;
                end
                4'd15: begin 
                    inner_arbi_res =    inner_bigger_than_64_reg[0]  ? 5'd0 :
                                        inner_bigger_than_64_reg[31] ? 5'd31 : 
                                        inner_bigger_than_64_reg[16] ? 5'd16 : 
                                        inner_bigger_than_64_reg[17] ? 5'd17 :
                                        inner_bigger_than_64_reg[18] ? 5'd18 :
                                        inner_bigger_than_64_reg[19] ? 5'd19 :
                                        inner_bigger_than_64_reg[20] ? 5'd20 :
                                        inner_bigger_than_64_reg[21] ? 5'd21 :
                                        inner_bigger_than_64_reg[22] ? 5'd22 :
                                        inner_bigger_than_64_reg[23] ? 5'd23 :
                                        inner_bigger_than_64_reg[24] ? 5'd24 :
                                        inner_bigger_than_64_reg[25] ? 5'd25 :
                                        inner_bigger_than_64_reg[26] ? 5'd26 :
                                        inner_bigger_than_64_reg[27] ? 5'd27 :
                                        inner_bigger_than_64_reg[28] ? 5'd28 :
                                        inner_bigger_than_64_reg[29] ? 5'd29 :
                                        inner_bigger_than_64_reg[30] ? 5'd30 : 5'd0;
                end
                default:
                    inner_arbi_res = 5'd0;
            endcase
            inner_mem_enough_reg = 1'b1;
            compute_inner_done = 1'b1;
        end
        else begin 
            // 单片提供所有空间
            case(priority_set)
                4'd0: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd1: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd2: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd3: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd4: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd5: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd6: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd7: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd8: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd9: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd10: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd11: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd12: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd13: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd14: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
                4'd15: begin 
                    if (pram_free_space_reg[6:0] >= mem_apply_num_reg) begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[31] && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd31;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[16] && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd16;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[17] && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd17;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[18] && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd18;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[19] && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd19;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[20] && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd20;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[21] && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd21;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[22] && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd22;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[23] && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd23;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[24] && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd24;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[25] && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd25;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[26] && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd26;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[27] && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd27;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[28] && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd28;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[29] && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd29;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else if (port_belong_pram[30] && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin  
                        inner_arbi_res = 5'd30;
                        inner_mem_enough_reg = 1'b1;
                        compute_inner_done = 1'b1;
                    end
                    else begin
                        inner_arbi_res = 5'd0;
                        inner_mem_enough_reg = 1'b0;
                        compute_inner_done = 1'b1;
                    end
                end
            endcase
        end
    end
    else if (next_state == S_DONE) begin
        inner_mem_enough_reg = 1'b0;
        compute_inner_done = 1'b0;
        inner_arbi_res = 5'd0;
    end
    else begin 
        inner_mem_enough_reg = inner_mem_enough_reg;
        compute_inner_done = compute_inner_done;
        inner_arbi_res = inner_arbi_res;
    end
end

// 空闲pram状态检测
always @(i_clk or i_rst_n) begin 
    if (~i_rst_n) begin 
        scan_chip_done = 1'b0;
        exist_idle_chip_reg = 1'b0;
        pram_chip_port_num = 5'd0;
    end
    else if (next_state == S_COMPUTE && scan_chip_done == 1'b0) begin 
        case(priority_set)
            4'd0: begin 
                if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd1: begin 
                if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd2: begin 
                if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd3: begin 
                if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd4: begin 
                if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd5: begin 
                if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd6: begin 
                if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd7: begin 
                if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd8: begin 
                if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd9: begin 
                if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd10: begin 
                if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd11: begin 
                if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd12: begin 
                if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd13: begin 
                if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd14: begin 
                if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
            4'd15: begin 
                if (~pram_state_reg[31]) begin 
                    pram_chip_port_num = 5'd31;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[16]) begin 
                    pram_chip_port_num = 5'd16;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[17] == 1'b1) begin 
                    pram_chip_port_num = 5'd17;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[18]) begin 
                    pram_chip_port_num = 5'd18;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[19]) begin 
                    pram_chip_port_num = 5'd19;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[20]) begin 
                    pram_chip_port_num = 5'd20;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[21]) begin 
                    pram_chip_port_num = 5'd21;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[22]) begin 
                    pram_chip_port_num = 5'd22;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[23]) begin 
                    pram_chip_port_num = 5'd23;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[24]) begin 
                    pram_chip_port_num = 5'd24;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[25]) begin 
                    pram_chip_port_num = 5'd25;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[26]) begin 
                    pram_chip_port_num = 5'd26;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[27]) begin 
                    pram_chip_port_num = 5'd27;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[28]) begin 
                    pram_chip_port_num = 5'd28;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[29]) begin 
                    pram_chip_port_num = 5'd29;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else if (~pram_state_reg[30]) begin 
                    pram_chip_port_num = 5'd30;
                    exist_idle_chip_reg = 1'b1;
                    scan_chip_done = 1'b1;
                end
                else begin 
                    pram_chip_port_num = 5'd0;
                    exist_idle_chip_reg = 1'b0;
                    scan_chip_done = 1'b1;
                end
            end
        endcase
    end
    else if (next_state == S_DONE) begin
        pram_chip_port_num = 5'd0;
        exist_idle_chip_reg = 1'b0;
        scan_chip_done = 1'b0;
    end
    else begin 
        pram_chip_port_num = pram_chip_port_num;
        exist_idle_chip_reg = exist_idle_chip_reg;
        scan_chip_done = scan_chip_done;
    end
end

// 外部空间计算
always @(i_clk or i_rst_n) begin 
    if (~i_rst_n) begin 
        outer_mem_enough_reg = 1'b0;
        compute_outer_done = 1'b0;
        outer_arbi_res = 5'd0;
    end
    else if (next_state == S_COMPUTE && compute_outer_done == 1'b0) begin 
        case(priority_set)
            4'd0: begin 
                if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd1: begin 
                if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd2: begin 
                if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd3: begin 
                if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd4: begin 
                if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd5: begin 
                if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd6: begin 
                if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd7: begin 
                if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd8: begin 
                if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd9: begin 
                if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd10: begin 
                if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd11: begin 
                if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd12: begin 
                if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd13: begin 
                if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd14: begin 
                if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
            4'd15: begin 
                if ((~port_belong_pram[31]) && (pram_free_space_reg[223:217] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd31;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[0]) && (pram_free_space_reg[6:0] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[1]) && (pram_free_space_reg[13:7] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[2]) && (pram_free_space_reg[20:14] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd2;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[3]) && (pram_free_space_reg[27:21] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd3;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[4]) && (pram_free_space_reg[34:28] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd4;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[5]) && (pram_free_space_reg[41:35] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd5;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[6]) && (pram_free_space_reg[47:42] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd6;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[7]) && (pram_free_space_reg[55:48] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd7;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[8]) && (pram_free_space_reg[62:56] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd8;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[9]) && (pram_free_space_reg[69:63] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd9;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[10]) && (pram_free_space_reg[76:70] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd10;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[11]) && (pram_free_space_reg[83:77] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd11;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[12]) && (pram_free_space_reg[90:84] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd12;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[13]) && (pram_free_space_reg[97:91] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd13;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[14]) && (pram_free_space_reg[104:98] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd14;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[15]) && (pram_free_space_reg[111:105] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd15;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[16]) && (pram_free_space_reg[118:112] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd16;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[17]) && (pram_free_space_reg[125:119] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd17;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[18]) && (pram_free_space_reg[132:126] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd18;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[19]) && (pram_free_space_reg[139:133] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd19;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[20]) && (pram_free_space_reg[146:140] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd20;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[21]) && (pram_free_space_reg[153:147] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd21;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[22]) && (pram_free_space_reg[160:154] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd1;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[23]) && (pram_free_space_reg[167:161] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd23;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[24]) && (pram_free_space_reg[174:168] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd24;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[25]) && (pram_free_space_reg[181:175] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd25;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[26]) && (pram_free_space_reg[188:182] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd26;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[27]) && (pram_free_space_reg[195:189] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd27;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[28]) && (pram_free_space_reg[202:196] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd28;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[29]) && (pram_free_space_reg[209:203] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd29;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else if ((~port_belong_pram[30]) && (pram_free_space_reg[216:210] >= mem_apply_num_reg)) begin 
                    outer_arbi_res = 5'd30;
                    outer_mem_enough_reg = 1'b1;
                    compute_outer_done = 1'b1;
                end
                else begin 
                    outer_arbi_res = 5'd0;
                    outer_mem_enough_reg = 1'b0;
                    compute_outer_done = 1'b1;
                end
            end
        endcase
    end
    else if (next_state == S_DONE) begin 
        outer_mem_enough_reg = 1'b0;
        compute_outer_done = 1'b0;
        outer_arbi_res = 5'd0;
    end
    else begin 
        outer_mem_enough_reg = outer_mem_enough_reg;
        compute_outer_done = compute_outer_done;
        outer_arbi_res = outer_arbi_res;
    end
end

// 决策标志位置位
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n) begin 
        inner_mem_enough <= 1'b0;
        outer_mem_enough <= 1'b0;
        exist_idle_chip <= 1'b0;
    end
    else if ({compute_inner_done, scan_chip_done, compute_outer_done} == 3'b111) begin 
        inner_mem_enough = inner_mem_enough_reg;
        outer_mem_enough = outer_mem_enough_reg;
        exist_idle_chip = exist_idle_chip_reg;
    end
    else begin 
        inner_mem_enough <= inner_mem_enough;
        outer_mem_enough <= outer_mem_enough;
        exist_idle_chip <= exist_idle_chip;
    end
end

/* 申请策略仲裁：单存储、共享 */
// arbi_res、arbi_pram_num
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n) begin 
        arbi_res <= 12'd0;
        error_flag <= 1'b0;
    end
    else if (next_state == S_ABRI_ALONE) begin 
        arbi_res <= {inner_arbi_res, mem_apply_num_reg};
        scheme_done <= 1'b1;
        error_flag <= 1'b0;
        o_pram_chip_apply_req <= 1'b0;
        o_pram_chip_port_num <= 5'd0;
    end
    else if (next_state == S_APPLY_CHIP) begin 
        case ({i_pram_chip_apply_success, i_pram_chip_apply_fail})
            2'b00: begin 
                o_pram_chip_apply_req <= 1'b1;
                o_pram_chip_port_num <= pram_chip_port_num;
            end
            2'b01: begin 
                scheme_done <= 1'b1;
            end
            2'b10: begin 
                scheme_done <= 1'b1;
                arbi_res <= {pram_chip_port_num, mem_apply_num_reg};
            end
            2'b11: begin 
                error_flag <= 1'b1;
                scheme_done <= 1'b1;
            end
            default: begin 
                error_flag <= 1'b1;
            end
        endcase
    end
    else if (next_state == S_ARBI_SHARE) begin 
        o_pram_chip_apply_req <= 1'b0;
        o_pram_chip_port_num <= 5'd0;
        arbi_res <= {outer_arbi_res, mem_apply_num_reg};
        scheme_done <= 1'b1;
        error_flag <= 1'b0;
    end
    else if(next_state == S_DONE)begin 
        o_pram_chip_apply_req <= 1'b0;
        o_pram_chip_port_num <= 5'd0;
        error_flag <= 1'b0;
        arbi_res <= 13'b0;
        scheme_done <= 1'b0;
    end
    else begin 
        o_pram_chip_apply_req <= 1'b0;
        o_pram_chip_port_num <= 5'd0;
        error_flag <= 1'b0;
        arbi_res <= arbi_res;
        scheme_done <= 1'b0;
    end
end

// 缓存申请
assign o_mem_vt_addr = i_mem_vt_addr;
assign o_data_vld = i_data_vld;

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        o_pram_mem_apply_num <= 7'd0;
        o_pram_mem_apply_port_num <= 5'd0;
        o_pram_mem_apply_req <= 1'b0;
    end
    else if (next_state == S_APPLY_MEM && ~i_pram_apply_mem_done) begin 
        o_pram_mem_apply_num <= arbi_res[6:0];
        o_pram_mem_apply_port_num <= arbi_res[11:7];
        o_pram_mem_apply_req <= 1'b1;
    end
    else begin 
        o_pram_mem_apply_num <= 7'd0;
        o_pram_mem_apply_port_num <= 5'd0;
        o_pram_mem_apply_req <= 1'b0;
    end
end

endmodule
