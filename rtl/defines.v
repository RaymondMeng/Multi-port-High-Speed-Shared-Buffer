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
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define DATA_WIDTH 64
`define DATA_DWIDTH 128
`define ADDR_WIDTH 16
`define DISPATCH_WIDTH 32
`define CROSSBAR_DIMENSION 4

/******************* v2 ************************/
`define PRAM_NUM 32                              // PRAM数量
`define PORT_NUM 16                              // 端口数量
`define PORT_NUM_WIDTH 4                         // 表示端口号的位数
`define PRAM_NUM_WIDTH 5                         // 表示PRAM号的位数
`define MEM_ADDR_WIDTH 11                        // 物理地址位宽
`define VT_ADDR_WIDTH 16                         // 虚拟地址位宽
`define DATA_DEEPTH 64                           // 数据包信源最大个数
`define DATA_DEEPTH_WIDTH 7                      // 数据深度位宽
`define DATA_FRAME_NUM_WIDTH 7                   // 单个数据包帧数量位宽
`define DATA_FRAME_NUM 128                       // 信源位宽
`define PRAM_DEPTH_WIDTH 12                      // PRAM最大深度表示位宽
`define PACKAGE_DESCRIPTION_WIDTH 32            


// `define PACKET_SWITCH`
// `define WRR_STRATEGY 
`define SP_STRATEGY   //严格优先级策略 
