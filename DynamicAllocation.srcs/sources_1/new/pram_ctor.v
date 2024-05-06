`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/29 21:33:21
// Design Name: 
// Module Name: pram_ctor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: PRAM管理模块，内含两个状态机，分别为分配状态机和回收状态机（内存回收和sram无关，仅需要在pram上做更改即可）
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pram_ctor #(
    PRAM_NUM = 16                               // pram号
)(
    input  i_clk,
    input  i_rst_n,

    // 芯片申请
    input  [15:0]  i_chip_apply_sig,             // 芯片申请信号

    output reg [15:0]  o_chip_apply_refuse,          // 芯片申请拒绝信号
    output reg [15:0]  o_chip_apply_success,         // 芯片申请同意信号

    // 内存申请
    input  [127:0] i_mem_apply_num,              // 内存申请数量
    input  [15:0]  i_mem_apply_sig,              // 内存申请信号
    output reg [16:0]  o_mem_addr,               // 输出内存地址（pram号 + 物理地址）
    output reg         o_mem_addr_vld_sig,       // 输出内存地址有效标志位

    // pram状态输出
    output         o_bigger_128,
    output [7:0]   o_remaining_mem
);

// 状态转移标志位
reg init_done;                                  // pram初始化标志位
reg pram_work;                                  // pram开始工作（pram已被分配至某端口域）
reg apply_arbi_done;                            // 申请仲裁完成
reg malloc_done;                                // 内存分配完成

// pram控制信号
reg         wea;                                 // 写使能
reg  [11:0] wr_addr;                             // 写地址总线
reg  [11:0] wr_data;                             // 写数据总线

reg  [11:0] rd_addr;                             // 读地址总线
wire [11:0] rd_data;                             // 读数据总线

// pram状态寄存器
reg         bigger_128_reg;                     // 剩余空间大于128标志位
reg  [7:0]  remaining_mem_reg;                  // 剩余空间不足128时的剩余数量
reg  [3:0]  belong_port_num;                    // pram所属端口号
reg  [36:0] pram_free_list;                     // pram空闲空间链表（首地址、尾地址、大小）
reg  [3:0]  malloc_port;                        // 内存分配目标端口
reg  [7:0]  malloc_num;                         // 分配数量
reg  [3:0]  rr;                                 // 多端口申请时，轮询仲裁参数

// 读取计数器
reg  [7:0]  rd_cnt;

/* 内存申请FSM */
localparam S_RST_APPLY    = 5'b0_0001;          // 复位状态
localparam S_IDLE_APPLY   = 5'b0_0010;          // 空闲状态
localparam S_CHIP_APPLY   = 5'b0_0100;          // 芯片申请状态
localparam S_ARBI_APPLY   = 5'b0_1000;          // 多端口申请仲裁状态
localparam S_MALLOC_APPLY = 5'b1_0000;          // 内存分配状态

reg [4:0] c_state_apply;
reg [4:0] n_state_apply;

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        c_state_apply <= S_RST_APPLY;
    else
        c_state_apply <= n_state_apply;
end

always @(*) begin
    case(c_state_apply) 
        S_RST_APPLY:
            if (init_done)
                n_state_apply <= S_IDLE_APPLY;
            else
                n_state_apply <= S_RST_APPLY;
        S_IDLE_APPLY:
            if (pram_work && |i_mem_apply_sig)
                n_state_apply <= S_ARBI_APPLY;
            else if (~pram_work && |i_chip_apply_sig)
                n_state_apply <= S_CHIP_APPLY;
            else
                n_state_apply <= S_IDLE_APPLY;
        S_CHIP_APPLY:
            if (pram_work)
                n_state_apply <= S_ARBI_APPLY;
            else
                n_state_apply <= S_CHIP_APPLY;
        S_ARBI_APPLY:
            if (apply_arbi_done)
                n_state_apply <= S_MALLOC_APPLY;
            else
                n_state_apply <= S_ARBI_APPLY;
        S_MALLOC_APPLY:
            if (malloc_done)
                n_state_apply <= S_IDLE_APPLY;
            else
                n_state_apply <= S_MALLOC_APPLY;
        default:
            n_state_apply <= S_IDLE_APPLY;
    endcase
end

/* pram控制信号 */
// 地址线、数据线（初始化、内存回收）
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        wr_addr <= 12'd0;
        wr_data <= 12'd1;
        init_done <= 1'b0;
    end
    else if (c_state_apply == S_RST_APPLY && init_done == 1'b0) begin 
        if (wea) begin
            if (&wr_addr) begin 
                wr_addr <= wr_addr;
                wr_data <= wr_data;
                init_done <= 1'b1;
            end
            else begin 
                wr_addr <= wr_addr + 1'b1;
                wr_data <= wr_data + 1'b1;
            end
        end
    end
    else begin 
        wr_addr <= wr_addr;
        wr_data <= wr_data;
        init_done <= 1'b1;
    end
end

// wea写使能信号
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        wea <= 1'b0;
    else if (c_state_apply == S_RST_APPLY && init_done == 1'b0) begin 
        if (&wr_addr)
            wea <= 1'b0;
        else
            wea <= 1'b1;
    end
    else
        wea <= 1'b0;
end

reg [11:0] rd_data_temp;

// 读地址总线（地址分配）
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        rd_addr <= 12'd0;
        o_mem_addr <= {5'd16, 12'd0};
        o_mem_addr_vld_sig <= 1'b0;
        malloc_done <= 1'b0;
        pram_free_list[36:0] <= {12'd0, 12'hfff, 13'h1000};
        rd_data_temp <= 12'd0;
    end
    else if (c_state_apply == S_ARBI_APPLY) begin 
        rd_addr <= pram_free_list[36:25];
    end
    else if (c_state_apply == S_MALLOC_APPLY && ~malloc_done) begin 
        if (rd_cnt != 8'd0) begin 
            rd_data_temp <= rd_data;
            o_mem_addr[11:0] <= rd_addr;
            rd_addr <= rd_data;
            o_mem_addr_vld_sig <= 1'b1;
        end
        else begin 
            o_mem_addr_vld_sig <= 1'b0;
            pram_free_list[36:25] <= rd_data_temp;
            rd_data_temp <= rd_data;
            pram_free_list[12:0] = pram_free_list[12:0] - malloc_num;
            malloc_done <= 1'b1;
        end
    end
    else begin 
        o_mem_addr_vld_sig <= 1'b0;
        pram_free_list <= pram_free_list;
        malloc_done <= 1'b0;
    end
end

reg div2_reg; // 由于要将读出的数据赋值给地址位，因此需要两个周期实现，因此计数器时钟为两个位宽
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        div2_reg <= 1'b0;
    else if (c_state_apply == S_MALLOC_APPLY)
        div2_reg <= div2_reg + 1'b1;
    else
        div2_reg <= 1'b0;
end

// 读地址计数器
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        rd_cnt <= 8'd0;
    end
    else if (c_state_apply == S_ARBI_APPLY) begin 
        rd_cnt <= malloc_num;
    end
    else if (c_state_apply == S_MALLOC_APPLY) begin 
        if (rd_cnt != 'd0 && div2_reg == 1'b1)
            rd_cnt <= rd_cnt - 1'b1;
        else
            rd_cnt <= rd_cnt;
    end
    else    
        rd_cnt <= 'd0;
end

// pram实例化
pram_12x4096 pram0 (
    .clka(i_clk),
    .wea(wea),
    .addra(wr_addr),
    .dina(wr_data),

    .clkb(i_clk),
    .addrb(rd_addr),
    .doutb(rd_data)
);

/* 端口交互信号，芯片申请、内存申请 */
// 芯片申请信号
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        o_chip_apply_refuse <= 16'd0;
        o_chip_apply_success <= 16'd0;
        pram_work <= 1'b0;
        belong_port_num <= 4'd0;
    end
    else if (n_state_apply == S_CHIP_APPLY) begin 
        casex(i_chip_apply_sig)
            16'bxxxx_xxxx_xxxx_xxx1: begin 
                belong_port_num <= 4'd0;
                o_chip_apply_refuse <= 16'hfffe;
                o_chip_apply_success <= 16'h0001;
            end 
            16'bxxxx_xxxx_xxxx_xx10: begin 
                belong_port_num <= 4'd1;
                o_chip_apply_refuse <= 16'hfffd;
                o_chip_apply_success <= 16'h0002;
            end 
            16'bxxxx_xxxx_xxxx_x100: begin 
                belong_port_num <= 4'd2;
                o_chip_apply_refuse <= 16'hfffb;
                o_chip_apply_success <= 16'h0004;
            end 
            16'bxxxx_xxxx_xxxx_1000: begin 
                belong_port_num <= 4'd3;
                o_chip_apply_refuse <= 16'hfff7;
                o_chip_apply_success <= 16'h0008;
            end 
            16'bxxxx_xxxx_xxx1_0000: begin 
                belong_port_num <= 4'd4;
                o_chip_apply_refuse <= 16'hffef;
                o_chip_apply_success <= 16'h0010;
            end 
            16'bxxxx_xxxx_xx10_0000: begin 
                belong_port_num <= 4'd5;
                o_chip_apply_refuse <= 16'hffdf;
                o_chip_apply_success <= 16'h0020;
            end 
            16'bxxxx_xxxx_x100_0000: begin 
                belong_port_num <= 4'd6;
                o_chip_apply_refuse <= 16'hffbf;
                o_chip_apply_success <= 16'h0040;
            end 
            16'bxxxx_xxxx_1000_0000: begin 
                belong_port_num <= 4'd7;
                o_chip_apply_refuse <= 16'hff7f;
                o_chip_apply_success <= 16'h0080;
            end 
            16'bxxxx_xxx1_0000_0000: begin 
                belong_port_num <= 4'd8;
                o_chip_apply_refuse <= 16'hfeff;
                o_chip_apply_success <= 16'h0100;
            end 
            16'bxxxx_xx10_0000_0000: begin 
                belong_port_num <= 4'd9;
                o_chip_apply_refuse <= 16'hfdff;
                o_chip_apply_success <= 16'h0200;
            end 
            16'bxxxx_x100_0000_0000: begin 
                belong_port_num <= 4'd10;
                o_chip_apply_refuse <= 16'hfbff;
                o_chip_apply_success <= 16'h0400;
            end 
            16'bxxxx_1000_0000_0000: begin 
                belong_port_num <= 4'd11;
                o_chip_apply_refuse <= 16'hf7ff;
                o_chip_apply_success <= 16'h0800;
            end 
            16'bxxx1_0000_0000_0000: begin 
                belong_port_num <= 4'd12;
                o_chip_apply_refuse <= 16'hefff;
                o_chip_apply_success <= 16'h1000;
            end 
            16'bxx10_0000_0000_0000: begin 
                belong_port_num <= 4'd13;
                o_chip_apply_refuse <= 16'hdfff;
                o_chip_apply_success <= 16'h2000;
            end 
            16'bx100_0000_0000_0000: begin 
                belong_port_num <= 4'd14;
                o_chip_apply_refuse <= 16'hbfff;
                o_chip_apply_success <= 16'h4000;
            end 
            16'b1000_0000_0000_0000: begin 
                belong_port_num <= 4'd15;
                o_chip_apply_refuse <= 16'h7fff;
                o_chip_apply_success <= 16'h8000;
            end 
            default: begin
                o_chip_apply_refuse <= 16'd0;
                o_chip_apply_success <= 16'd0;
            end
        endcase
        pram_work <= 1'b1;
    end
    else begin 
        o_chip_apply_refuse <= 16'd0;
        o_chip_apply_success <= 16'd0;
    end
end

// 端口申请仲裁
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        rr <= 4'd0;
        apply_arbi_done <= 1'b0;
        malloc_port <= 4'd0;
    end
    else if (n_state_apply == S_ARBI_APPLY) begin 
        case(rr) 
            4'd0: begin 
                malloc_port <= i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 4'd0;
            end
            4'd1: begin 
                malloc_port <= i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 4'd0;
            end
            4'd2: begin 
                malloc_port <= i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 : 4'd0;
            end
            4'd3: begin 
                malloc_port <= i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 : 4'd0;
            end
            4'd4: begin 
                malloc_port <= i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 : 4'd0;
            end
            4'd5: begin 
                malloc_port <= i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 : 4'd0;
            end
            4'd6: begin 
                malloc_port <= i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 : 
                               i_mem_apply_sig[5] ? 4'd5 : 4'd0;
            end
            4'd7: begin 
                malloc_port <= i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 : 4'd0;
            end
            4'd8: begin 
                malloc_port <= i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 : 4'd0;
            end
            4'd9: begin 
                malloc_port <= i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 : 4'd0;
            end
            4'd10: begin 
                malloc_port <= i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 : 4'd0;
            end
            4'd11: begin 
                malloc_port <= i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 : 4'd0;
            end
            4'd12: begin 
                malloc_port <= i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 : 4'd0;
            end
            4'd13: begin 
                malloc_port <= i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 : 4'd0;
            end
            4'd14: begin 
                malloc_port <= i_mem_apply_sig[14] ? 4'd14 :
                               i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 : 4'd0;
            end
            4'd15: begin 
                malloc_port <= i_mem_apply_sig[15] ? 4'd15 : 
                               i_mem_apply_sig[0] ? 4'd0 : 
                               i_mem_apply_sig[1] ? 4'd1 :
                               i_mem_apply_sig[2] ? 4'd2 :
                               i_mem_apply_sig[3] ? 4'd3 :
                               i_mem_apply_sig[4] ? 4'd4 :
                               i_mem_apply_sig[5] ? 4'd5 :
                               i_mem_apply_sig[6] ? 4'd6 :
                               i_mem_apply_sig[7] ? 4'd7 :
                               i_mem_apply_sig[8] ? 4'd8 :
                               i_mem_apply_sig[9] ? 4'd9 :
                               i_mem_apply_sig[10] ? 4'd10 :
                               i_mem_apply_sig[11] ? 4'd11 :
                               i_mem_apply_sig[12] ? 4'd12 :
                               i_mem_apply_sig[13] ? 4'd13 :
                               i_mem_apply_sig[14] ? 4'd14 : 4'd0;
            end
            default:
                malloc_port <= 4'd0;
        endcase
        rr <= rr + 1'b1;
        apply_arbi_done <= 1'b1;
    end
    else begin 
        rr <= rr;
        apply_arbi_done <= 1'b0;
    end
end

// malloc_num赋值
always @(malloc_port or i_rst_n) begin
    if (~i_rst_n)
        malloc_num <= 8'd0;
    else begin 
        case(malloc_port) 
            4'd0:
                malloc_num <= i_mem_apply_num[7:0];
            4'd1:
                malloc_num <= i_mem_apply_num[15:8];
            4'd2:
                malloc_num <= i_mem_apply_num[23:16];
            4'd3:
                malloc_num <= i_mem_apply_num[31:24];
            4'd4:
                malloc_num <= i_mem_apply_num[39:32];
            4'd5:
                malloc_num <= i_mem_apply_num[47:40];
            4'd6:
                malloc_num <= i_mem_apply_num[55:48];
            4'd7:
                malloc_num <= i_mem_apply_num[63:56];
            4'd8:
                malloc_num <= i_mem_apply_num[71:64];
            4'd9:
                malloc_num <= i_mem_apply_num[79:72];
            4'd10:
                malloc_num <= i_mem_apply_num[87:80];
            4'd11:
                malloc_num <= i_mem_apply_num[95:88];
            4'd12:
                malloc_num <= i_mem_apply_num[103:96];
            4'd13:
                malloc_num <= i_mem_apply_num[111:104];
            4'd14:
                malloc_num <= i_mem_apply_num[119:112];
            4'd15:
                malloc_num <= i_mem_apply_num[127:120];
            default:
                malloc_num <= 8'd0;
        endcase
    end
end

// 内存分配
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        o_mem_addr <= 17'd0;
        o_mem_addr_vld_sig <= 1'b0;
        pram_free_list <= {12'd0, 12'hfff, 13'h1000};
    end
end

endmodule
