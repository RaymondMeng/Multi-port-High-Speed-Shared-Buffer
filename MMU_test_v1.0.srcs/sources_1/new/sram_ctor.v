`timescale 1ns / 1ps

`include "defines.v"

module sram_ctor #(
    RR_INIT_VAL = 13
)(
    input         i_clk,
    input         i_rst_n,

    input  [`PORT_NUM-1:0]                   i_wr_apply_sig,             // 写入申请
    input  [`MEM_ADDR_WIDTH * `PORT_NUM-1:0] i_wr_phy_addr,              // 16组物理地址
    input  [`DATA_FRAME_NUM*`PORT_NUM-1:0]   i_wr_data,                  // 16组写入数据
    input  [`PORT_NUM-1:0]                   i_wea,                      // 16组写使能信号
    input  [`PORT_NUM-1:0]                   i_write_done,               // 写入结束标志位

    output reg [`PORT_NUM-1:0]             o_wr_apply_success,
    output reg [`PORT_NUM-1:0]             o_wr_apply_refuse,

    input                                  i_rd_clk,
    input  [`MEM_ADDR_WIDTH-1:0]           i_rd_phy_addr,
    output [`DATA_FRAME_NUM-1:0]           o_rd_data                     // data_vld在pram部分提供，读数据时直接一对一读出
);

// SRAM写控制信号
reg  [`MEM_ADDR_WIDTH-1:0] wr_phy_addr;
reg  [`DATA_FRAME_NUM-1:0] wr_data;
reg                        wea;

// 状态转移信号
reg  arbi_done;
reg  write_done;

reg  [3:0] rr;                   // 轮询调度器
reg  [3:0] sel;

/*FSM*/
localparam S_IDLE  = 3'b001;
localparam S_ARBI  = 3'b010;
localparam S_WRITE = 3'b100;

reg [2:0] c_state;
reg [2:0] n_state;

always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n)
        c_state <= S_IDLE;
    else 
        c_state <= n_state;
end

always @(*) begin
    if (~i_rst_n)
        n_state <= S_IDLE;
    else begin
        case(c_state) 
            S_IDLE:
                if (|i_wr_apply_sig)
                    n_state = S_ARBI;
                else
                    n_state = S_IDLE;
            S_ARBI:
                if (arbi_done)
                    n_state = S_WRITE;
                else
                    n_state = S_ARBI;
            S_WRITE:
                if (write_done)
                    n_state = S_IDLE;
                else
                    n_state = S_WRITE;
            default:
                n_state = S_IDLE;
        endcase
    end
end

// 端口选择仲裁
always @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin 
        sel <= 4'd0;
        arbi_done <= 1'b0;
        rr <= RR_INIT_VAL >= 16 ? RR_INIT_VAL - 16 : RR_INIT_VAL;
    end
    else if (n_state == S_ARBI) begin 
        case(rr) 
            4'd0: begin 
                sel <= i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 4'd0;
            end
            4'd1: begin 
                sel <= i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 : 4'd0;
            end
            4'd2: begin 
                sel <= i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 : 4'd0;
            end
            4'd3: begin 
                sel <= i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 : 4'd0;
            end
            4'd4: begin 
                sel <= i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 : 4'd0;
            end
            4'd5: begin 
                sel <= i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 : 4'd0;
            end
            4'd6: begin 
                sel <= i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 : 4'd0;
            end
            4'd7: begin 
                sel <= i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 : 4'd0;
            end
            4'd8: begin 
                sel <= i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 : 4'd0;
            end
            4'd9: begin 
                sel <= i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 : 4'd0;
            end
            4'd10: begin 
                sel <= i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 : 4'd0;
            end
            4'd11: begin 
                sel <= i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 : 4'd0;
            end
            4'd12: begin 
                sel <= i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 : 4'd0;
            end
            4'd13: begin 
                sel <= i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 : 4'd0;
            end
            4'd14: begin 
                sel <= i_wr_apply_sig[14] ? 4'd14 :
                        i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 : 4'd0;
            end
            4'd15: begin 
                sel <= i_wr_apply_sig[15] ? 4'd15 : 
                        i_wr_apply_sig[0] ? 4'd0 :
                        i_wr_apply_sig[1] ? 4'd1 :
                        i_wr_apply_sig[2] ? 4'd2 :
                        i_wr_apply_sig[3] ? 4'd3 :
                        i_wr_apply_sig[4] ? 4'd4 :
                        i_wr_apply_sig[5] ? 4'd5 :
                        i_wr_apply_sig[6] ? 4'd6 :
                        i_wr_apply_sig[7] ? 4'd7 :
                        i_wr_apply_sig[8] ? 4'd8 :
                        i_wr_apply_sig[9] ? 4'd9 :
                        i_wr_apply_sig[10] ? 4'd10 :
                        i_wr_apply_sig[11] ? 4'd11 :
                        i_wr_apply_sig[12] ? 4'd12 :
                        i_wr_apply_sig[13] ? 4'd13 :
                        i_wr_apply_sig[14] ? 4'd14 : 4'd0;
            end
            default:
                sel <= 4'd0;
        endcase
        rr <= rr + 1'b1;
        arbi_done <= 1'b1;
    end
    else begin
        rr <= rr;
        sel <= sel;
        arbi_done <= 1'b0;
    end
end

// 数据通路选择
always @(sel or i_clk) begin 
    if (i_clk == 'd1) begin
        case(sel) 
            'd0: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 0 + 10:`MEM_ADDR_WIDTH * 0];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 0 + 127:`DATA_FRAME_NUM * 0];
                wea = i_wea[0];
                o_wr_apply_success <= 16'h0001;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfffe;
                write_done <= i_write_done[0];
            end
            'd1: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 1 + 10:`MEM_ADDR_WIDTH * 1];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 1 + 127:`DATA_FRAME_NUM * 1];
                wea = i_wea[1];
                o_wr_apply_success <= 16'h0002;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfffd;
                write_done <= i_write_done[1];
            end
            'd2: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 2 + 10:`MEM_ADDR_WIDTH * 2];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 2 + 127:`DATA_FRAME_NUM * 2];
                wea = i_wea[2];
                o_wr_apply_success <= 16'h0004;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfffb;
                write_done <= i_write_done[2];
            end
            'd3: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 3 + 10:`MEM_ADDR_WIDTH * 3];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 3 + 127:`DATA_FRAME_NUM * 3];
                wea = i_wea[3];
                o_wr_apply_success <= 16'h0008;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfff7;
                write_done <= i_write_done[3];
            end
            'd4: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 4 + 10:`MEM_ADDR_WIDTH * 4];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 4 + 127:`DATA_FRAME_NUM * 4];
                wea = i_wea[4];
                o_wr_apply_success <= 16'h0010;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hffef;
                write_done <= i_write_done[4];
            end
            'd5: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 5 + 10:`MEM_ADDR_WIDTH * 5];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 5 + 127:`DATA_FRAME_NUM * 5];
                wea = i_wea[5];
                o_wr_apply_success <= 16'h0020;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hffdf;
                write_done <= i_write_done[5];
            end
            'd6: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 6 + 10:`MEM_ADDR_WIDTH * 6];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 6 + 127:`DATA_FRAME_NUM * 6];
                wea = i_wea[6];
                o_wr_apply_success <= 16'h0040;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hffbf;
                write_done <= i_write_done[6];
            end
            'd7: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 7 + 10:`MEM_ADDR_WIDTH * 7];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 7 + 127:`DATA_FRAME_NUM * 7];
                wea = i_wea[7];
                o_wr_apply_success <= 16'h0080;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hff7f;
                write_done <= i_write_done[7];
            end
            'd8: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 8 + 10:`MEM_ADDR_WIDTH * 8];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 8 + 127:`DATA_FRAME_NUM * 8];
                wea = i_wea[8];
                o_wr_apply_success <= 16'h0100;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfeff;
                write_done <= i_write_done[8];
            end
            'd9: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 9 + 10:`MEM_ADDR_WIDTH * 9];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 9 + 127:`DATA_FRAME_NUM * 9];
                wea = i_wea[9];
                o_wr_apply_success <= 16'h0200;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfdff;
                write_done <= i_write_done[9];
            end
            'd10: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 10 + 10:`MEM_ADDR_WIDTH * 10];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 10 +127:`DATA_FRAME_NUM * 10];
                wea = i_wea[10];
                o_wr_apply_success <= 16'h0400;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hfbff;
                write_done <= i_write_done[10];
            end
            'd11: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 11 + 10:`MEM_ADDR_WIDTH * 11];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 11 +127:`DATA_FRAME_NUM * 11];
                wea = i_wea[11];
                o_wr_apply_success <= 16'h0800;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hf7ff;
                write_done <= i_write_done[11];
            end
            'd12: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 12 + 10:`MEM_ADDR_WIDTH * 12];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 12 +127:`DATA_FRAME_NUM * 12];
                wea = i_wea[12];
                o_wr_apply_success <= 16'h1000;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hefff;
                write_done <= i_write_done[12];
            end
            'd13: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 13 + 10:`MEM_ADDR_WIDTH * 13];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 13 +127:`DATA_FRAME_NUM * 13];
                wea = i_wea[13];
                o_wr_apply_success <= 16'h2000;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hdfff;
                write_done <= i_write_done[13];
            end
            'd14: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 14 + 10:`MEM_ADDR_WIDTH * 14];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 14 +127:`DATA_FRAME_NUM * 14];
                wea = i_wea[14];
                o_wr_apply_success <= 16'h4000;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'hbfff;
                write_done <= i_write_done[14];
            end
            'd15: begin
                wr_phy_addr = i_wr_phy_addr[`MEM_ADDR_WIDTH * 15 + 10:`MEM_ADDR_WIDTH * 15];
                wr_data = i_wr_data[`DATA_FRAME_NUM * 15 +127:`DATA_FRAME_NUM * 15];
                wea = i_wea[15];
                o_wr_apply_success <= 16'h8000;
                o_wr_apply_refuse <= i_wr_apply_sig & 16'h7fff;
                write_done <= i_write_done[15];
            end
        endcase
    end
    else begin 
        wr_phy_addr = wr_phy_addr;
        wr_data = wr_data;
        wea = wea;
        o_wr_apply_success <= o_wr_apply_success;
        o_wr_apply_refuse <= o_wr_apply_refuse;
        write_done <= write_done;
    end
end

sram_128x2048 sram_u(
    .addra(wr_phy_addr),
    .clka(i_clk),
    .dina(wr_data),
    .wea(wea),

    .addrb(i_rd_phy_addr),
    .clkb(i_rd_clk),
    .doutb(o_rd_data)
);

endmodule
