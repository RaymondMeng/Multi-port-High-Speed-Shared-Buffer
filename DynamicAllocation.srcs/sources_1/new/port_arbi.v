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


module port_arbi (
    input          i_clk,
    input          i_rst_n,

    // pram交互信号
    input  [`PRAM_NUM - 1:0]                          i_pram_state,               // pram工作状态
    input                                             i_pram_apply_mem_ack,       // pram握手信号
    input                                             i_pram_apply_mem_refuse,    // 在mem_apply状态拒绝提供空闲地址
    input  [`PRAM_NUM * `DATA_FRAME_NUM_WIDTH - 1:0]  i_pram_free_space,          // pram剩余空间（低于128的部分）
    input  [`PORT_NUM - 1:0]                          i_bigger_than_128,          // 32片pram剩余空间大于128的标志位

    output reg [`PRAM_NUM_WIDTH - 1:0]                o_pram_mem_apply_port_num,  // 目标pram号，输出至接口模块进行分配
    output reg                                        o_pram_mem_apply_req,       // 数据请求信号

    input                                             i_pram_chip_apply_success,  // pram片申请成功信号
    input                                             i_pram_chip_apply_fail,     // pram片申请失败信号

    output reg                                        o_pram_chip_apply_req,      // pram片申请信号
    output     [`PRAM_NUM_WIDTH - 1:0]                o_pram_chip_port_num,       // 申请的pram号

    input  [`PRAM_NUM_WIDTH + `MEM_ADDR_WIDTH - 1:0]  i_pram_addr,                // pram分配的空间地址  (pram中进存储物理地址，在输出时打一拍，同时变成虚拟地址)      

    // free list交互信号
    input                                             i_mem_req,                  // 端口发起内存申请
    input                                             i_mem_apply_num,            // 申请内存数量

    output                                            o_data_vld,                 // 输出数据有效位（作为FIFO的使能信号）
    output [`PRAM_NUM_WIDTH + `MEM_ADDR_WIDTH - 1:0]  o_mem_vt_addr,              // 分配内存的虚拟地址
    output                                            o_mem_apply_failed          // 内存分配失败
);

// 状态信息标志位
// reg arbi_done;                                // 仲裁结束标志位
reg inner_mem_enough;                         // 端口域内存充足
reg outer_mem_enough;                         // 其他端口域内存充足
reg exist_idle_chip;                          // 存在空闲芯片
// reg apply_chip_done;                          // 芯片申请完成标志位
reg all_done;                                 // 状态恢复标志位
reg apply_mem_done;                           // 内存分配完成标志位
reg scheme_done;                              // 调度结束标志位

// 计算完成标志位，用于控制调度方式同时载入
reg compute_inner_done;                       // 内部计数计算完成
reg scan_chip_done;                           // 芯片状态计算完成
reg compute_outer_done;                       // 外部计数计算完成

reg [11:0] compute_inner_res;                 // 内部剩余空间计算结果
reg [11:0] compute_outer_res;                 // 外部剩余空间计算结果

reg inner_mem_enough_reg;                     // 标志位寄存器     
reg outer_mem_enough_reg;                         
reg exist_idle_chip_reg;                          

// 输入寄存器
// reg apply_chip_success;                       // 申请成功信号寄存器
// reg apply_chip_fail;                          // 申请失败信号寄存器

reg [`PRAM_NUM / 2 - 1:0]                      pram_state_reg;                        // pram状态寄存器
reg [`DATA_FRAME_NUM_WIDTH - 1:0]              mem_apply_num_reg;                     // 内存申请数量寄存器
reg [`PRAM_NUM * `DATA_FRAME_NUM_WIDTH - 1:0]  pram_free_space_reg;                   // pram剩余空间寄存器
reg [`PORT_NUM - 1:0]                          bigger_than_128_reg;                   // pram剩余空间大于128标志位

wire [`PORT_NUM - 1:0]                          inner_bigger_than_128_reg;             // 端口域内pram剩余空间大于128标志位
wire [`PORT_NUM - 1:0]                          outer_bigger_than_128_reg;             // 端口域外pram剩余空间大于128标志位

// 存储策略标志位
// reg str_self;                                 // 在自己端口域下存储标志位
// reg str_cross_chip_self;                      // 端口域内跨片传输
// reg str_share;                                // 跨端口域传输标志位

// 模块内寄存器
reg [(`PRAM_NUM_WIDTH + `DATA_FRAME_NUM_WIDTH) * 5 - 1:0] arbi_res;              // 仲裁结果寄存器，pram号加申请数量的组合（暂定最多能同时申请5片sram空间）
reg [4:0]                                                 arbi_pram_num;         // 仲裁所使用pram的数量
reg [`PRAM_NUM - 1:0]                                     port_belong_pram;      // 端口所属pram寄存器，置1为该端口所属，0为非所属
reg [`PRAM_NUM_WIDTH - 1:0]                               pram_chip_port_num;    // 申请pram所使用的端口号

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
                next_state <= S_LOAD;
            else
                next_state <= S_RST;
        S_IDLE:
            if (i_mem_req)
                next_state <= S_LOAD;
            else
                next_state <= S_IDLE;
        S_LOAD:
            next_state <= S_COMPUTE;
        S_COMPUTE:
            if ({inner_mem_enough, exist_idle_chip, outer_mem_enough} == 3'b1xx)
                next_state <= S_ABRI_ALONE;                                               // 之后通过时序控制，控制三个标志位同时写入，三个计算过程，在计算完成后，将标志位置高
            else if ({inner_mem_enough, exist_idle_chip, outer_mem_enough} == 3'b01x)
                next_state <= S_APPLY_CHIP;
            else if ({inner_mem_enough, exist_idle_chip, outer_mem_enough} == 3'b001)
                next_state <= S_ARBI_SHARE;
            else
                next_state <= S_COMPUTE;
        S_ABRI_ALONE:
            if (scheme_done)
                next_state <= S_APPLY_MEM;
            else
                next_state <= S_ABRI_ALONE;
        S_APPLY_CHIP:
            if (scheme_done)
                next_state <= S_APPLY_MEM;
            else if (timeout_cnt > 8'hff)
                next_state <= S_LOAD;
            else
                next_state <= S_APPLY_CHIP;
        S_ARBI_SHARE:
            if (scheme_done)
                next_state <= S_APPLY_MEM;
            else
                next_state <= S_ARBI_SHARE;
        S_APPLY_MEM:
            if (apply_mem_done)
                next_state <= S_DONE;
            else
                next_state <= S_APPLY_MEM;
        S_DONE:
            if (all_done)
                next_state <= S_IDLE;
            else
                next_state <= S_DONE;
        default:
            next_state <= S_IDLE;
    endcase
end

// port_belong_pram 端口号对应的pram一定所属该端口下
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n)
        port_belong_pram <= 32'b0;
    else if (state == S_LOAD)
        port_belong_pram[`PORT_NUM] <= 1'b1;                                    // 保证域端口号相对应的pram始终存在于该端口域下
    else if (state == S_APPLY_CHIP && i_pram_chip_apply_success)
        port_belong_pram[pram_chip_port_num] <= 1'b1;
    else
        port_belong_pram <= port_belong_pram;
end

// pram_state_reg、mem_apply_num_reg、pram_free_space_reg、bigger_than_128_reg四个寄存器在LOAD状态载入pram状态信息
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n) begin
        pram_state_reg <= 16'd0;
        mem_apply_num_reg <= 8'd0;
        pram_free_space_reg <= 256'd0;
        bigger_than_128_reg <= 32'd0;
    end
    else if (state == S_LOAD) begin 
        pram_state_reg <= i_pram_state;
        mem_apply_num_reg <= i_mem_apply_num;
        pram_free_space_reg <= i_pram_free_space;
        bigger_than_128_reg <= i_bigger_than_128;
    end
    else begin
        pram_state_reg <= pram_state_reg;
        mem_apply_num_reg <= mem_apply_num_reg;
        pram_free_space_reg <= pram_free_space_reg;
        bigger_than_128_reg <= bigger_than_128_reg;
    end
end

/* 申请域仲裁：端口域内申请、空闲pram申请、端口域外申请 */
assign inner_bigger_than_128_reg = port_belong_pram & bigger_than_128_reg;
assign outer_bigger_than_128_reg = (~port_belong_pram) & bigger_than_128_reg;

// 内部空间计算，以及计算完成标志位寄存器置位
always @(i_clk or i_rst_n) begin 
    if (~i_rst_n) begin 
        inner_mem_enough_reg = 1'd0;
        compute_inner_res = 12'd0;
        compute_inner_done = 1'd0;
    end
    else if (state == S_COMPUTE && compute_inner_done == 1'b0) begin
        if (|inner_bigger_than_128_reg) begin 
            inner_mem_enough_reg = 1'b1;
            compute_inner_done = 1'b1;
        end
        else begin 
            compute_inner_res = (8{port_belong_pram[0]} & pram_free_space_reg[7:0]) + 
                                (8{port_belong_pram[1]} & pram_free_space_reg[15:8]) + 
                                (8{port_belong_pram[2]} & pram_free_space_reg[23:16]) + 
                                (8{port_belong_pram[3]} & pram_free_space_reg[31:24]) + 
                                (8{port_belong_pram[4]} & pram_free_space_reg[39:32]) + 
                                (8{port_belong_pram[5]} & pram_free_space_reg[47:40]) + 
                                (8{port_belong_pram[6]} & pram_free_space_reg[55:48]) + 
                                (8{port_belong_pram[7]} & pram_free_space_reg[63:56]) + 
                                (8{port_belong_pram[8]} & pram_free_space_reg[71:64]) + 
                                (8{port_belong_pram[9]} & pram_free_space_reg[79:72]) + 
                                (8{port_belong_pram[10]} & pram_free_space_reg[87:80]) + 
                                (8{port_belong_pram[11]} & pram_free_space_reg[95:88]) +
                                (8{port_belong_pram[12]} & pram_free_space_reg[103:96]) +
                                (8{port_belong_pram[13]} & pram_free_space_reg[111:104]) +
                                (8{port_belong_pram[14]} & pram_free_space_reg[119:112]) +
                                (8{port_belong_pram[15]} & pram_free_space_reg[127:120]) +
                                (8{port_belong_pram[16]} & pram_free_space_reg[135:128]) +
                                (8{port_belong_pram[17]} & pram_free_space_reg[143:136]) +
                                (8{port_belong_pram[18]} & pram_free_space_reg[151:144]) +
                                (8{port_belong_pram[19]} & pram_free_space_reg[159:152]) +
                                (8{port_belong_pram[20]} & pram_free_space_reg[167:160]) +
                                (8{port_belong_pram[21]} & pram_free_space_reg[175:168]) +
                                (8{port_belong_pram[22]} & pram_free_space_reg[183:176]) +
                                (8{port_belong_pram[23]} & pram_free_space_reg[191:184]) +
                                (8{port_belong_pram[24]} & pram_free_space_reg[199:192]) +
                                (8{port_belong_pram[25]} & pram_free_space_reg[207:200]) +
                                (8{port_belong_pram[26]} & pram_free_space_reg[215:208]) +
                                (8{port_belong_pram[27]} & pram_free_space_reg[223:216]) +
                                (8{port_belong_pram[28]} & pram_free_space_reg[231:224]) +
                                (8{port_belong_pram[29]} & pram_free_space_reg[239:232]) +
                                (8{port_belong_pram[30]} & pram_free_space_reg[247:240]) +
                                (8{port_belong_pram[31]} & pram_free_space_reg[255:248]);
            if (compute_inner_res >= mem_apply_num_reg) begin 
                inner_mem_enough_reg = 1'b1;
                compute_inner_done = 1'b1;
            end
            else begin 
                inner_mem_enough_reg = 1'b0;
                compute_inner_done = 1'b1;
            end
        end
    end
    else if (state == S_DONE) begin
        inner_mem_enough_reg = 1'b0;
        compute_inner_done = 1'b0;
        compute_inner_res = 12'd0;
    end
    else begin 
        inner_mem_enough_reg = inner_mem_enough_reg;
        compute_inner_done = compute_inner_done;
        compute_inner_res = compute_inner_res;
    end
end

// 空闲pram状态检测
always @(i_clk or i_rst_n) begin 
    if (~i_rst_n) begin 
        scan_chip_done = 1'b0;
        exist_idle_chip_reg = 1'b0;
    end
    else if (state == S_COMPUTE && scan_chip_done == 1'b0) begin 
        if (|pram_state_reg != 0) begin 
            exist_idle_chip_reg = 1'b1;
            scan_chip_done = 1'b1;
        end
        else begin 
            exist_idle_chip_reg = 1'b0;
            scan_chip_done = 1'b1;
        end
    end
    else if (state == S_DONE) begin
        exist_idle_chip_reg = 1'b0;
        scan_chip_done = 1'b0;
    end
    else begin 
        exist_idle_chip_reg = exist_idle_chip_reg;
        scan_chip_done = scan_chip_done;
    end
end

// 外部空间计算
always @(i_clk or i_rst_n) begin 
    if (~i_rst_n) begin 
        outer_mem_enough_reg = 1'b0;
        compute_outer_done = 1'b0;
        compute_outer_res = 12'd0;
    end
    else if (state == S_COMPUTE && compute_outer_done == 1'b0) begin 
        if (|outer_bigger_than_128_reg) begin 
            outer_mem_enough_reg = 1'b1;
            compute_outer_done = 1'b1;
        end
        else begin
            compute_outer_res = ((~port_belong_pram[0]) && pram_free_space_reg[7:0]) + 
                                ((~port_belong_pram[1]) && pram_free_space_reg[15:8]) + 
                                ((~port_belong_pram[2]) && pram_free_space_reg[23:16]) + 
                                ((~port_belong_pram[3]) && pram_free_space_reg[31:24]) + 
                                ((~port_belong_pram[4]) && pram_free_space_reg[39:32]) + 
                                ((~port_belong_pram[5]) && pram_free_space_reg[47:40]) + 
                                ((~port_belong_pram[6]) && pram_free_space_reg[55:48]) + 
                                ((~port_belong_pram[7]) && pram_free_space_reg[63:56]) + 
                                ((~port_belong_pram[8]) && pram_free_space_reg[71:64]) + 
                                ((~port_belong_pram[9]) && pram_free_space_reg[79:72]) + 
                                ((~port_belong_pram[10]) && pram_free_space_reg[87:80]) + 
                                ((~port_belong_pram[11]) && pram_free_space_reg[95:88]) +
                                ((~port_belong_pram[12]) && pram_free_space_reg[103:96]) +
                                ((~port_belong_pram[13]) && pram_free_space_reg[111:104]) +
                                ((~port_belong_pram[14]) && pram_free_space_reg[119:112]) +
                                ((~port_belong_pram[15]) && pram_free_space_reg[127:120]) +
                                ((~port_belong_pram[16]) && pram_free_space_reg[135:128]) +
                                ((~port_belong_pram[17]) && pram_free_space_reg[143:136]) +
                                ((~port_belong_pram[18]) && pram_free_space_reg[151:144]) +
                                ((~port_belong_pram[19]) && pram_free_space_reg[159:152]) +
                                ((~port_belong_pram[20]) && pram_free_space_reg[167:160]) +
                                ((~port_belong_pram[21]) && pram_free_space_reg[175:168]) +
                                ((~port_belong_pram[22]) && pram_free_space_reg[183:176]) +
                                ((~port_belong_pram[23]) && pram_free_space_reg[191:184]) +
                                ((~port_belong_pram[24]) && pram_free_space_reg[199:192]) +
                                ((~port_belong_pram[25]) && pram_free_space_reg[207:200]) +
                                ((~port_belong_pram[26]) && pram_free_space_reg[215:208]) +
                                ((~port_belong_pram[27]) && pram_free_space_reg[223:216]) +
                                ((~port_belong_pram[28]) && pram_free_space_reg[231:224]) +
                                ((~port_belong_pram[29]) && pram_free_space_reg[239:232]) +
                                ((~port_belong_pram[30]) && pram_free_space_reg[247:240]) +
                                ((~port_belong_pram[31]) && pram_free_space_reg[255:248]);
            if (compute_outer_res >= mem_apply_num_reg) begin 
                outer_mem_enough_reg = 1'b1;
                compute_outer_done = 1'b1;
            end
            else begin 
                outer_mem_enough_reg = 1'b0;
                compute_outer_done = 1'b1;
            end
        end
    end
    else if (state == S_DONE) begin 
        outer_mem_enough_reg = 1'b0;
        compute_outer_done = 1'b0;
        compute_outer_res = 12'd0;
    end
    else begin 
        outer_mem_enough_reg = outer_mem_enough_reg;
        compute_outer_done = compute_outer_done;
        compute_inner_res = compute_outer_res;
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
        arbi_res <= 65'd0;
        arbi_pram_num <= 5'd0; 
    end
    else if (state == S_ABRI_ALONE) begin 
        if (|inner_bigger_than_128_reg) begin 
            arbi_pram_num <= 5'd1;
            case (inner_bigger_than_128_reg)                             // 一共需要检测17个标志位
                32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxx1:                 
                    arbi_res[12:0] <= {5'b0_0000, mem_apply_num_reg};
                32'bxxxx_xxxx_xxxx_xxx1_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0000, mem_apply_num_reg};
                32'bxxxx_xxxx_xxxx_xx10_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0001, mem_apply_num_reg};
                32'bxxxx_xxxx_xxxx_x100_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0010, mem_apply_num_reg};
                32'bxxxx_xxxx_xxxx_1000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0011, mem_apply_num_reg};
                32'bxxxx_xxxx_xxx1_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0100, mem_apply_num_reg};
                32'bxxxx_xxxx_xx10_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0101, mem_apply_num_reg};
                32'bxxxx_xxxx_x100_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0110, mem_apply_num_reg};
                32'bxxxx_xxxx_1000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_0111, mem_apply_num_reg};
                32'bxxxx_xxx1_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1000, mem_apply_num_reg};
                32'bxxxx_xx10_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1001, mem_apply_num_reg};
                32'bxxxx_x100_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1010, mem_apply_num_reg};
                32'bxxxx_1000_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1011, mem_apply_num_reg};
                32'bxxx1_0000_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1100, mem_apply_num_reg};
                32'bxx10_0000_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1101, mem_apply_num_reg};
                32'bx100_0000_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1110, mem_apply_num_reg};
                32'b1000_0000_0000_0000_xxxx_xxxx_xxxx_xxx0:
                    arbi_res[12:0] <= {5'b1_1111, mem_apply_num_reg};
            endcase
        end
    end
end

endmodule
