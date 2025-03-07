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
    input                           clk, //250MHz
    input                           rst_n,

    /*port1 interface*/
    //write
    input                           p1_wr_sop,
    input                           p1_wr_eop,
    input                           p1_wr_vld,
    input       [`DATA_WIDTH-1:0]   p1_wr_data,
    
    output                          p1_almost_full,
    output                          p1_full,
    //read
    output                          p1_rd_sop,
    output                          p1_rd_eop,
    output                          p1_rd_vld,
    output       [`DATA_WIDTH-1:0]  p1_rd_data,
    input                           p1_rd_ready,

    /*port2 interface*/
    //write
    input                           p2_wr_sop,
    input                           p2_wr_eop,
    input                           p2_wr_vld,
    input       [`DATA_WIDTH-1:0]   p2_wr_data,
    
    output                          p2_almost_full,
    output                          p2_full,

    //read
    output                          p2_rd_sop,
    output                          p2_rd_eop,
    output                          p2_rd_vld,
    output       [`DATA_WIDTH-1:0]  p2_rd_data,
    input                           p2_rd_ready,

    /*port3 interface*/
    //write
    input                           p3_wr_sop,
    input                           p3_wr_eop,
    input                           p3_wr_vld,
    input       [`DATA_WIDTH-1:0]   p3_wr_data,
    
    output                          p3_almost_full,
    output                          p3_full,

    //read
    output                          p3_rd_sop,
    output                          p3_rd_eop,
    output                          p3_rd_vld,
    output       [`DATA_WIDTH-1:0]  p3_rd_data,
    input                           p3_rd_ready,

    /*port4 interface*/
    //write
    input                           p4_wr_sop,
    input                           p4_wr_eop,
    input                           p4_wr_vld,
    input       [`DATA_WIDTH-1:0]   p4_wr_data,
    
    output                          p4_almost_full,
    output                          p4_full,

    //read
    output                          p4_rd_sop,
    output                          p4_rd_eop,
    output                          p4_rd_vld,
    output       [`DATA_WIDTH-1:0]  p4_rd_data,
    input                           p4_rd_ready,

    /*port5 interface*/
    //write
    input                           p5_wr_sop,
    input                           p5_wr_eop,
    input                           p5_wr_vld,
    input       [`DATA_WIDTH-1:0]   p5_wr_data,
    
    output                          p5_almost_full,
    output                          p5_full,

    //read
    output                          p5_rd_sop,
    output                          p5_rd_eop,
    output                          p5_rd_vld,
    output       [`DATA_WIDTH-1:0]  p5_rd_data,
    input                           p5_rd_ready,

    /*port6 interface*/
    //write
    input                           p6_wr_sop,
    input                           p6_wr_eop,
    input                           p6_wr_vld,
    input       [`DATA_WIDTH-1:0]   p6_wr_data,
    
    output                          p6_almost_full,
    output                          p6_full,

    //read
    output                          p6_rd_sop,
    output                          p6_rd_eop,
    output                          p6_rd_vld,
    output       [`DATA_WIDTH-1:0]  p6_rd_data,
    input                           p6_rd_ready,

    /*port7 interface*/
    //write
    input                           p7_wr_sop,
    input                           p7_wr_eop,
    input                           p7_wr_vld,
    input       [`DATA_WIDTH-1:0]   p7_wr_data,
    
    output                          p7_almost_full,
    output                          p7_full,

    //read
    output                          p7_rd_sop,
    output                          p7_rd_eop,
    output                          p7_rd_vld,
    output       [`DATA_WIDTH-1:0]  p7_rd_data,
    input                           p7_rd_ready,

    /*port8 interface*/
    //write
    input                           p8_wr_sop,
    input                           p8_wr_eop,
    input                           p8_wr_vld,
    input       [`DATA_WIDTH-1:0]   p8_wr_data,
    
    output                          p8_almost_full,
    output                          p8_full,

    //read
    output                          p8_rd_sop,
    output                          p8_rd_eop,
    output                          p8_rd_vld,
    output       [`DATA_WIDTH-1:0]  p8_rd_data,
    input                           p8_rd_ready,

    /*port9 interface*/
    //write
    input                           p9_wr_sop,
    input                           p9_wr_eop,
    input                           p9_wr_vld,
    input       [`DATA_WIDTH-1:0]   p9_wr_data,
    
    output                          p9_almost_full,
    output                          p9_full,

    //read
    output                          p9_rd_sop,
    output                          p9_rd_eop,
    output                          p9_rd_vld,
    output       [`DATA_WIDTH-1:0]  p9_rd_data,
    input                           p9_rd_ready,

    /*port10 interface*/
    //write
    input                           p10_wr_sop,
    input                           p10_wr_eop,
    input                           p10_wr_vld,
    input       [`DATA_WIDTH-1:0]   p10_wr_data,
    
    output                          p10_almost_full,
    output                          p10_full,

    //read
    output                          p10_rd_sop,
    output                          p10_rd_eop,
    output                          p10_rd_vld,
    output       [`DATA_WIDTH-1:0]  p10_rd_data,
    input                           p10_rd_ready,

    /*port11 interface*/
    //write
    input                           p11_wr_sop,
    input                           p11_wr_eop,
    input                           p11_wr_vld,
    input       [`DATA_WIDTH-1:0]   p11_wr_data,
    
    output                          p11_almost_full,
    output                          p11_full,

    //read
    output                          p11_rd_sop,
    output                          p11_rd_eop,
    output                          p11_rd_vld,
    output       [`DATA_WIDTH-1:0]  p11_rd_data,
    input                           p11_rd_ready,

    /*port12 interface*/
    //write
    input                           p12_wr_sop,
    input                           p12_wr_eop,
    input                           p12_wr_vld,
    input       [`DATA_WIDTH-1:0]   p12_wr_data,
    
    output                          p12_almost_full,
    output                          p12_full,

    //read
    output                          p12_rd_sop,
    output                          p12_rd_eop,
    output                          p12_rd_vld,
    output       [`DATA_WIDTH-1:0]  p12_rd_data,
    input                           p12_rd_ready,

    /*port13 interface*/
    //write
    input                           p13_wr_sop,
    input                           p13_wr_eop,
    input                           p13_wr_vld,
    input       [`DATA_WIDTH-1:0]   p13_wr_data,
    
    output                          p13_almost_full,
    output                          p13_full,

    //read
    output                          p13_rd_sop,
    output                          p13_rd_eop,
    output                          p13_rd_vld,
    output       [`DATA_WIDTH-1:0]  p13_rd_data,
    input                           p13_rd_ready,

    /*port14 interface*/
    //write
    input                           p14_wr_sop,
    input                           p14_wr_eop,
    input                           p14_wr_vld,
    input       [`DATA_WIDTH-1:0]   p14_wr_data,
    
    output                          p14_almost_full,
    output                          p14_full,

    //read
    output                          p14_rd_sop,
    output                          p14_rd_eop,
    output                          p14_rd_vld,
    output       [`DATA_WIDTH-1:0]  p14_rd_data,
    input                           p14_rd_ready,

    /*port15 interface*/
    //write
    input                           p15_wr_sop,
    input                           p15_wr_eop,
    input                           p15_wr_vld,
    input       [`DATA_WIDTH-1:0]   p15_wr_data,
    
    output                          p15_almost_full,
    output                          p15_full,

    //read
    output                          p15_rd_sop,
    output                          p15_rd_eop,
    output                          p15_rd_vld,
    output       [`DATA_WIDTH-1:0]  p15_rd_data,
    input                           p15_rd_ready,

    /*port16 interface*/
    //write
    input                           p16_wr_sop,
    input                           p16_wr_eop,
    input                           p16_wr_vld,
    input       [`DATA_WIDTH-1:0]   p16_wr_data,
    
    output                          p16_almost_full,
    output                          p16_full,

    //read
    output                          p16_rd_sop,
    output                          p16_rd_eop,
    output                          p16_rd_vld,
    output       [`DATA_WIDTH-1:0]  p16_rd_data,
    input                           p16_rd_ready
    );

//input fifo
// wire [`DATA_DWIDTH-1:0] p1_dout, p2_dout, p3_dout, p4_dout, p5_dout, p6_dout, p7_dout, p8_dout, p9_dout, p10_dout, p11_dout, p12_dout, p13_dout, p14_dout, p15_dout, p16_dout;
// wire p1_empty, p2_empty, p3_empty, p4_empty, p5_empty, p6_empty, p7_empty, p8_empty, p9_empty, p10_empty, p11_empty, p12_empty, p13_empty, p14_empty, p15_empty, p16_empty;
// wire p1_rd_en, p2_rd_en, p3_rd_en, p4_rd_en, p5_rd_en, p6_rd_en, p7_rd_en, p8_rd_en, p9_rd_en, p10_rd_en, p11_rd_en, p12_rd_en, p13_rd_en, p14_rd_en, p15_rd_en, p16_rd_en;
// wire [`DATA_WIDTH-1:0] port_wr_data [0:`PORT_NUM-1];
// wire port_wr_vld [0:`PORT_NUM-1];
wire [`PORT_NUM-1:0] port_rd_en ;
wire [`DATA_DWIDTH-1:0] port_dout [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] port_full ;
wire [`PORT_NUM-1:0] port_empty ;
wire [`PORT_NUM-1:0] port_almost_full ;
wire [`PORT_NUM-1:0] port_wr_sop ;
wire [`PORT_NUM-1:0] port_wr_eop ;
wire [`PORT_NUM-1:0] port_rd_ready;
reg  [`PORT_NUM-1:0] port_rd_sop, port_rd_eop;
wire [`PORT_NUM-1:0] port_rd_vld;

// wire [`DATA_WIDTH-1:0] sdata;
// wire sdat_valid;
//wire [7:0] p1_dat_count, p2_dat_count, p3_dat_count, p4_dat_count;

//crossbar buffer defines
// wire [`DISPATCH_WIDTH-1:0] cb11_din, cb12_din, cb13_din, cb14_din;
// wire cb11_wr_en, cb12_wr_en, cb13_wr_en, cb14_wr_en;
// wire [`DISPATCH_WIDTH-1:0] cb11_dout, cb12_dout, cb13_dout, cb14_dout;
// wire cb11_full, cb12_full, cb13_full, cb14_full;
// wire cb11_empty, cb12_empty, cb13_empty, cb14_empty;
// wire cb11_rd_en, cb12_rd_en, cb13_rd_en, cb14_rd_en;
wire [`CROSSBAR_DIMENSION-1:0] cb_wr_en;
wire [1:0] cb_sel [`CROSSBAR_DIMENSION-1:0];
wire [`DISPATCH_WIDTH-1:0] cb_din [`CROSSBAR_DIMENSION-1:0];
wire [4:0] cb_col_queue_sel[`CROSSBAR_DIMENSION-1:0];
wire [`DISPATCH_WIDTH-1:0] cb_col_dout[`CROSSBAR_DIMENSION-1:0];
wire [`CROSSBAR_DIMENSION-1:0] cb_col_dat_valid;

//sgdma defines & schedule_fifo defines
// wire [`DISPATCH_WIDTH-1:0] sf1_din, sf2_din, sf3_din, sf4_din;
// wire sf1_wr_en, sf2_wr_en, sf3_wr_en, sf4_wr_en;
// wire sf1_full, sf2_full, sf3_full, sf4_full;
wire [`DISPATCH_WIDTH-1:0] sf_din [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] sf_wr_en ;
wire [`PORT_NUM-1:0] sf_full ;
wire [`PORT_NUM-1:0] fp_wr_en ;
wire [`ADDR_WIDTH-1:0] fp_wr_dat [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] fp_list_full;

//mmu defines
// wire mmu_p1_wr_req, mmu_p2_wr_req, mmu_p3_wr_req, mmu_p4_wr_req; //write request
// wire mmu_p1_wr_ready, mmu_p2_wr_ready, mmu_p3_wr_ready, mmu_p4_wr_ready;
// wire mmu_p1_wr_en, mmu_p2_wr_en, mmu_p3_wr_en, mmu_p4_wr_en;
// wire [`ADDR_WIDTH-1:0] mmu_p1_wr_addr, mmu_p2_wr_addr, mmu_p3_wr_addr, mmu_p4_wr_addr;
// wire [`DATA_DWIDTH-1:0] mmu_p1_wr_dat, mmu_p2_wr_dat, mmu_p3_wr_dat, mmu_p4_wr_dat;
wire [`PORT_NUM-1:0] mmu_wr_req ;
wire [`PORT_NUM-1:0] mmu_wr_done;
wire [`PORT_NUM-1:0] mmu_wr_ready ;
wire [`PORT_NUM-1:0] mmu_wr_en ;
wire [`ADDR_WIDTH-1:0] mmu_wr_addr [`PORT_NUM-1:0];
wire [`DATA_DWIDTH-1:0] mmu_wr_dat [`PORT_NUM-1:0];
 
//mmu read interface
wire [`PORT_NUM-1:0] mmu_rd_clk; //读取mmu输出接口
wire [`DATA_DWIDTH-1:0] mmu_rd_dout [`PORT_NUM-1:0]; //读取mmu输出接口
wire [`PORT_NUM-1:0] opt_fifo_wr_en; //mmu输出写入fifo
reg [`PORT_NUM-1:0] opt_fifo_rd_en, opt_fifo_rd_en_r; //读取fifo输出端口
wire [`DATA_WIDTH-1:0] opt_fifo_rd_dout [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] opt_fifo_empty;

//freelist interface 
// wire fp_p1_wr_en, fp_p2_wr_en, fp_p3_wr_en, fp_p4_wr_en;
// wire [`ADDR_WIDTH-1:0] fp_p1_wr_dat, fp_p2_wr_dat, fp_p3_wr_dat, fp_p4_wr_dat;
// wire fp_p1_list_full, fp_p2_list_full, fp_p3_list_full, fp_p4_list_full;

//clock
wire locked;
wire clk_125MHz;

reg [`PORT_NUM-1:0] mmu_rd_req;
wire [`DISPATCH_WIDTH-1:0] mmu_rd_aply_dat [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] mmu_rd_ready;
wire [`PORT_NUM-1:0] mmu_rd_done;

//out of queue interface
reg [`PORT_NUM-1:0] ooqc_rd_en;
wire [`DISPATCH_WIDTH-1:0] ooqc_rd_dout [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] ooqc_rd_empty;

reg [2:0] rd_mem_state [`PORT_NUM-1:0];

MMCM_CLK_125MHz MMCM_CLK_125MHz_inst
   (
    // Clock out ports
    .clk_out1(clk_125MHz),     // output clk_out1
    // Status and control signals
    .resetn(rst_n), // input resetn
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(clk)      // input clk_in1
);

assign port_wr_sop[0] = p1_wr_sop;
assign port_wr_sop[1] = p2_wr_sop;
assign port_wr_sop[2] = p3_wr_sop;
assign port_wr_sop[3] = p4_wr_sop;
assign port_wr_sop[4] = p5_wr_sop;
assign port_wr_sop[5] = p6_wr_sop;
assign port_wr_sop[6] = p7_wr_sop;
assign port_wr_sop[7] = p8_wr_sop;
assign port_wr_sop[8] = p9_wr_sop;
assign port_wr_sop[9] = p10_wr_sop;
assign port_wr_sop[10] = p11_wr_sop;
assign port_wr_sop[11] = p12_wr_sop;
assign port_wr_sop[12] = p13_wr_sop;
assign port_wr_sop[13] = p14_wr_sop;
assign port_wr_sop[14] = p15_wr_sop;
assign port_wr_sop[15] = p16_wr_sop;

assign port_wr_eop[0]  = p1_wr_eop ;
assign port_wr_eop[1]  = p2_wr_eop ;
assign port_wr_eop[2]  = p3_wr_eop ;
assign port_wr_eop[3]  = p4_wr_eop ;
assign port_wr_eop[4]  = p5_wr_eop ;
assign port_wr_eop[5]  = p6_wr_eop ;
assign port_wr_eop[6]  = p7_wr_eop ;
assign port_wr_eop[7]  = p8_wr_eop ;
assign port_wr_eop[8]  = p9_wr_eop ;
assign port_wr_eop[9]  = p10_wr_eop;
assign port_wr_eop[10] = p11_wr_eop;
assign port_wr_eop[11] = p12_wr_eop;
assign port_wr_eop[12] = p13_wr_eop;
assign port_wr_eop[13] = p14_wr_eop;
assign port_wr_eop[14] = p15_wr_eop;
assign port_wr_eop[15] = p16_wr_eop;

assign   p1_full = port_full[0] ;
assign   p2_full = port_full[1] ;
assign   p3_full = port_full[2] ;
assign   p4_full = port_full[3] ;
assign   p5_full = port_full[4] ;
assign   p6_full = port_full[5] ;
assign   p7_full = port_full[6] ;
assign   p8_full = port_full[7] ;
assign   p9_full = port_full[8] ;
assign  p10_full = port_full[9] ;
assign  p11_full = port_full[10];
assign  p12_full = port_full[11];
assign  p13_full = port_full[12];
assign  p14_full = port_full[13];
assign  p15_full = port_full[14];
assign  p16_full = port_full[15];

assign  p1_almost_full = port_almost_full[0] ;
assign  p2_almost_full = port_almost_full[1] ;
assign  p3_almost_full = port_almost_full[2] ;
assign  p4_almost_full = port_almost_full[3] ;
assign  p5_almost_full = port_almost_full[4] ;
assign  p6_almost_full = port_almost_full[5] ;
assign  p7_almost_full = port_almost_full[6] ;
assign  p8_almost_full = port_almost_full[7] ;
assign  p9_almost_full = port_almost_full[8] ;
assign p10_almost_full = port_almost_full[9] ;
assign p11_almost_full = port_almost_full[10];
assign p12_almost_full = port_almost_full[11];
assign p13_almost_full = port_almost_full[12];
assign p14_almost_full = port_almost_full[13];
assign p15_almost_full = port_almost_full[14];
assign p16_almost_full = port_almost_full[15];

assign port_rd_ready[0]  = p1_rd_ready;
assign port_rd_ready[1]  = p2_rd_ready;
assign port_rd_ready[2]  = p3_rd_ready;
assign port_rd_ready[3]  = p4_rd_ready;
assign port_rd_ready[4]  = p5_rd_ready;
assign port_rd_ready[5]  = p6_rd_ready;
assign port_rd_ready[6]  = p7_rd_ready;
assign port_rd_ready[7]  = p8_rd_ready;
assign port_rd_ready[8]  = p9_rd_ready;
assign port_rd_ready[9]  = p10_rd_ready;
assign port_rd_ready[10] = p11_rd_ready;
assign port_rd_ready[11] = p12_rd_ready;
assign port_rd_ready[12] = p13_rd_ready;
assign port_rd_ready[13] = p14_rd_ready;
assign port_rd_ready[14] = p15_rd_ready;
assign port_rd_ready[15] = p16_rd_ready;

assign p1_rd_vld  = port_rd_vld[0];
assign p2_rd_vld  = port_rd_vld[1];
assign p3_rd_vld  = port_rd_vld[2];
assign p4_rd_vld  = port_rd_vld[3];
assign p5_rd_vld  = port_rd_vld[4];
assign p6_rd_vld  = port_rd_vld[5];
assign p7_rd_vld  = port_rd_vld[6];
assign p8_rd_vld  = port_rd_vld[7];
assign p9_rd_vld  = port_rd_vld[8];
assign p10_rd_vld = port_rd_vld[9];
assign p11_rd_vld = port_rd_vld[10];
assign p12_rd_vld = port_rd_vld[11];
assign p13_rd_vld = port_rd_vld[12];
assign p14_rd_vld = port_rd_vld[13];
assign p15_rd_vld = port_rd_vld[14];
assign p16_rd_vld = port_rd_vld[15];

assign p1_rd_sop  = port_rd_sop[0];
assign p2_rd_sop  = port_rd_sop[1];
assign p3_rd_sop  = port_rd_sop[2];
assign p4_rd_sop  = port_rd_sop[3];
assign p5_rd_sop  = port_rd_sop[4];
assign p6_rd_sop  = port_rd_sop[5];
assign p7_rd_sop  = port_rd_sop[6];
assign p8_rd_sop  = port_rd_sop[7];
assign p9_rd_sop  = port_rd_sop[8];
assign p10_rd_sop = port_rd_sop[9];
assign p11_rd_sop = port_rd_sop[10];
assign p12_rd_sop = port_rd_sop[11];
assign p13_rd_sop = port_rd_sop[12];
assign p14_rd_sop = port_rd_sop[13];
assign p15_rd_sop = port_rd_sop[14];
assign p16_rd_sop = port_rd_sop[15];

assign p1_rd_eop  = port_rd_eop[0];
assign p2_rd_eop  = port_rd_eop[1];
assign p3_rd_eop  = port_rd_eop[2];
assign p4_rd_eop  = port_rd_eop[3];
assign p5_rd_eop  = port_rd_eop[4];
assign p6_rd_eop  = port_rd_eop[5];
assign p7_rd_eop  = port_rd_eop[6];
assign p8_rd_eop  = port_rd_eop[7];
assign p9_rd_eop  = port_rd_eop[8];
assign p10_rd_eop = port_rd_eop[9];
assign p11_rd_eop = port_rd_eop[10];
assign p12_rd_eop = port_rd_eop[11];
assign p13_rd_eop = port_rd_eop[12];
assign p14_rd_eop = port_rd_eop[13];
assign p15_rd_eop = port_rd_eop[14];
assign p16_rd_eop = port_rd_eop[15];

assign p1_rd_data  = opt_fifo_rd_dout[0];
assign p2_rd_data  = opt_fifo_rd_dout[1];
assign p3_rd_data  = opt_fifo_rd_dout[2];
assign p4_rd_data  = opt_fifo_rd_dout[3];
assign p5_rd_data  = opt_fifo_rd_dout[4];
assign p6_rd_data  = opt_fifo_rd_dout[5];
assign p7_rd_data  = opt_fifo_rd_dout[6];
assign p8_rd_data  = opt_fifo_rd_dout[7];
assign p9_rd_data  = opt_fifo_rd_dout[8];
assign p10_rd_data = opt_fifo_rd_dout[9];
assign p11_rd_data = opt_fifo_rd_dout[10];
assign p12_rd_data = opt_fifo_rd_dout[11];
assign p13_rd_data = opt_fifo_rd_dout[12];
assign p14_rd_data = opt_fifo_rd_dout[13];
assign p15_rd_data = opt_fifo_rd_dout[14];
assign p16_rd_data = opt_fifo_rd_dout[15];

/*      端口输入fifo 
**  Descrip: 端口输入数据后缓存
**  write  : port
**  read   : Port_SGDMA
*/
port_input_fifo port1_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p1_wr_data),                  // input wire [63 : 0] din
  .wr_en(p1_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[0]),              // input wire rd_en
  .dout(port_dout[0]),                // output wire [127 : 0] dout
  .full(port_full[0]),                // output wire full
  .almost_full(port_almost_full[0]),  // output wire almost_full
  .empty(port_empty[0])              // output wire empty
);

port_input_fifo port2_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p2_wr_data),                  // input wire [63 : 0] din
  .wr_en(p2_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[1]),              // input wire rd_en
  .dout(port_dout[1]),                // output wire [127 : 0] dout
  .full(port_full[1]),                // output wire full
  .almost_full(port_almost_full[1]),  // output wire almost_full
  .empty(port_empty[1])              // output wire empty
);

port_input_fifo port3_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p3_wr_data),                  // input wire [63 : 0] din
  .wr_en(p3_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[2]),              // input wire rd_en
  .dout(port_dout[2]),                // output wire [127 : 0] dout
  .full(port_full[2]),                // output wire full
  .almost_full(port_almost_full[2]),  // output wire almost_full
  .empty(port_empty[2])             // output wire empty
);

port_input_fifo port4_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p4_wr_data),                  // input wire [63 : 0] din
  .wr_en(p4_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[3]),              // input wire rd_en
  .dout(port_dout[3]),                // output wire [127 : 0] dout
  .full(port_full[3]),                // output wire full
  .almost_full(port_almost_full[3]),  // output wire almost_full
  .empty(port_empty[3])             // output wire empty
);

port_input_fifo port5_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p5_wr_data),                  // input wire [63 : 0] din
  .wr_en(p5_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[4]),              // input wire rd_en
  .dout(port_dout[4]),                // output wire [127 : 0] dout
  .full(port_full[4]),                // output wire full
  .almost_full(port_almost_full[4]),  // output wire almost_full
  .empty(port_empty[4])              // output wire empty
);

port_input_fifo port6_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p6_wr_data),                  // input wire [63 : 0] din
  .wr_en(p6_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[5]),              // input wire rd_en
  .dout(port_dout[5]),                // output wire [127 : 0] dout
  .full(port_full[5]),                // output wire full
  .almost_full(port_almost_full[5]),  // output wire almost_full
  .empty(port_empty[5])              // output wire empty
);

port_input_fifo port7_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p7_wr_data),                  // input wire [63 : 0] din
  .wr_en(p7_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[6]),              // input wire rd_en
  .dout(port_dout[6]),                // output wire [127 : 0] dout
  .full(port_full[6]),                // output wire full
  .almost_full(port_almost_full[6]),  // output wire almost_full
  .empty(port_empty[6])              // output wire empty
);

port_input_fifo port8_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p8_wr_data),                  // input wire [63 : 0] din
  .wr_en(p8_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[7]),              // input wire rd_en
  .dout(port_dout[7]),                // output wire [127 : 0] dout
  .full(port_full[7]),                // output wire full
  .almost_full(port_almost_full[7]),  // output wire almost_full
  .empty(port_empty[7])              // output wire empty
);

port_input_fifo port9_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p9_wr_data),                  // input wire [63 : 0] din
  .wr_en(p9_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[8]),              // input wire rd_en
  .dout(port_dout[8]),                // output wire [127 : 0] dout
  .full(port_full[8]),                // output wire full
  .almost_full(port_almost_full[8]),  // output wire almost_full
  .empty(port_empty[8])              // output wire empty
);

port_input_fifo port10_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p10_wr_data),                  // input wire [63 : 0] din
  .wr_en(p10_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[9]),              // input wire rd_en
  .dout(port_dout[9]),                // output wire [127 : 0] dout
  .full(port_full[9]),                // output wire full
  .almost_full(port_almost_full[9]),  // output wire almost_full
  .empty(port_empty[9])             // output wire empty
);

port_input_fifo port11_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p11_wr_data),                  // input wire [63 : 0] din
  .wr_en(p11_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[10]),              // input wire rd_en
  .dout(port_dout[10]),                // output wire [127 : 0] dout
  .full(port_full[10]),                // output wire full
  .almost_full(port_almost_full[10]),  // output wire almost_full
  .empty(port_empty[10])              // output wire empty
);

port_input_fifo port12_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p12_wr_data),                  // input wire [63 : 0] din
  .wr_en(p12_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[11]),              // input wire rd_en
  .dout(port_dout[11]),                // output wire [127 : 0] dout
  .full(port_full[11]),                // output wire full
  .almost_full(port_almost_full[11]),  // output wire almost_full
  .empty(port_empty[11])              // output wire empty
);

port_input_fifo port13_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p13_wr_data),                  // input wire [63 : 0] din
  .wr_en(p13_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[12]),              // input wire rd_en
  .dout(port_dout[12]),                // output wire [127 : 0] dout
  .full(port_full[12]),                // output wire full
  .almost_full(port_almost_full[12]),  // output wire almost_full
  .empty(port_empty[12])              // output wire empty
);

port_input_fifo port14_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p14_wr_data),                  // input wire [63 : 0] din
  .wr_en(p14_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[13]),              // input wire rd_en
  .dout(port_dout[13]),                // output wire [127 : 0] dout
  .full(port_full[13]),                // output wire full
  .almost_full(port_almost_full[13]),  // output wire almost_full
  .empty(port_empty[13])              // output wire empty
);

port_input_fifo port15_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p15_wr_data),                  // input wire [63 : 0] din
  .wr_en(p15_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[14]),              // input wire rd_en
  .dout(port_dout[14]),                // output wire [127 : 0] dout
  .full(port_full[14]),                // output wire full
  .almost_full(port_almost_full[14]),  // output wire almost_full
  .empty(port_empty[14])              // output wire empty
);

port_input_fifo port16_input_inst (
  .rst(~rst_n),                  // input wire rst
  .wr_clk(clk),            // input wire wr_clk
  .rd_clk(clk_125MHz),            // input wire rd_clk
  .din(p16_wr_data),                  // input wire [63 : 0] din
  .wr_en(p16_wr_vld),              // input wire wr_en
  .rd_en(port_rd_en[15]),              // input wire rd_en
  .dout(port_dout[15]),                // output wire [127 : 0] dout
  .full(port_full[15]),                // output wire full
  .almost_full(port_almost_full[15]),  // output wire almost_full
  .empty(port_empty[15])              // output wire empty
);

    // Port_SGDMA Port_SGDMA_inst(
    //   .i_clk                         (clk_125MHz),
    //   .i_rst_n                       (rst_n),
    //   .o_rd_en                       (p1_rd_en),
    //   .i_dat                         (p1_dout),
    //   .i_empty                       (p1_empty),
    //   .i_sop                         (p1_wr_sop), //TODO:sop和eop�?要和fifo读出同步,和rd_en&
    //   .i_eop                         (p1_wr_eop),
    //   /*crossbar schedule interface*/ 
    //   .o_cb_din                      (sf1_din),
    //   .o_cb_wr_en                    (sf1_wr_en),
    //   .i_cb_full                     (sf1_full),
    //   /*mmu interface*/
    //   .o_mmu_wr_req                  (mmu_p1_wr_req),
    //   .o_mmu_wr_en                   (mmu_p1_wr_en),
    //   .o_mmu_wr_addr                 (mmu_p1_wr_addr),
    //   .o_mmu_wr_dat                  (mmu_p1_wr_dat),
    //   .i_mmu_wr_ready                (mmu_p1_wr_ready), 
    //   /*freelist interface*/
    //   .i_fp_wr_en                    (fp_p1_wr_en),
    //   .i_fp_wr_dat                   (fp_p1_wr_dat),
    //   .o_fp_list_full                (fp_p1_list_full),
    //   .locked                        (locked)
    // );
wire [`PORT_NUM-1:0] aply_req;
wire [6:0] length [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0] aply_valid;
wire [`PRAM_NUM_WIDTH-1:0] sram_sel [`PORT_NUM-1:0];
wire init_done;
wire [`PORT_NUM-1:0] malloc_done;

genvar j;
generate 
  for (j = 0; j < 16; j = j+1) begin : Port_SGDMA_modules
    Port_SGDMA #(.port(j)) Port_SGDMA_inst(
      .i_clk                         (clk_125MHz),
      .i_rst_n                       (rst_n),
      .o_rd_en                       (port_rd_en[j]),
      .i_dat                         (port_dout[j]),
      .i_empty                       (port_empty[j]),
      .i_sop                         (port_wr_sop[j]), //TODO:sop和eop�?要和fifo读出同步,和rd_en&
      .i_eop                         (port_wr_eop[j]),
      /*crossbar schedule interface*/ 
      .o_cb_din                      (sf_din[j]),
      .o_cb_wr_en                    (sf_wr_en[j]),
      .i_cb_full                     (sf_full[j]),
      /*mmu interface*/
      .o_mmu_wr_req                  (mmu_wr_req[j]),
      .o_sram_sel                    (sram_sel[j]),
      .o_mmu_wr_en                   (mmu_wr_en[j]),
      .o_mmu_wr_addr                 (mmu_wr_addr[j]),
      .o_mmu_wr_dat                  (mmu_wr_dat[j]),
      .o_mmu_wr_done                 (mmu_wr_done[j]),
      .i_mmu_wr_ready                (mmu_wr_ready[j]), 
      /*freelist interface*/
      .i_mmu_malloc_done             (malloc_done[j]),
      .i_fp_wr_en                    (fp_wr_en[j]),
      .i_fp_wr_dat                   (fp_wr_dat[j]),
      //.i_aply_valid                  (aply_valid[j]),
      .o_aply_req                    (aply_req[j]),
      .o_length                      (length[j]),
      //.o_fp_list_full                (fp_list_full[j]),
      .locked                        (locked)
    );
  end
endgenerate



// MMU_top MMU_top_inst(
//     .i_clk               (clk),
//     .i_clk_125MHz        (clk_125MHz),
//     .i_rst_n             (rst_n),

//     // .i_mem_req           (mmu_wr_req[0]),
//     // .i_mem_apply_num     (),

//     // .o_data_vld          (),
//     // .o_mem_vt_addr       (),
//     // .o_malloc_clk        (),

//     .i_wr_apply_sig      ({16{mmu_wr_req[0]}}),
//     .i_wr_vt_addr        ({16{mmu_wr_addr[0]}}),             
//     .i_wr_data           ({16{mmu_wr_dat[0]}}),                 
//     .i_wea               ({16{mmu_wr_en[0]}}),                     
//     .i_write_done        ({16{mmu_wr_done[0]}}) 
// );

wire [`PORT_NUM*`DATA_FRAME_NUM-1:0] mmu_rd_dat;

MMU_top MMU_top_inst(
    .i_clk                 (clk),
    .i_rst_n               (rst_n),
    .o_init_done           (init_done),
    .i_mem_req             (aply_req),

    .i_mem_apply_num       ({length[15], 
                             length[14], 
                             length[13], 
                             length[12], 
                             length[11], 
                             length[10], 
                             length[9], 
                             length[8], 
                             length[7], 
                             length[6], 
                             length[5], 
                             length[4], 
                             length[3], 
                             length[2], 
                             length[1], 
                             length[0]}),

    .o_data_vld            (fp_wr_en),

    .o_mem_vt_addr         ({fp_wr_dat[15], 
                             fp_wr_dat[14], 
                             fp_wr_dat[13], 
                             fp_wr_dat[12], 
                             fp_wr_dat[11], 
                             fp_wr_dat[10], 
                             fp_wr_dat[9], 
                             fp_wr_dat[8], 
                             fp_wr_dat[7], 
                             fp_wr_dat[6], 
                             fp_wr_dat[5], 
                             fp_wr_dat[4], 
                             fp_wr_dat[3], 
                             fp_wr_dat[2], 
                             fp_wr_dat[1], 
                             fp_wr_dat[0]}),

    //.o_malloc_clk          (), //？会不会有反相问题
    .o_malloc_done         (malloc_done),
    .i_wr_clk              ({16{clk_125MHz}}),  

    .i_wr_port_sel         ({sram_sel[15], 
                             sram_sel[14], 
                             sram_sel[13], 
                             sram_sel[12], 
                             sram_sel[11], 
                             sram_sel[10], 
                             sram_sel[9], 
                             sram_sel[8], 
                             sram_sel[7], 
                             sram_sel[6], 
                             sram_sel[5], 
                             sram_sel[4], 
                             sram_sel[3], 
                             sram_sel[2], 
                             sram_sel[1], 
                             sram_sel[0]}),

    .i_wr_apply_sig        (mmu_wr_req),

    .i_wr_vt_addr          ({mmu_wr_addr[15], 
                             mmu_wr_addr[14], 
                             mmu_wr_addr[13], 
                             mmu_wr_addr[12], 
                             mmu_wr_addr[11], 
                             mmu_wr_addr[10], 
                             mmu_wr_addr[9], 
                             mmu_wr_addr[8], 
                             mmu_wr_addr[7], 
                             mmu_wr_addr[6], 
                             mmu_wr_addr[5], 
                             mmu_wr_addr[4], 
                             mmu_wr_addr[3], 
                             mmu_wr_addr[2], 
                             mmu_wr_addr[1], 
                             mmu_wr_addr[0]}), 

    .i_wr_data             ({mmu_wr_dat[15], 
                             mmu_wr_dat[14], 
                             mmu_wr_dat[13], 
                             mmu_wr_dat[12], 
                             mmu_wr_dat[11], 
                             mmu_wr_dat[10], 
                             mmu_wr_dat[9], 
                             mmu_wr_dat[8], 
                             mmu_wr_dat[7], 
                             mmu_wr_dat[6], 
                             mmu_wr_dat[5], 
                             mmu_wr_dat[4], 
                             mmu_wr_dat[3], 
                             mmu_wr_dat[2], 
                             mmu_wr_dat[1], 
                             mmu_wr_dat[0]}),  

    .i_wea                 (mmu_wr_en),      

    .i_write_done          (mmu_wr_done), 

    .o_wr_ack              (mmu_wr_ready),

    .i_rd_port_sel         ({mmu_rd_aply_dat[15][22:18], 
                             mmu_rd_aply_dat[14][22:18], 
                             mmu_rd_aply_dat[13][22:18], 
                             mmu_rd_aply_dat[12][22:18], 
                             mmu_rd_aply_dat[11][22:18], 
                             mmu_rd_aply_dat[10][22:18], 
                             mmu_rd_aply_dat[9][22:18], 
                             mmu_rd_aply_dat[8][22:18], 
                             mmu_rd_aply_dat[7][22:18], 
                             mmu_rd_aply_dat[6][22:18], 
                             mmu_rd_aply_dat[5][22:18], 
                             mmu_rd_aply_dat[4][22:18], 
                             mmu_rd_aply_dat[3][22:18], 
                             mmu_rd_aply_dat[2][22:18], 
                             mmu_rd_aply_dat[1][22:18], 
                             mmu_rd_aply_dat[0][22:18]}),
                             
    .i_read_apply          (mmu_rd_req),
    .o_read_ack            (mmu_rd_ready),

    .i_pd                  ({mmu_rd_aply_dat[15], 
                             mmu_rd_aply_dat[14], 
                             mmu_rd_aply_dat[13], 
                             mmu_rd_aply_dat[12], 
                             mmu_rd_aply_dat[11], 
                             mmu_rd_aply_dat[10], 
                             mmu_rd_aply_dat[9], 
                             mmu_rd_aply_dat[8], 
                             mmu_rd_aply_dat[7], 
                             mmu_rd_aply_dat[6], 
                             mmu_rd_aply_dat[5], 
                             mmu_rd_aply_dat[4], 
                             mmu_rd_aply_dat[3], 
                             mmu_rd_aply_dat[2], 
                             mmu_rd_aply_dat[1], 
                             mmu_rd_aply_dat[0]}),

    .o_rd_done             (mmu_rd_done),

    .o_rd_data             (mmu_rd_dat),
    .o_read_clk            (mmu_rd_clk), //???
    .o_read_data_vld       (opt_fifo_wr_en)
);

assign {mmu_rd_dout[15], mmu_rd_dout[14], mmu_rd_dout[13], mmu_rd_dout[12], mmu_rd_dout[11], mmu_rd_dout[10], mmu_rd_dout[9], mmu_rd_dout[8], mmu_rd_dout[7], mmu_rd_dout[6], mmu_rd_dout[5], mmu_rd_dout[4], mmu_rd_dout[3], mmu_rd_dout[2], mmu_rd_dout[1], mmu_rd_dout[0]} = mmu_rd_dat;

// genvar i;
// generate
//   for (i = 0; i < 16; i = i+1) begin : ready_drive_test_1
//     ready_drive_test ready_drive_test_inst(
//       .i_clk                         (clk_125MHz),
//       .i_rst_n                       (rst_n),
//       .i_mmu_wr_req                  (mmu_wr_req[i]),
//       // .i_mmu_wr_addr                 (mmu_wr_addr[i]),
//       // .i_mmu_wr_dat                  (mmu_wr_dat[i]),
//       .o_mmu_wr_ready                (mmu_wr_ready[i])
//     );
//   end
// endgenerate

genvar k;
generate
  for (k = 0; k <= 3; k = k+1) begin : Fair_polling_scheduling
    Fair_polling_scheduling Fair_polling_scheduling_inst(
      .i_clk                         (clk_125MHz),
      .i_rst_n                       (rst_n),
      
      .i_schedule_fifo1_din          (sf_din[k*4]),
      .i_schedule_fifo1_wr_en        (sf_wr_en[k*4]),
      .o_schedule_fifo1_full         (sf_full[k*4]),

      .i_schedule_fifo2_din          (sf_din[k*4+1]),
      .i_schedule_fifo2_wr_en        (sf_wr_en[k*4+1]),
      .o_schedule_fifo2_full         (sf_full[k*4+1]),

      .i_schedule_fifo3_din          (sf_din[k*4+2]),
      .i_schedule_fifo3_wr_en        (sf_wr_en[k*4+2]),
      .o_schedule_fifo3_full         (sf_full[k*4+2]),

      .i_schedule_fifo4_din          (sf_din[k*4+3]),
      .i_schedule_fifo4_wr_en        (sf_wr_en[k*4+3]),
      .o_schedule_fifo4_full         (sf_full[k*4+3]), 
      
      .o_cb_wr_en                    (cb_wr_en[k]),
      .o_cb_din                      (cb_din[k]),
      .o_cb_sel                      (cb_sel[k])
    );
  end
endgenerate


Crossbar_switching_fabric Crossbar_switching_fabric_inst(
  .i_clk                           (clk_125MHz)                ,
  .i_rst_n                         (rst_n)                     ,
                     
  .i_cb_l1_din                     (cb_din[0])                 ,
  .i_cb_l1_sel                     (cb_sel[0])                 ,
  .i_cb_l1_wr_en                   (cb_wr_en[0])               ,
                
  .i_cb_l2_din                     (cb_din[1])                 ,
  .i_cb_l2_sel                     (cb_sel[1])                 ,
  .i_cb_l2_wr_en                   (cb_wr_en[1])               ,
                                 
  .i_cb_l3_din                     (cb_din[2])                 ,
  .i_cb_l3_sel                     (cb_sel[2])                 ,
  .i_cb_l3_wr_en                   (cb_wr_en[2])               ,
                                 
  .i_cb_l4_din                     (cb_din[3])                 ,
  .i_cb_l4_sel                     (cb_sel[3])                 ,
  .i_cb_l4_wr_en                   (cb_wr_en[3])               ,
               
  .o_cb_c1_queue_sel               (cb_col_queue_sel[0])       ,  //选择8个优先级队列
  .o_cb_c1_dout                    (cb_col_dout[0])            ,
  .o_cb_c1_dat_valid               (cb_col_dat_valid[0])       ,
               
  .o_cb_c2_queue_sel               (cb_col_queue_sel[1])       ,  //选择8个优先级队列
  .o_cb_c2_dout                    (cb_col_dout[1])            ,
  .o_cb_c2_dat_valid               (cb_col_dat_valid[1])       ,
               
  .o_cb_c3_queue_sel               (cb_col_queue_sel[2])       ,  //选择8个优先级队列
  .o_cb_c3_dout                    (cb_col_dout[2])            ,
  .o_cb_c3_dat_valid               (cb_col_dat_valid[2])       ,
               
  .o_cb_c4_queue_sel               (cb_col_queue_sel[3])       ,  //选择8个优先级队列
  .o_cb_c4_dout                    (cb_col_dout[3])            ,
  .o_cb_c4_dat_valid               (cb_col_dat_valid[3])
);


genvar m;
generate
  for (m = 0; m < 4; m = m + 1) begin : priority_schedule
    priority_schedule priority_schedule_inst(
      .i_clk                           (clk_125MHz)               ,
      .i_rst_n                         (rst_n)                    ,
    
      .i_queue_sel                     (cb_col_queue_sel[m])      ,
      .i_cb_col_dat                    (cb_col_dout[m])           ,
      .i_cb_col_dat_valid              (cb_col_dat_valid[m])      ,
      //out of queue cache interface
      .i_ooqc1_rd_en                   (ooqc_rd_en[4*m])          ,
      .o_ooqc1_rd_dat                  (ooqc_rd_dout[4*m])        , //32位完整调度数据
      .o_ooqc1_rd_empty                (ooqc_rd_empty[4*m])       ,

      .i_ooqc2_rd_en                   (ooqc_rd_en[4*m+1])        ,
      .o_ooqc2_rd_dat                  (ooqc_rd_dout[4*m+1])      , //32位完整调度数据
      .o_ooqc2_rd_empty                (ooqc_rd_empty[4*m+1])     ,

      .i_ooqc3_rd_en                   (ooqc_rd_en[4*m+2])        ,
      .o_ooqc3_rd_dat                  (ooqc_rd_dout[4*m+2])      , //32位完整调度数据
      .o_ooqc3_rd_empty                (ooqc_rd_empty[4*m+2])     ,

      .i_ooqc4_rd_en                   (ooqc_rd_en[4*m+3])        ,
      .o_ooqc4_rd_dat                  (ooqc_rd_dout[4*m+3])      , //32位完整调度数据
      .o_ooqc4_rd_empty                (ooqc_rd_empty[4*m+3])
    );
  end
endgenerate



// genvar l;
// generate
//   for (l = 0; l < `PORT_NUM; l = l+1) begin                 //16       7
//     assign mmu_rd_aply_dat[l] = ooqc_rd_dout[l][29:7]; //initial_addr length
//   end
// endgenerate
//需要循环例化16遍
/*                    状态机控制读取MMU包数据并写入fifo 
**  |----------------------------interface------------------------------| 
**  |  mmu_rd_req  |  mmu_rd_ready  |  mmu_rd_aply_dat  |  mmu_rd_done  |
**  |     读请求    |     读响应     |  包存储首地址和长度 | 整个包读取完成 |
*/
genvar n;
generate
  for (n = 0; n < `PORT_NUM; n = n + 1) begin
                                                            //16       7
    assign mmu_rd_aply_dat[n] = ooqc_rd_dout[n][29:7]; //initial_addr length

    always @(posedge clk_125MHz or negedge rst_n) begin
      if (rst_n == 1'b0) begin
        rd_mem_state[n] <= 'd0;
        ooqc_rd_en[n] <= 1'b0;
        mmu_rd_req[n] <= 1'b0;
      end  
      else begin
        rd_mem_state[n] <= rd_mem_state[n];
        ooqc_rd_en[n] <= 1'b0;
        mmu_rd_req[n] <= 1'b0;
        case (rd_mem_state[n])
          'd0: begin
            // rd_mem_state[n] <= (port_rd_ready[n] == 1'b1) ? 'd1 : 'd0;
            if (port_rd_ready[n] == 1'b1) begin //考虑x的情况
              rd_mem_state[n] <= 'd1;
            end
            else begin
              rd_mem_state[n] <= 'd0;
            end
            // ooqc_rd_en[n] <= port_rd_ready[n] ? 1'b1 : 1'b0;
          end //ooqc读使能 拉低读使能 
          'd1: begin
            if (ooqc_rd_empty[n]==1'b0) begin //考虑x的情况
              rd_mem_state[n] <= 'd2;
              ooqc_rd_en[n] <= 1'b1;
            end
            else begin
              rd_mem_state[n] <= 'd1;
              ooqc_rd_en[n] <= 1'b0;
            end
            // ooqc_rd_en[n] <= (ooqc_rd_empty[n]==1'b0) ? 1'b1 : 1'b0;
            // rd_mem_state[n] <= (ooqc_rd_empty[n]==1'b0) ? 'd2 : 'd1;
          end
          'd2: begin
            rd_mem_state[n] <= 'd3;
            mmu_rd_req[n] <= 1'b1;
          end
          'd3: begin
            rd_mem_state[n] <= 'd4;
          end
          'd4: begin //ooqc出数据  开始申请读mmu的包数据
            if (~mmu_rd_ready[n]) begin//未响应
              mmu_rd_req[n] <= 1'b1;
              rd_mem_state[n] <= 'd3; //一直申请
            end
            else begin //响应成功
              mmu_rd_req[n] <= 1'b0; //取消申请
              rd_mem_state[n] <= 'd5; //进入正式读取阶段
            end
          end
          'd5: begin //等待mmu全部读取完包数据并写入fifo中
            rd_mem_state[n] <= mmu_rd_done[n] ? 'd1 : 'd5;
          end
        endcase
      end
    end
  end
endgenerate

wire [`PORT_NUM-1:0] opt_rd_clk, opt_wr_clk;
reg clk_en;


/*      端口输出fifo 
**  Descrip: mmu输出包数据后缓存
**  write  : mmu
**  read   : port
*/
//暴露给mmu写入
genvar o;
//需要循环例化16遍
generate
  for (o = 0; o < `PORT_NUM; o = o + 1) begin

    assign opt_wr_clk[o] = locked ? mmu_rd_clk[o] : clk;
    port_output_fifo port_output_fifo_inst (
      .rst(~rst_n),                      // input wire rst
      .wr_clk(opt_wr_clk[o]),            // input wire wr_clk 125MHz
      .rd_clk(clk),                      // input wire rd_clk         250MHz
      .din(mmu_rd_dout[o]),              // input wire [127 : 0] din
      .wr_en(opt_fifo_wr_en[o]),         // input wire wr_en
      .rd_en(opt_fifo_rd_en[o]),         // input wire rd_en
      .dout(opt_fifo_rd_dout[o]),        // output wire [63 : 0] dout
      .empty(opt_fifo_empty[o])          // output wire empty
    );
  end
endgenerate

reg [2:0] opt_sig_state [`PORT_NUM-1:0];
reg [9:0] pkg_unit_cnt_reg [`PORT_NUM-1:0];
// reg [`PORT_NUM-1:0] opt_vld;

//主要用于SOP和EOP信号的生成以及fifo数据输出 64位读取的逻辑
genvar p;
generate
  for (p = 0; p < `PORT_NUM; p = p + 1) begin : output_signal_ctrl
    assign port_rd_vld[p] = opt_fifo_rd_en_r[p];
    always @(posedge clk or negedge rst_n) begin
      if (~rst_n) begin
        opt_fifo_rd_en[p] <= 1'b0;
        opt_fifo_rd_en_r[p] <= 1'b0;
        port_rd_sop[p] <= 1'b0;
        port_rd_eop[p] <= 1'b0;
        //port_rd_vld[p] <= 1'b0;
        opt_sig_state[p] <= 'd0;
        pkg_unit_cnt_reg[p] <= 'd0;
      end
      else begin
        opt_fifo_rd_en_r[p] <= opt_fifo_rd_en[p];
        if (opt_fifo_empty[p]) begin
          opt_fifo_rd_en[p] <= 1'b0;
          port_rd_sop[p] <= 1'b0;
          port_rd_eop[p] <= 1'b0;
          //port_rd_vld[p] <= 1'b0;
          opt_sig_state[p] <= opt_sig_state[p];
          pkg_unit_cnt_reg[p] <= pkg_unit_cnt_reg[p];
          opt_fifo_rd_en_r[p] <= 1'b0;
        end
        else begin
          port_rd_sop[p] <= 1'b0;
          port_rd_eop[p] <= 1'b0;
          //port_rd_vld[p] <= 1'b0;
          opt_sig_state[p] <= opt_sig_state[p];
          pkg_unit_cnt_reg[p] <= pkg_unit_cnt_reg[p];
          case (opt_sig_state[p])
            'd0: begin
              opt_fifo_rd_en[p] <= 1'b1; //读使能开启
              port_rd_sop[p] <= 1'b1;    //读sop信号开启
              opt_sig_state[p] <= 'd1;
            end 
            'd1: begin
              opt_sig_state[p] <= 'd2;
              port_rd_sop[p] <= 1'b0;    //读sop信号关闭
              opt_fifo_rd_en[p] <= 1'b1; //读使能开启
              //port_rd_vld[p] <= 1'b1;    //端口数据输出有效
            end
            'd2: begin                   //读取到包头高64位
              //pkg_unit_cnt_reg[p] <= ((opt_fifo_rd_dout[p][17:7] >> 'd4) + (|(opt_fifo_rd_dout[p][17:7] % 'd16))) << 2; //获取包信元数量
              opt_fifo_rd_en[p] <= 1'b1; //读使能开启
              //port_rd_vld[p] <= 1'b1;    //端口数据输出有效
              opt_sig_state[p] <= 'd3;
            end
            'd3: begin                   //读取到包头低64位
              pkg_unit_cnt_reg[p] <= (((opt_fifo_rd_dout[p][17:7] >> 'd4) + (|((opt_fifo_rd_dout[p][17:7]) % 'd16))) << 'd1) + 'd1; //获取包信元数量
              opt_fifo_rd_en[p] <= 1'b1; //读使能开启
              //port_rd_vld[p] <= 1'b1;    //端口数据输出有效
              opt_sig_state[p] <= 'd4;
            end
            'd4: begin
              if (pkg_unit_cnt_reg[p] > 'd2) begin
                pkg_unit_cnt_reg[p] <= pkg_unit_cnt_reg[p] - 'd1;
                opt_fifo_rd_en[p] <= 1'b1; //读使能开启
                //port_rd_vld[p] <= 1'b1;    //端口数据输出有效
                opt_sig_state[p] <= 'd4;
              end
              else begin
                pkg_unit_cnt_reg[p] <= pkg_unit_cnt_reg[p] - 'd1;
                opt_fifo_rd_en[p] <= 1'b0; //读使能开启
                //port_rd_vld[p] <= 1'b1;    //端口数据输出有效
                opt_sig_state[p] <= 'd5;
              end
            end
            'd5: begin //生成eop信号
              opt_fifo_rd_en[p] <= 1'b0; //读使能开启
              port_rd_eop[p] <= 1'b1;
              opt_sig_state[p] <= 'd0;
            end
          endcase
        end
      end
    end
  end
endgenerate




endmodule
