`timescale 1ns / 1ps

`include "./defines.v"

/*
`define PRAM_NUM 32                              // PRAM数量
`define PORT_NUM 16                              // 端口数量
`define PORT_NUM_WIDTH 4                         // 表示端口号的位数
`define PRAM_NUM_WIDTH 5                         // 表示PRAM号的位数
`define MEM_ADDR_WIDTH 11                        // 物理地址位宽
`define VT_ADDR_WIDTH 16                         // 虚拟地址位宽
`define DATA_DEEPTH_WIDTH 7                      // 数据深度位宽
`define DATA_FRAME_NUM_WIDTH 7                   // 单个数据包帧数量位宽
`define DATA_FRAME_NUM 128                       // 信源位宽
`define PRAM_DEPTH_WIDTH 12                      // PRAM最大深度表示位宽
*/

module pram_ctor #(
    PRAM_NUMBER = 16
)(
    input  i_clk,
    input  i_rst_n,

    // 芯片申请
    input      [`PORT_NUM-1:0]  i_chip_apply_sig,             // 芯片申请信号

    output reg [`PORT_NUM-1:0]  o_chip_apply_refuse,          // 芯片申请拒绝信号
    output reg [`PORT_NUM-1:0]  o_chip_apply_success,         // 芯片申请同意信号

    // 内存申请
    input      [`PORT_NUM*`DATA_FRAME_NUM_WIDTH-1:0]          i_mem_apply_num,          // 内存申请数量
    input      [`PORT_NUM-1:0]                                i_mem_apply_sig,          // 内存申请信号
    output reg [`PORT_NUM*`VT_ADDR_WIDTH-1:0]                 o_mem_addr,               // 输出内存地址（pram号 + 物理地址）
    output reg [`PORT_NUM-1:0]                                o_mem_addr_vld_sig,       // 输出内存地址有效标志位
    output reg [`PORT_NUM-1:0]                                o_mem_apply_done,         // 内存分配结束标志位
    output reg [`PORT_NUM-1:0]                                o_mem_apply_refuse,       // 申请拒绝标志位
    output reg [`PORT_NUM-1:0]                                o_mem_clk,                // fifo时钟

    output                                                    o_init_done,

    // pram状态输出
    output                               o_bigger_64,
    output [`DATA_FRAME_NUM_WIDTH-1:0]   o_remaining_mem,
    output                               o_pram_state,

    /* -------------数据读取、内存回收端口----------- */
    input      [`PORT_NUM-1:0]                                              i_read_apply_sig,         // 读申请信号 
    output reg [`PORT_NUM-1:0]                                              o_read_apply_ack,
    input      [`PORT_NUM*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)-1:0]       i_pd,                     // 数据包描述信息
    output     [`MEM_ADDR_WIDTH-1:0]                                        o_portb_addr,
    output reg                                                              o_portb_addr_vld,
    // output     [`PORT_NUM_WIDTH-1:0]                                        o_aim_port_num,           // 输出目的端口号

    input      [`DATA_FRAME_NUM-1:0]                                        i_read_data,
    output reg [`PORT_NUM*`DATA_FRAME_NUM-1:0]                              o_read_data,

    output reg [`PORT_NUM-1:0]                                              o_read_clk,               // 读取时钟
    output                                                                  o_read_clk_single,
    output reg [`PORT_NUM-1:0]                                              o_read_done
);

// 状态转移标志位
reg init_done;                                  // pram初始化标志位
reg pram_work;                                  // pram开始工作（pram已被分配至某端口域）
reg apply_arbi_done;                            // 申请仲裁完成
reg malloc_done;                                // 内存分配完成

// pram控制信号
reg         wea;                                // 写使能
reg         web;
reg  [`MEM_ADDR_WIDTH-1:0] porta_addr;                         // 端口A控制信号
wire [`MEM_ADDR_WIDTH-1:0] porta_dout;
reg  [`MEM_ADDR_WIDTH-1:0] porta_din;                         

reg  [`MEM_ADDR_WIDTH-1:0] portb_addr;                         // 端口B控制信号
wire [`MEM_ADDR_WIDTH-1:0] portb_dout;  
reg  [`MEM_ADDR_WIDTH-1:0] portb_din;    

reg div2_reg;                                                  // 由于要将读出的数据赋值给地址位，因此需要两个周期实现，因此计数器时钟为两个位宽
reg div2_reg_rvs;
reg mem_addr_vld_sig;

// pram状态寄存器
reg  [`PORT_NUM_WIDTH-1:0]                         belong_port_num;                    // pram所属端口号
reg  [`MEM_ADDR_WIDTH*2+`PRAM_DEPTH_WIDTH-1:0]     pram_free_list;                     // pram空闲空间链表（首地址、尾地址、大小）
reg  [`PORT_NUM_WIDTH-1:0]                         malloc_port;                        // 内存分配目标端口
reg  [`DATA_FRAME_NUM_WIDTH-1:0]                   malloc_num;                         // 分配数量
reg  [`PORT_NUM_WIDTH-1:0]                         rr;                                 // 多端口申请时，轮询仲裁参数

// 读取计数器
reg  [`DATA_FRAME_NUM_WIDTH-1:0]  porta_rd_cnt;
reg  [`DATA_FRAME_NUM_WIDTH-1:0]  portb_rd_cnt;

/*----------------------数据读取、内存回收---------------------------*/
//状态转移寄存器
reg        read_arbi_done;                                   // 读取仲裁结束标志位
reg        read_done;                                        // 数据读取完成标志位
reg        reclaim_done;                                     // 内存回收完成标志位
reg  [3:0] rr_reclaim;                                       // 调度器

// pram状态寄存器（读取、回收）
reg  [3:0]  read_port;            // 仲裁后的读端口
reg  [7:0]  read_num;             // 仲裁之后读数量
reg  [10:0] rd_first_addr;        // 读物理地址

reg  div2_reg_reclaim;            // 内存读取分频
reg  div2_reg_reclaim_rvs;        // 内存读取时钟

// pram_free_list更改标志位
reg  change_apply;
reg  change_reclaim;

/* 内存申请FSM */
localparam S_RST_APPLY    = 6'b00_0001;          // 复位状态
localparam S_IDLE_APPLY   = 6'b00_0010;          // 空闲状态
localparam S_CHIP_APPLY   = 6'b00_0100;          // 芯片申请状态
localparam S_ARBI_APPLY   = 6'b00_1000;          // 多端口申请仲裁状态
localparam S_MALLOC_APPLY = 6'b01_0000;          // 内存分配状态
localparam S_DONE         = 6'b10_0000;

reg [5:0] c_state_apply;
reg [5:0] n_state_apply;

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
                n_state_apply = S_IDLE_APPLY;
            else
                n_state_apply = S_RST_APPLY;
        S_IDLE_APPLY:
            if (pram_work && |i_mem_apply_sig)
                n_state_apply = S_ARBI_APPLY;
            else if (~pram_work && |i_chip_apply_sig)
                n_state_apply = S_CHIP_APPLY;
            else
                n_state_apply = S_IDLE_APPLY;
        S_CHIP_APPLY:
            if (pram_work)
                n_state_apply = S_ARBI_APPLY;
            else
                n_state_apply = S_CHIP_APPLY;
        S_ARBI_APPLY:
            if (apply_arbi_done)
                n_state_apply = S_MALLOC_APPLY;
            else
                n_state_apply = S_ARBI_APPLY;
        S_MALLOC_APPLY:
            if (malloc_done)
                n_state_apply = S_DONE;
            else
                n_state_apply = S_MALLOC_APPLY;
        S_DONE:
            n_state_apply = S_IDLE_APPLY;
        default:
            n_state_apply = S_IDLE_APPLY;
    endcase
end

assign o_pram_state = pram_work;
assign o_portb_addr = portb_addr;
assign o_init_done = init_done;
assign o_aim_port_num = read_port;

assign o_remaining_mem = (pram_free_list[11:0] >= 64) ? 64 : pram_free_list[6:0];
assign o_bigger_64 = (pram_free_list[11:0] >= 64) ? 1 : 0;

assign o_read_clk_single = div2_reg_reclaim_rvs;
// assign o_read_clk = div2_reg_reclaim_rvs;
// assign o_read_done = read_done;

// assign o_read_data = i_read_data;

/* pram控制信号 */
// 地址线、数据线（初始化、内存回收）
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        porta_addr <= 11'd0;
        porta_din <= 11'd1;
        init_done <= 1'b0;
        mem_addr_vld_sig <= 1'b0;
        malloc_done <= 1'b0;
        change_apply <= 1'b0;
    end
    else if (c_state_apply == S_RST_APPLY && init_done == 1'b0) begin 
        if (wea) begin
            if (&porta_addr) begin 
                porta_addr <= porta_addr;
                porta_din <= porta_din;
                init_done <= 1'b1;
            end
            else begin 
                porta_addr <= porta_addr + 1'b1;
                porta_din <= porta_din + 1'b1;
            end
        end
    end
    else if (n_state_apply == S_ARBI_APPLY) begin 
        porta_addr <= pram_free_list[33:23];
        mem_addr_vld_sig <= 1'b1;
    end
    else if (c_state_apply == S_MALLOC_APPLY && ~malloc_done) begin 
        if (porta_rd_cnt == 7'd0 && div2_reg == 1'b1) begin 
            change_apply <= 1'b1;
            malloc_done <= 1'b1; 
        end
        else if (porta_rd_cnt == 7'd0 && div2_reg == 1'b0) begin 
            mem_addr_vld_sig <= 1'b0;
        end
        else begin 
            porta_addr <= porta_dout;
        end
    end
    else begin 
        porta_addr <= porta_addr;
        porta_din <= porta_din;
        init_done <= 1'b1;
        malloc_done <= 1'b0;
        change_apply <= 1'b0;
    end
end

// wea写使能信号
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        wea <= 1'b0;
    else if (c_state_apply == S_RST_APPLY && init_done == 1'b0) begin 
        if (&porta_addr)
            wea <= 1'b0;
        else
            wea <= 1'b1;
    end
    else
        wea <= 1'b0;
end

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        div2_reg <= 1'b0;
    else if (c_state_apply == S_MALLOC_APPLY)
        div2_reg <= div2_reg + 1'b1;
    else
        div2_reg <= 1'b0;
end

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        div2_reg_rvs <= 1'b0;
    else if (n_state_apply == S_MALLOC_APPLY)
        div2_reg_rvs <= div2_reg_rvs + 1'b1;
    else
        div2_reg_rvs <= 1'b0;
end

// 读地址计数器
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        porta_rd_cnt <= 7'd0;
    end
    else if (c_state_apply == S_ARBI_APPLY && malloc_num != 'd0) begin 
        porta_rd_cnt <= malloc_num - 1;
    end
    else if (c_state_apply == S_MALLOC_APPLY) begin 
        if (div2_reg == 1'b1 && porta_rd_cnt != 7'd0)
            porta_rd_cnt <= porta_rd_cnt - 1'b1;
        else begin 
            porta_rd_cnt <= porta_rd_cnt;
        end
    end
    else    
        porta_rd_cnt <= 'd0;
end

// pram实例化
pram_11x2048 pram_u (
    .clka(i_clk),
    .wea(wea),
    .addra(porta_addr),
    .dina(porta_din),
    .douta(porta_dout),

    .clkb(i_clk),
    .web(web),
    .addrb(portb_addr),
    .dinb(portb_din),
    .doutb(portb_dout)
);

/* 端口交互信号，芯片申请、内存申请 */
// 芯片申请信号
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        o_chip_apply_refuse <= 16'd0;
        o_chip_apply_success <= 16'd0;
        belong_port_num <= 4'd0;
    end
    else if (c_state_apply == S_RST_APPLY) begin 
        if (PRAM_NUMBER < 16) begin 
            belong_port_num <= PRAM_NUMBER;
        end
        else begin 
            belong_port_num <= 4'd0;
        end
    end
    else if (n_state_apply == S_CHIP_APPLY && ~pram_work) begin 
        case(PRAM_NUMBER) 
            'd16: begin 
                if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
            end
            'd17: begin 
                if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
            end
            'd18: begin 
                if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
            end
            'd19: begin 
                if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
            end
            'd20: begin 
                if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
            end
            'd21: begin 
                if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end 
            end
            'd22: begin 
                if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
            end
            'd23: begin 
                if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
            end
            'd24: begin 
                if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
            end
            'd25: begin 
                if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
            end
            'd26: begin 
                if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
            end
            'd27: begin 
                if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
            end
            'd28: begin 
                if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
            end
            'd29: begin 
                if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
            end
            'd30: begin 
                if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
            end
            'd31: begin 
                if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
                else if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
            end
            default: begin 
                if (i_chip_apply_sig[0]) begin 
                    belong_port_num <= 4'd0;
                    o_chip_apply_refuse <= 16'hfffe;
                    o_chip_apply_success <= 16'h0001;
                end
                else if (i_chip_apply_sig[1]) begin 
                    belong_port_num <= 4'd1;
                    o_chip_apply_refuse <= 16'hfffd;
                    o_chip_apply_success <= 16'h0002;
                end
                else if (i_chip_apply_sig[2]) begin 
                    belong_port_num <= 4'd2;
                    o_chip_apply_refuse <= 16'hfffb;
                    o_chip_apply_success <= 16'h0004;
                end
                else if (i_chip_apply_sig[3]) begin 
                    belong_port_num <= 4'd3;
                    o_chip_apply_refuse <= 16'hfff7;
                    o_chip_apply_success <= 16'h0008;
                end
                else if (i_chip_apply_sig[4]) begin 
                    belong_port_num <= 4'd4;
                    o_chip_apply_refuse <= 16'hffef;
                    o_chip_apply_success <= 16'h0010;
                end
                else if (i_chip_apply_sig[5]) begin 
                    belong_port_num <= 4'd5;
                    o_chip_apply_refuse <= 16'hffdf;
                    o_chip_apply_success <= 16'h0020;
                end
                else if (i_chip_apply_sig[6]) begin 
                    belong_port_num <= 4'd6;
                    o_chip_apply_refuse <= 16'hffbf;
                    o_chip_apply_success <= 16'h0040;
                end
                else if (i_chip_apply_sig[7]) begin 
                    belong_port_num <= 4'd7;
                    o_chip_apply_refuse <= 16'hff7f;
                    o_chip_apply_success <= 16'h0080;
                end
                else if (i_chip_apply_sig[8]) begin 
                    belong_port_num <= 4'd8;
                    o_chip_apply_refuse <= 16'hfeff;
                    o_chip_apply_success <= 16'h0100;
                end
                else if (i_chip_apply_sig[9]) begin 
                    belong_port_num <= 4'd9;
                    o_chip_apply_refuse <= 16'hfdff;
                    o_chip_apply_success <= 16'h0200;
                end
                else if (i_chip_apply_sig[10]) begin 
                    belong_port_num <= 4'd10;
                    o_chip_apply_refuse <= 16'hfbff;
                    o_chip_apply_success <= 16'h0400;
                end
                else if (i_chip_apply_sig[11]) begin 
                    belong_port_num <= 4'd11;
                    o_chip_apply_refuse <= 16'hf7ff;
                    o_chip_apply_success <= 16'h0800;
                end
                else if (i_chip_apply_sig[12]) begin 
                    belong_port_num <= 4'd12;
                    o_chip_apply_refuse <= 16'hefff;
                    o_chip_apply_success <= 16'h1000;
                end
                else if (i_chip_apply_sig[13]) begin 
                    belong_port_num <= 4'd13;
                    o_chip_apply_refuse <= 16'hdfff;
                    o_chip_apply_success <= 16'h2000;
                end
                else if (i_chip_apply_sig[14]) begin 
                    belong_port_num <= 4'd14;
                    o_chip_apply_refuse <= 16'hbfff;
                    o_chip_apply_success <= 16'h4000;
                end
                else if (i_chip_apply_sig[15]) begin 
                    belong_port_num <= 4'd15;
                    o_chip_apply_refuse <= 16'h7fff;
                    o_chip_apply_success <= 16'h8000;
                end
            end
        endcase
    end
end

// pram_work
always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n) begin 
        pram_work <= 1'b1;
    end
    else if (c_state_apply == S_RST_APPLY) begin 
        if (PRAM_NUMBER < 16) begin 
            pram_work <= 1'b1;
        end
        else begin 
            pram_work <= 1'b0;
        end
    end
    else if (n_state_apply == S_CHIP_APPLY && ~pram_work) begin 
        pram_work <= 1'b1;
    end
    else if (c_state_apply == S_DONE && PRAM_NUMBER > 16 && pram_free_list[11:0] == 12'h800) begin 
        pram_work <= 1'b0;
    end 
end

// 端口申请仲裁
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        rr <= 4'd0;
        apply_arbi_done <= 1'b0;
        malloc_port <= 4'd0;
        o_mem_apply_refuse <= 16'd0;
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
                o_mem_apply_refuse <= 16'hfffe;

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
                o_mem_apply_refuse <= 16'hfffd;
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
                o_mem_apply_refuse <= 16'hfffb;
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
                o_mem_apply_refuse <= 16'hfff7;
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
                o_mem_apply_refuse <= 16'hffef;
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
                o_mem_apply_refuse <= 16'hffdf;
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
                o_mem_apply_refuse <= 16'hffbf;
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
                o_mem_apply_refuse <= 16'hff7f;
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
                o_mem_apply_refuse <= 16'hfeff;
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
                o_mem_apply_refuse <= 16'hfdff;
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
                o_mem_apply_refuse <= 16'hfbff;
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
                o_mem_apply_refuse <= 16'hf7ff;
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
                o_mem_apply_refuse <= 16'hefff;
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
                o_mem_apply_refuse <= 16'hdfff;
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
                o_mem_apply_refuse <= 16'hbfff;
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
                o_mem_apply_refuse <= 16'h7fff;
            end
            default: begin 
                malloc_port <= 4'd0;
                o_mem_apply_refuse <= 16'hfffe;
            end
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
always @(malloc_port or i_rst_n or i_clk) begin : prot_sel
    integer i;
    if (~i_rst_n) begin 
        malloc_num = 8'd0;
        o_mem_addr = 'd0;
        o_mem_addr_vld_sig = 'd0;
        o_mem_clk = 'd0;
        o_mem_apply_done = 'd0;
    end
    else begin 
        malloc_num = i_mem_apply_num[malloc_port*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH];
        for (i = 0; i < `PORT_NUM; i = i + 1) begin 
            if (i == malloc_port) begin 
                o_mem_addr[(i*`VT_ADDR_WIDTH+11)+:5] = PRAM_NUMBER;
                o_mem_addr[i*`VT_ADDR_WIDTH+:11] = porta_addr;
                o_mem_addr_vld_sig[i] = mem_addr_vld_sig;
                o_mem_clk[i] = div2_reg_rvs;
                o_mem_apply_done[i] = malloc_done;
            end
            else begin 
                o_mem_addr[i*`VT_ADDR_WIDTH+:16] = 'd0;
                o_mem_addr_vld_sig[i] = 'd0;
                o_mem_clk[i] = 'd0;
                o_mem_apply_done[i] = 'd0;
            end
        end
    end
end

/*******************************  内存回收  *****************************/
localparam S_IDLE_RECLAIM    = 6'b00_0001;                  // 空闲状态
localparam S_LOAD_RECLAIM    = 6'b00_0010;
localparam S_ARBI_RECLAIM    = 6'b00_0100;                  // 处理多端口同时申请的仲裁状态
localparam S_READ_RECLAIM    = 6'b00_1000;                  // 读sram状态
localparam S_RECLAIM         = 6'b01_0000;                  // 内存回收状态
localparam S_LOAD_FIRST_ADDR = 6'b10_0000;                  // 加载读取首地址

reg [5:0] c_state_reclaim;
reg [5:0] n_state_reclaim;

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        c_state_reclaim <= S_IDLE_RECLAIM;
    else 
        c_state_reclaim <= n_state_reclaim;
end

always @(*) begin
    case(c_state_reclaim)
        S_IDLE_RECLAIM:
            if (|i_read_apply_sig && init_done)
                n_state_reclaim = S_LOAD_RECLAIM;
            else
                n_state_reclaim = S_IDLE_RECLAIM;
        S_LOAD_RECLAIM:
            n_state_reclaim = S_ARBI_RECLAIM;
        S_ARBI_RECLAIM:
            if (read_arbi_done)
                n_state_reclaim = S_LOAD_FIRST_ADDR;
            else 
                n_state_reclaim = S_ARBI_RECLAIM;
        S_LOAD_FIRST_ADDR:
            n_state_reclaim = S_READ_RECLAIM;
        S_READ_RECLAIM:
            if (read_done)
                n_state_reclaim = S_RECLAIM;
            else 
                n_state_reclaim = S_READ_RECLAIM;
        S_RECLAIM:
            if (reclaim_done)
                n_state_reclaim = S_IDLE_RECLAIM;
            else
                n_state_reclaim = S_RECLAIM;
        default:
            n_state_reclaim = S_IDLE_RECLAIM;
    endcase
end

always @(posedge i_clk or negedge i_rst_n) begin 
    if (~i_rst_n) begin 
        read_arbi_done <= 1'b0;
        rr_reclaim <= 4'd0;
        read_port <= 4'd0;
    end
    else if (n_state_reclaim == S_LOAD_RECLAIM) begin 
        case(rr_reclaim) 
            4'd0: begin 
                read_port <= i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 4'd0;
            end
            4'd1: begin 
                read_port <= i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 : 4'd0;
            end
            4'd2: begin 
                read_port <= i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 : 4'd0;
            end
            4'd3: begin 
                read_port <= i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 : 4'd0;
            end
            4'd4: begin 
                read_port <= i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 : 4'd0;
            end
            4'd5: begin 
                read_port <= i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 : 4'd0;
            end
            4'd6: begin 
                read_port <= i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 : 4'd0;
            end
            4'd7: begin 
                read_port <= i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 : 4'd0;
            end
            4'd8: begin 
                read_port <= i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 : 4'd0;
            end
            4'd9: begin 
                read_port <= i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 : 4'd0;
            end
            4'd10: begin 
                read_port <= i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 : 4'd0;
            end
            4'd11: begin 
                read_port <= i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 : 4'd0;
            end
            4'd12: begin 
                read_port <= i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 : 4'd0;
            end
            4'd13: begin 
                read_port <= i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 : 4'd0;
            end
            4'd14: begin 
                read_port <= i_read_apply_sig[14] ? 4'd14 :
                              i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 : 4'd0;
            end
            4'd15: begin 
                read_port <= i_read_apply_sig[15] ? 4'd15 : 
                              i_read_apply_sig[0] ? 4'd0 :
                              i_read_apply_sig[1] ? 4'd1 :
                              i_read_apply_sig[2] ? 4'd2 :
                              i_read_apply_sig[3] ? 4'd3 :
                              i_read_apply_sig[4] ? 4'd4 :
                              i_read_apply_sig[5] ? 4'd5 :
                              i_read_apply_sig[6] ? 4'd6 :
                              i_read_apply_sig[7] ? 4'd7 :
                              i_read_apply_sig[8] ? 4'd8 :
                              i_read_apply_sig[9] ? 4'd9 :
                              i_read_apply_sig[10] ? 4'd10 :
                              i_read_apply_sig[11] ? 4'd11 :
                              i_read_apply_sig[12] ? 4'd12 :
                              i_read_apply_sig[13] ? 4'd13 :
                              i_read_apply_sig[14] ? 4'd14 : 4'd0;
            end
            default:
                read_port <= 4'd0;
        endcase
        rr_reclaim <= rr_reclaim + 1'b1;
        read_arbi_done <= 1'b1;
    end
    else if (n_state_reclaim == S_RECLAIM) begin 
        read_arbi_done <= 1'b0;
        rr_reclaim <= rr_reclaim;
    end
    else begin
        rr_reclaim <= rr_reclaim;
    end
end

// 端口b数据读取
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        portb_addr <= 11'd0;
        read_done <= 1'b0;
        o_portb_addr_vld <= 1'b0;
        portb_din <= 'd0;
    end
    else if (n_state_reclaim == S_LOAD_FIRST_ADDR) begin
        portb_addr <= rd_first_addr;
        o_portb_addr_vld <= 1'b1;
    end
    else if (c_state_reclaim == S_READ_RECLAIM && ~read_done) begin
        if (portb_rd_cnt == 0 && div2_reg_reclaim == 1'b0)begin 
            o_portb_addr_vld <= 1'b0;
            read_done <= 1'b1;
        end
        else begin
            portb_addr <= portb_dout;
        end
    end
    else if (c_state_reclaim == S_RECLAIM && ~reclaim_done) begin 
        portb_addr <= pram_free_list[22:12];
        portb_din <= rd_first_addr;
    end
    else begin 
        portb_addr <= portb_addr;
        o_portb_addr_vld <= o_portb_addr_vld;
        read_done <= 1'b0;
    end
end

// web
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        web <= 1'b0;
        reclaim_done <= 1'b0;
        change_reclaim <= 1'b0;
    end
    else if (c_state_reclaim == S_RECLAIM && ~reclaim_done) begin 
        web <= 1'b1;
        reclaim_done <= 1'b1;
        change_reclaim <= 1'b1;
    end
    else begin 
        web <= 1'b0;
        reclaim_done <= 1'b0;
        change_reclaim <= 1'b0;
    end
end

// portb_rd_cnt端口b读地址计数器、read_num
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        read_num <= 7'd0;
        portb_rd_cnt <= 7'd0;
        rd_first_addr <= 11'd0;
    end
    else if (n_state_reclaim == S_ARBI_RECLAIM) begin 
        read_num <= i_pd[read_port*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+:`DATA_FRAME_NUM_WIDTH];
        portb_rd_cnt <= i_pd[read_port*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+:`DATA_FRAME_NUM_WIDTH] - 1;
        rd_first_addr <= i_pd[read_port*(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)+7+:`MEM_ADDR_WIDTH];
    end
    else if (c_state_reclaim == S_READ_RECLAIM && div2_reg_reclaim == 1'b0 && portb_rd_cnt != 0) begin 
        portb_rd_cnt <= portb_rd_cnt - 'd1;
    end 
    else begin   
        portb_rd_cnt <= portb_rd_cnt;
        read_num <= read_num;
        rd_first_addr <= rd_first_addr;
    end
end

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        div2_reg_reclaim <= 1'b0;
    else if (c_state_reclaim == S_READ_RECLAIM)
        div2_reg_reclaim <= div2_reg_reclaim + 1'b1;
    else 
        div2_reg_reclaim <= 1'b0;
end

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        div2_reg_reclaim_rvs <= 1'b0;
    else if (n_state_reclaim == S_READ_RECLAIM)
        div2_reg_reclaim_rvs <= div2_reg_reclaim_rvs + 1'b1;
    else 
        div2_reg_reclaim_rvs <= 1'b0;
end

//对pram进行赋值
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        if (PRAM_NUMBER >=16)
            pram_free_list <= {11'd0, 11'h7ff, 12'h800};
        else 
            pram_free_list <= {11'd128, 11'h7ff, 12'h800};
    end
    else begin 
        case({change_apply, change_reclaim})
            2'b01: begin 
                pram_free_list[22:12] <= portb_dout;
                pram_free_list[11:0] <= pram_free_list[11:0] + read_num;
            end
            2'b10: begin 
                pram_free_list[33:23] <= porta_dout;
                pram_free_list[11:0] <= pram_free_list[11:0] - malloc_num;
            end
            2'b11: begin 
                pram_free_list[33:23] <= porta_dout;
                pram_free_list[22:12] <= portb_dout;
                pram_free_list[11:0] <= pram_free_list[11:0] - malloc_num + read_num;
            end
            default: begin 
                pram_free_list <= pram_free_list;
            end
        endcase
    end
end

always @(read_port or i_rst_n or i_read_data) begin : output_read_data_res
    integer m;
    if (~i_rst_n) begin
        o_read_data = 'd0;
        // o_read_done = 'd0;
        // o_read_clk = 'd0;
    end
    else begin 
        for (m = 0; m < 16; m = m + 1) begin 
            if (m == read_port) begin 
                o_read_data[m*`DATA_FRAME_NUM+:`DATA_FRAME_NUM] = i_read_data;
                // o_read_done[m] = read_done;
                // o_read_clk[m] = div2_reg_reclaim_rvs;
            end
            else begin 
                o_read_data[m*`DATA_FRAME_NUM+:`DATA_FRAME_NUM] = 'd0;
                // o_read_done[m] = 'd0;
            end
        end
    end
end

always @(read_port or i_rst_n or read_done) begin : output_read_done_res
    integer a;
    if (~i_rst_n) begin
        o_read_done = 'd0;
    end
    else begin 
        for (a = 0; a < 16; a = a + 1) begin 
            if (a == read_port) begin 
                o_read_done[a] = read_done;
            end
            else begin 
                o_read_done[a] = 'd0;
            end
        end
    end
end

always @(read_port or i_rst_n or div2_reg_reclaim_rvs) begin : output_read_clk_res
    integer b;
    if (~i_rst_n) begin
        o_read_clk = 'd0;
    end
    else begin 
        for (b = 0; b < 16; b = b + 1) begin 
            if (b == read_port) begin 
                o_read_clk[b] = div2_reg_reclaim;
            end
            else begin 
                o_read_clk[b] = 'd0;
            end
        end
    end
end

always @(read_port or i_clk) begin : ack_res
    integer n;
    if (n_state_reclaim == S_IDLE_RECLAIM) begin 
        o_read_apply_ack = 'd0;
    end
    else if (i_clk == 'd1) begin
        for (n = 0; n < 16; n = n + 1) begin 
            if (n == read_port) begin 
                o_read_apply_ack[n] = i_read_apply_sig;
            end
            else begin 
                o_read_apply_ack[n] = 'd0;
            end
        end
    end
end

endmodule
