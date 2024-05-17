`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// team: 极链缘起
// Engineer: mengcheng
// 
// Create Date: 2024/03/10 00:08:44
// Design Name: high speed multi-port shared buffer
// Module Name: Multiport_sBuffer_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "defines.v"

module Multiport_sBuffer_top(
    input                           clk,
    input                           rst_n,

    /*port1 interface*/
    input                           p1_wr_sop,
    input                           p1_wr_eop,
    input                           p1_wr_vld,
    input       [`DATA_WIDTH-1:0]   p1_wr_data,
    
    output                          p1_almost_full,
    output                          p1_full,

    //output interface
    input                           p1_ready,
    output      [`DATA_WIDTH-1:0]   p1_rd_data,
    output                          p1_rd_sop,
    output                          p1_rd_eop,
    output                          p1_rd_vld,

    /*port2 interface*/
    input                           p2_wr_sop,
    input                           p2_wr_eop,
    input                           p2_wr_vld,
    input       [`DATA_WIDTH-1:0]   p2_wr_data,
    
    output                          p2_almost_full,
    output                          p2_full,

    input                           p2_ready,
    output      [`DATA_WIDTH-1:0]   p2_rd_data,
    output                          p2_rd_sop,
    output                          p2_rd_eop,
    output                          p2_rd_vld,

    /*port3 interface*/
    input                           p3_wr_sop,
    input                           p3_wr_eop,
    input                           p3_wr_vld,
    input       [`DATA_WIDTH-1:0]   p3_wr_data,
    
    output                          p3_almost_full,
    output                          p3_full,

    input                           p3_ready,
    output      [`DATA_WIDTH-1:0]   p3_rd_data,
    output                          p3_rd_sop,
    output                          p3_rd_eop,
    output                          p3_rd_vld,

    /*port4 interface*/
    input                           p4_wr_sop,
    input                           p4_wr_eop,
    input                           p4_wr_vld,
    input       [`DATA_WIDTH-1:0]   p4_wr_data,
    
    output                          p4_almost_full,
    output                          p4_full,
    
    input                           p4_ready,
    output      [`DATA_WIDTH-1:0]   p4_rd_data,
    output                          p4_rd_sop,
    output                          p4_rd_eop,
    output                          p4_rd_vld  
    );

wire [`DATA_WIDTH-1:0] p1_dout, p2_dout, p3_dout, p4_dout;
wire p1_empty, p2_empty, p3_empty, p4_empty;
wire p1_wr_en, p2_wr_en, p3_wr_en, p4_wr_en;
wire p1_rd_en, p2_rd_en, p3_rd_en, p4_rd_en;
wire [`DATA_WIDTH-1:0] sdata;
wire sdat_valid;
wire [7:0] p1_dat_count, p2_dat_count, p3_dat_count, p4_dat_count;

assign #10 p1_rd_data =  p1_ready ? p1_wr_data : 'd0;
assign #10 p1_rd_sop =  p1_ready ? p1_wr_sop : 1'b0;
assign #10 p1_rd_eop =  p1_ready ? p1_wr_eop : 1'b0;
assign #10 p1_rd_vld =  p1_ready ? p1_wr_vld : 1'b0;

assign #10 p2_rd_data =  p2_ready ? p2_wr_data : 'd0;
assign #10 p2_rd_sop =  p2_ready ? p2_wr_sop : 1'b0;
assign #10 p2_rd_eop =  p2_ready ? p2_wr_eop : 1'b0;
assign #10 p2_rd_vld =  p2_ready ? p2_wr_vld : 1'b0;

assign #10 p3_rd_data =  p3_ready ? p3_wr_data : 'd0;
assign #10 p3_rd_sop =  p3_ready ? p3_wr_sop : 1'b0;
assign #10 p3_rd_eop =  p3_ready ? p3_wr_eop : 1'b0;
assign #10 p3_rd_vld =  p3_ready ? p3_wr_vld : 1'b0;

assign #10 p4_rd_data =  p4_ready ? p4_wr_data : 'd0;
assign #10 p4_rd_sop =  p4_ready ? p4_wr_sop : 1'b0;
assign #10 p4_rd_eop =  p4_ready ? p4_wr_eop : 1'b0;
assign #10 p4_rd_vld =  p4_ready ? p4_wr_vld : 1'b0;

/*fifo read latency: one cycle*/
port_input_fifo port1_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p1_wr_data),                  // input wire [63 : 0] din
  .wr_en(p1_wr_vld),              // input wire wr_en
  .rd_en(p1_rd_en),              // input wire rd_en
  .dout(p1_dout),                // output wire [63 : 0] dout
  .full(p1_full),                // output wire full
  .almost_full(p1_almost_full),  // output wire almost_full
  .empty(p1_empty)              // output wire empty
);

port_input_fifo port2_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p2_wr_data),                  // input wire [63 : 0] din
  .wr_en(p2_wr_vld),              // input wire wr_en
  .rd_en(p2_rd_en),              // input wire rd_en
  .dout(p2_dout),                // output wire [63 : 0] dout
  .full(p2_full),                // output wire full
  .almost_full(p2_almost_full),  // output wire almost_full
  .empty(p2_empty)              // output wire empty
);

port_input_fifo port3_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p3_wr_data),                  // input wire [63 : 0] din
  .wr_en(p3_wr_vld),              // input wire wr_en
  .rd_en(p3_rd_en),              // input wire rd_en
  .dout(p3_dout),                // output wire [63 : 0] dout
  .full(p3_full),                // output wire full
  .almost_full(p3_almost_full),  // output wire almost_full
  .empty(p3_empty)              // output wire empty
);

port_input_fifo port4_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p4_wr_data),                  // input wire [63 : 0] din
  .wr_en(p4_wr_vld),              // input wire wr_en
  .rd_en(p4_rd_en),              // input wire rd_en
  .dout(p4_dout),                // output wire [63 : 0] dout
  .full(p4_full),                // output wire full
  .almost_full(p4_almost_full),  // output wire almost_full
  .empty(p4_empty)              // output wire empty
);

enter_arbitr enter_arbitr_inst(
    .clk                      (clk),      
    .rst_n                    (rst_n), 
    /*fifo1 interface*/ 
    .i_fifo1_empty            (p1_empty),
    .i_fifo1_data             (p1_dout),
    .o_fifo1_rd_en            (p1_rd_en),
    /*fifo2 interface*/
    .i_fifo2_empty            (p2_empty),
    .i_fifo2_data             (p2_dout),
    .o_fifo2_rd_en            (p2_rd_en),
    /*fifo3 interface*/
    .i_fifo3_empty            (p3_empty),
    .i_fifo3_data             (p3_dout),
    .o_fifo3_rd_en            (p3_rd_en),
    /*fifo4 interface*/
    .i_fifo4_empty            (p4_empty),
    .i_fifo4_data             (p4_dout),
    .o_fifo4_rd_en            (p4_rd_en),
    .o_sdata                  (sdata),
    .o_data_valid             (sdat_valid)
    );

endmodule
