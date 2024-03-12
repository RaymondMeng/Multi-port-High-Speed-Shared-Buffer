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
// Additional Comments:
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
    /*serial data output control*/
    output              [`DATA_WIDTH-1:0]           o_sdata,
    output                                          o_data_valid
    );

reg [1:0] cnt;
reg fifo1_rd_en, fifo2_rd_en, fifo3_rd_en, fifo4_rd_en;
reg fifo1_rd_en_d, fifo2_rd_en_d, fifo3_rd_en_d, fifo4_rd_en_d;

assign o_fifo1_rd_en = fifo1_rd_en;
assign o_fifo2_rd_en = fifo2_rd_en;
assign o_fifo3_rd_en = fifo3_rd_en;
assign o_fifo4_rd_en = fifo4_rd_en;

/* 2bit-count & fifo_rd_en信号打拍 */
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        cnt <= 'd0;
        fifo1_rd_en_d <= 1'b0;
        fifo2_rd_en_d <= 1'b0;
        fifo3_rd_en_d <= 1'b0;
        fifo4_rd_en_d <= 1'b0;
    end
    else begin
        cnt <= cnt + 1'b1;
        fifo1_rd_en_d <= fifo1_rd_en;
        fifo2_rd_en_d <= fifo2_rd_en;
        fifo3_rd_en_d <= fifo3_rd_en;
        fifo4_rd_en_d <= fifo4_rd_en;
    end
end

/*mux*/
always @(*) begin
    fifo1_rd_en = 'b0;
    fifo2_rd_en = 'b0;
    fifo3_rd_en = 'b0;
    fifo4_rd_en = 'b0;
    if (cnt == 2'd0) begin
        fifo1_rd_en = ~i_fifo1_empty;
    end
    else if(cnt == 2'd1) begin
        fifo2_rd_en = ~i_fifo2_empty;
    end
    else if(cnt == 2'd2) begin
        fifo3_rd_en = ~i_fifo3_empty;
    end
    else if(cnt == 2'd3) begin
        fifo4_rd_en = ~i_fifo4_empty;
    end
end

assign o_data_valid = fifo1_rd_en_d | fifo2_rd_en_d | fifo3_rd_en_d | fifo4_rd_en_d;
assign o_sdata = fifo1_rd_en_d ? i_fifo1_data :
                (fifo2_rd_en_d ? i_fifo2_data :
                (fifo3_rd_en_d ? i_fifo3_data :
                (fifo4_rd_en_d ? i_fifo4_data : 64'dz)));


endmodule
