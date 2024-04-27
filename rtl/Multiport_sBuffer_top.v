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

    /*port2 interface*/
    input                           p2_wr_sop,
    input                           p2_wr_eop,
    input                           p2_wr_vld,
    input       [`DATA_WIDTH-1:0]   p2_wr_data,
    
    output                          p2_almost_full,
    output                          p2_full,

    /*port3 interface*/
    input                           p3_wr_sop,
    input                           p3_wr_eop,
    input                           p3_wr_vld,
    input       [`DATA_WIDTH-1:0]   p3_wr_data,
    
    output                          p3_almost_full,
    output                          p3_full,

    /*port4 interface*/
    input                           p4_wr_sop,
    input                           p4_wr_eop,
    input                           p4_wr_vld,
    input       [`DATA_WIDTH-1:0]   p4_wr_data,
    
    output                          p4_almost_full,
    output                          p4_full,

    /*port5 interface*/
    input                           p5_wr_sop,
    input                           p5_wr_eop,
    input                           p5_wr_vld,
    input       [`DATA_WIDTH-1:0]   p5_wr_data,
    
    output                          p5_almost_full,
    output                          p5_full,

    /*port6 interface*/
    input                           p6_wr_sop,
    input                           p6_wr_eop,
    input                           p6_wr_vld,
    input       [`DATA_WIDTH-1:0]   p6_wr_data,
    
    output                          p6_almost_full,
    output                          p6_full,

    /*port7 interface*/
    input                           p7_wr_sop,
    input                           p7_wr_eop,
    input                           p7_wr_vld,
    input       [`DATA_WIDTH-1:0]   p7_wr_data,
    
    output                          p7_almost_full,
    output                          p7_full,

    /*port8 interface*/
    input                           p8_wr_sop,
    input                           p8_wr_eop,
    input                           p8_wr_vld,
    input       [`DATA_WIDTH-1:0]   p8_wr_data,
    
    output                          p8_almost_full,
    output                          p8_full,

    /*port9 interface*/
    input                           p9_wr_sop,
    input                           p9_wr_eop,
    input                           p9_wr_vld,
    input       [`DATA_WIDTH-1:0]   p9_wr_data,
    
    output                          p9_almost_full,
    output                          p9_full,

    /*port10 interface*/
    input                           p10_wr_sop,
    input                           p10_wr_eop,
    input                           p10_wr_vld,
    input       [`DATA_WIDTH-1:0]   p10_wr_data,
    
    output                          p10_almost_full,
    output                          p10_full,

    /*port11 interface*/
    input                           p11_wr_sop,
    input                           p11_wr_eop,
    input                           p11_wr_vld,
    input       [`DATA_WIDTH-1:0]   p11_wr_data,
    
    output                          p11_almost_full,
    output                          p11_full,

    /*port12 interface*/
    input                           p12_wr_sop,
    input                           p12_wr_eop,
    input                           p12_wr_vld,
    input       [`DATA_WIDTH-1:0]   p12_wr_data,
    
    output                          p12_almost_full,
    output                          p12_full,

    /*port13 interface*/
    input                           p13_wr_sop,
    input                           p13_wr_eop,
    input                           p13_wr_vld,
    input       [`DATA_WIDTH-1:0]   p13_wr_data,
    
    output                          p13_almost_full,
    output                          p13_full,

    /*port14 interface*/
    input                           p14_wr_sop,
    input                           p14_wr_eop,
    input                           p14_wr_vld,
    input       [`DATA_WIDTH-1:0]   p14_wr_data,
    
    output                          p14_almost_full,
    output                          p14_full,

    /*port15 interface*/
    input                           p15_wr_sop,
    input                           p15_wr_eop,
    input                           p15_wr_vld,
    input       [`DATA_WIDTH-1:0]   p15_wr_data,
    
    output                          p15_almost_full,
    output                          p15_full,

    /*port16 interface*/
    input                           p16_wr_sop,
    input                           p16_wr_eop,
    input                           p16_wr_vld,
    input       [`DATA_WIDTH-1:0]   p16_wr_data,
    
    output                          p16_almost_full,
    output                          p16_full

    );

wire [`DATA_WIDTH-1:0] p1_dout, p2_dout, p3_dout, p4_dout, p5_dout, p6_dout, p7_dout, p8_dout, p9_dout, p10_dout, p11_dout, p12_dout, p13_dout, p14_dout, p15_dout, p16_dout;
wire p1_empty, p2_empty, p3_empty, p4_empty, p5_empty, p6_empty, p7_empty, p8_empty, p9_empty, p10_empty, p11_empty, p12_empty, p13_empty, p14_empty, p15_empty, p16_empty;
wire p1_wr_en, p2_wr_en, p3_wr_en, p4_wr_en, p5_wr_en, p6_wr_en, p7_wr_en, p8_wr_en, p9_wr_en, p10_wr_en, p11_wr_en, p12_wr_en, p13_wr_en, p14_wr_en, p15_wr_en, p16_wr_en;
wire p1_rd_en, p2_rd_en, p3_rd_en, p4_rd_en, p5_rd_en, p6_rd_en, p7_rd_en, p8_rd_en, p9_rd_en, p10_rd_en, p11_rd_en, p12_rd_en, p13_rd_en, p14_rd_en, p15_rd_en, p16_rd_en;
// wire [`DATA_WIDTH-1:0] sdata;
// wire sdat_valid;
//wire [7:0] p1_dat_count, p2_dat_count, p3_dat_count, p4_dat_count;

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

port_input_fifo port5_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p5_wr_data),                  // input wire [63 : 0] din
  .wr_en(p5_wr_vld),              // input wire wr_en
  .rd_en(p5_rd_en),              // input wire rd_en
  .dout(p5_dout),                // output wire [63 : 0] dout
  .full(p5_full),                // output wire full
  .almost_full(p5_almost_full),  // output wire almost_full
  .empty(p5_empty)              // output wire empty
);

port_input_fifo port6_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p6_wr_data),                  // input wire [63 : 0] din
  .wr_en(p6_wr_vld),              // input wire wr_en
  .rd_en(p6_rd_en),              // input wire rd_en
  .dout(p6_dout),                // output wire [63 : 0] dout
  .full(p6_full),                // output wire full
  .almost_full(p6_almost_full),  // output wire almost_full
  .empty(p6_empty)              // output wire empty
);

port_input_fifo port7_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p7_wr_data),                  // input wire [63 : 0] din
  .wr_en(p7_wr_vld),              // input wire wr_en
  .rd_en(p7_rd_en),              // input wire rd_en
  .dout(p7_dout),                // output wire [63 : 0] dout
  .full(p7_full),                // output wire full
  .almost_full(p7_almost_full),  // output wire almost_full
  .empty(p7_empty)              // output wire empty
);

port_input_fifo port8_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p8_wr_data),                  // input wire [63 : 0] din
  .wr_en(p8_wr_vld),              // input wire wr_en
  .rd_en(p8_rd_en),              // input wire rd_en
  .dout(p8_dout),                // output wire [63 : 0] dout
  .full(p8_full),                // output wire full
  .almost_full(p8_almost_full),  // output wire almost_full
  .empty(p8_empty)              // output wire empty
);

port_input_fifo port9_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p9_wr_data),                  // input wire [63 : 0] din
  .wr_en(p9_wr_vld),              // input wire wr_en
  .rd_en(p9_rd_en),              // input wire rd_en
  .dout(p9_dout),                // output wire [63 : 0] dout
  .full(p9_full),                // output wire full
  .almost_full(p9_almost_full),  // output wire almost_full
  .empty(p9_empty)              // output wire empty
);

port_input_fifo port10_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p10_wr_data),                  // input wire [63 : 0] din
  .wr_en(p10_wr_vld),              // input wire wr_en
  .rd_en(p10_rd_en),              // input wire rd_en
  .dout(p10_dout),                // output wire [63 : 0] dout
  .full(p10_full),                // output wire full
  .almost_full(p10_almost_full),  // output wire almost_full
  .empty(p10_empty)              // output wire empty
);

port_input_fifo port11_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p11_wr_data),                  // input wire [63 : 0] din
  .wr_en(p11_wr_vld),              // input wire wr_en
  .rd_en(p11_rd_en),              // input wire rd_en
  .dout(p11_dout),                // output wire [63 : 0] dout
  .full(p11_full),                // output wire full
  .almost_full(p11_almost_full),  // output wire almost_full
  .empty(p11_empty)              // output wire empty
);

port_input_fifo port12_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p12_wr_data),                  // input wire [63 : 0] din
  .wr_en(p12_wr_vld),              // input wire wr_en
  .rd_en(p12_rd_en),              // input wire rd_en
  .dout(p12_dout),                // output wire [63 : 0] dout
  .full(p12_full),                // output wire full
  .almost_full(p12_almost_full),  // output wire almost_full
  .empty(p12_empty)              // output wire empty
);

port_input_fifo port13_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p13_wr_data),                  // input wire [63 : 0] din
  .wr_en(p13_wr_vld),              // input wire wr_en
  .rd_en(p13_rd_en),              // input wire rd_en
  .dout(p13_dout),                // output wire [63 : 0] dout
  .full(p13_full),                // output wire full
  .almost_full(p13_almost_full),  // output wire almost_full
  .empty(p13_empty)              // output wire empty
);

port_input_fifo port14_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p14_wr_data),                  // input wire [63 : 0] din
  .wr_en(p14_wr_vld),              // input wire wr_en
  .rd_en(p14_rd_en),              // input wire rd_en
  .dout(p14_dout),                // output wire [63 : 0] dout
  .full(p14_full),                // output wire full
  .almost_full(p14_almost_full),  // output wire almost_full
  .empty(p14_empty)              // output wire empty
);

port_input_fifo port15_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p15_wr_data),                  // input wire [63 : 0] din
  .wr_en(p15_wr_vld),              // input wire wr_en
  .rd_en(p15_rd_en),              // input wire rd_en
  .dout(p15_dout),                // output wire [63 : 0] dout
  .full(p15_full),                // output wire full
  .almost_full(p15_almost_full),  // output wire almost_full
  .empty(p15_empty)              // output wire empty
);

port_input_fifo port16_input_inst (
  .clk(clk),                  // input wire clk
  .srst(~rst_n),                // input wire srst
  .din(p16_wr_data),                  // input wire [63 : 0] din
  .wr_en(p16_wr_vld),              // input wire wr_en
  .rd_en(p16_rd_en),              // input wire rd_en
  .dout(p16_dout),                // output wire [63 : 0] dout
  .full(p16_full),                // output wire full
  .almost_full(p16_almost_full),  // output wire almost_full
  .empty(p16_empty)              // output wire empty
);

// enter_arbitr enter_arbitr_inst(
//     .clk                      (clk),      
//     .rst_n                    (rst_n), 
//     /*fifo1 interface*/ 
//     .i_fifo1_empty            (p1_empty),
//     .i_fifo1_data             (p1_dout),
//     .o_fifo1_rd_en            (p1_rd_en),
//     /*fifo2 interface*/
//     .i_fifo2_empty            (p2_empty),
//     .i_fifo2_data             (p2_dout),
//     .o_fifo2_rd_en            (p2_rd_en),
//     /*fifo3 interface*/
//     .i_fifo3_empty            (p3_empty),
//     .i_fifo3_data             (p3_dout),
//     .o_fifo3_rd_en            (p3_rd_en),
//     /*fifo4 interface*/
//     .i_fifo4_empty            (p4_empty),
//     .i_fifo4_data             (p4_dout),
//     .o_fifo4_rd_en            (p4_rd_en)
//     // .o_sdata                  (sdata),
//     // .o_data_valid             (sdat_valid)
//     );

Port1_SGDMA Port1_SGDMA_inst(
    i_clk(clk),
    i_rst_n(rst_n),
    o_rd_en(p1_rd_en),
    i_dat(p1_dout),
    i_empty(p1_empty),
    i_sop(p1_wr_sop), //TODO:sop和eop需要和fifo读出同步,和rd_en&
    i_eop(p1_wr_eop)
);


endmodule
