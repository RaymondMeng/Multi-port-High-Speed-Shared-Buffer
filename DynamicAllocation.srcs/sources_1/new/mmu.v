`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/29 23:16:27
// Design Name: 
// Module Name: mmu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 顶层模块
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
`define PORT_NUM_WIDTH 4                         // 表示端口号的位数
`define PRAM_NUM_WIDTH 5                         // 表示PRAM号的位数
`define MEM_ADDR_WIDTH 11                        // 物理地址位宽
`define VT_ADDR_WIDTH 16                         // 虚拟地址位宽
`define DATA_DEEPTH_WIDTH 7                      // 数据深度位宽
`define DATA_FRAME_NUM_WIDTH 7                   // 单个数据包帧数量位宽
`define DATA_FRAME_NUM 128                       // 信源位宽
`define PRAM_DEPTH_WIDTH 12                      // PRAM最大深度表示位宽
*/

module mmu(
    input  i_clk_250,
    input  i_rst_n,

    /*********缓存申请*************/
    input  [`PORT_NUM-1:0]                       i_mem_apply_req,          // 缓存请求信号
    input  [`PORT_NUM*`DATA_FRAME_NUM_WIDTH-1:0] i_mem_apply_num,          // 缓存请求数量

    output [`PORT_NUM-1:0]                       o_mem_addr_vld,           // 缓存地址有效标志位
    output [`PORT_NUM-1:0]                       o_free_list_clk,          // 空闲缓存池fifo写时钟
    output [`PORT_NUM*`VT_ADDR_WIDTH-1:0]        o_mem_addr,               // 缓存地址

    output [`PORT_NUM-1:0]                       o_mem_apply_done,         // 缓存申请结束标志位
    output                                       o_init_done,              // pram初始化完成标志位

    /**********数据读取************/
    input  [`PORT_NUM-1:0]                                                          i_read_apply_req,    // 读取请求
    input  [(`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH)*`PORT_NUM-1:0]                   i_pd,                // 包描述文件

    output [`PORT_NUM-1:0]                       o_read_addr_vld,          // 读取数据有效标志位
    output [`PORT_NUM-1:0]                       o_fifo_out_clk,           // 出端fifo写时钟
    output [`DATA_FRAME_NUM*`PORT_NUM-1:0]       o_data,                   // 缓存地址

    /************数据存储**********/
    input  [`PORT_NUM-1:0]                                    i_wr_req,                 // 写入请求
    input  [`DATA_FRAME_NUM*`PORT_NUM-1:0]                    i_data,                   // 缓存数据
    input  [`MEM_ADDR_WIDTH*`PORT_NUM-1:0]                    i_vt_addr,                // 缓存地址
    input  [`PORT_NUM-1:0]                                    i_wea,                    // sram写使能

    input  [`PORT_NUM-1:0]                                    i_wr_done,                // 写入完成标志位

    output [`PORT_NUM-1:0]                                    o_wr_apply_refuse,        // 写请求拒绝标志位
    output [`PORT_NUM-1:0]                                    o_wr_apply_success        // 写请求接收标志位
);

/*port_arbi ------ pram_ctor*/
wire [`PRAM_NUM-1:0]                     pram_state;
wire [`PRAM_NUM-1:0]                     pram_apply_mem_done;
wire [`PORT_NUM-1:0]                     pram_apply_mem_done_arbi;
wire [`PORT_NUM-1:0]                     pram_apply_mem_done_2        [`PRAM_NUM-1:0];
wire [`PORT_NUM-1:0]                     pram_apply_mem_refuse        [`PRAM_NUM-1:0];
wire [`PORT_NUM-1:0]                     mem_apply_refuse_arbi;
    
wire [`DATA_DEEPTH_WIDTH*`PRAM_NUM-1:0]  pram_free_space;
wire [`PRAM_NUM-1:0]                     bigger_than_64;
    
wire [`PRAM_NUM-1:0]                     data_vld;
wire [`PORT_NUM-1:0]                     data_vld_arbi;
wire [`PORT_NUM-1:0]                     data_vld_2                   [`PRAM_NUM-1:0];
wire [`VT_ADDR_WIDTH-1:0]                mem_vt_addr                  [`PRAM_NUM-1:0];
wire [`VT_ADDR_WIDTH*`PORT_NUM-1:0]      mem_vt_addr_2                [`PRAM_NUM-1:0];
wire [`VT_ADDR_WIDTH-1:0]                mem_vt_addr_arbi             [`PORT_NUM-1:0];
    
wire [`PORT_NUM-1:0]                     pram_mem_apply_req;
wire [`PRAM_NUM_WIDTH-1:0]               pram_mem_apply_port_num      [`PORT_NUM-1:0];
wire [`DATA_DEEPTH_WIDTH-1:0]            pram_mem_apply_num           [`PORT_NUM-1:0];

wire [`PRAM_NUM-1:0]                     pram_chip_apply_success;
wire [`PRAM_NUM-1:0]                     pram_chip_apply_fail;

wire [`PORT_NUM-1:0]                     pram_chip_apply_reg;
wire [`PRAM_NUM_WIDTH-1:0]               pram_chip_apply_num          [`PORT_NUM-1:0];

wire [`PRAM_NUM-1:0]                     mem_apply_sig                [`PORT_NUM-1:0];
wire [`PRAM_NUM-1:0]                     chip_apply_sig               [`PORT_NUM-1:0];
wire [`DATA_DEEPTH_WIDTH*`PRAM_NUM-1:0]  mem_apply_num_port           [`PORT_NUM-1:0];
wire [`PORT_NUM-1:0]                     mem_malloc_port              [`PRAM_NUM-1:0];

wire [`PRAM_NUM-1:0]                     mem_clk_1;
wire [`PORT_NUM-1:0]                     mem_clk_arbi;
wire [`PORT_NUM-1:0]                     mem_clk_2                    [`PRAM_NUM-1:0];

wire [`PORT_NUM-1:0]                     chip_apply_refuse            [`PRAM_NUM-1:0];
wire [`PORT_NUM-1:0]                     chip_apply_succcess          [`PRAM_NUM-1:0];

wire [`PRAM_NUM-1:0]                     init_done;

wire [`PORT_NUM-1:0]                     read_apply_sig               [`PRAM_NUM-1:0];
wire [`VT_ADDR_WIDTH+`DATA_FRAME_NUM_WIDTH-1:0] pd                    [`PRAM_NUM-1:0];

wire [`MEM_ADDR_WIDTH-1:0]               read_addr                    [`PRAM_NUM-1:0]; 
wire [`PRAM_NUM-1:0]                     read_addr_vld;           
wire [`PRAM_NUM-1:0]                     read_clk;

wire [`PORT_NUM_WIDTH-1:0]               aim_port_num                 [`PRAM_NUM-1:0];

genvar i;
generate
    for (i = 0; i<16; i=i+1) begin : port_arbi_inst
        port_arbi #(
            .PRIORITY_PRAM_NUM(i),
            .PORT_NUM(i)
        )
        port_arbi_u (
            .i_clk(i_clk_250),
            .i_rst_n(i_rst_n),
            .i_pram_state(pram_state),               
            .i_pram_apply_mem_done(pram_apply_mem_done_arbi[i]),                                                                  // 32 -> 1
            .i_pram_apply_mem_refuse(mem_apply_refuse_arbi[i]),                                                                // 32 -> 1
            .i_pram_free_space(pram_free_space),                                               
            .i_bigger_than_64(bigger_than_64),                                               
                                     
            .i_data_vld(data_vld_arbi[i]),                                                                             // 32 -> 1  
            .i_mem_vt_addr(mem_vt_addr_arbi[n]),                                                                          // 32 -> 1
                                     
            .o_pram_mem_apply_port_num(pram_mem_apply_port_num[i]),                                       
            .o_pram_mem_apply_req(pram_mem_apply_req[i]),                                              // 1 -> 32
            .o_pram_mem_apply_num(pram_mem_apply_num[i]),                                              // 1 -> 32
                                     
            .i_pram_chip_apply_success(chip_apply_succcess[i]),                                                              // 32 -> 1
            .i_pram_chip_apply_fail(chip_apply_refuse[i]),                                                                 // 32 -> 1
   
            .o_pram_chip_apply_req(pram_chip_apply_reg[i]),                                            // 1 -> 32
            .o_pram_chip_port_num(pram_chip_apply_num[i]),                                             // 1 -> 32
   
            // free list交互信号   
            .i_mem_req(i_mem_apply_req[i]),                                                            // 端口发起内存申请
            .i_mem_apply_num(i_mem_apply_num[i*`DATA_DEEPTH_WIDTH+:`DATA_DEEPTH_WIDTH]),               // 申请内存数量
                                             
            .o_data_vld(o_mem_addr_vld[i]),                                                            // 输出数据有效位（作为FIFO的使能信号）
            .o_mem_vt_addr(o_mem_addr[i*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH]),

            .i_mem_malloc_clk(mem_clk_arbi[i]),
            .o_mem_malloc_clk(o_free_list_clk[i])                               
        );
    end
endgenerate

genvar j;
generate
    for (j = 0; j < 16; j = j + 1) begin : interconnect_arbi2pram_inst
        interconnect_arbi2pram interconnect_arbi2pram_u (                   
            .sel_mem_apply_port_num(pram_mem_apply_port_num[j]),                
            .sel_chip_apply_port_num(pram_chip_apply_num[j]),  

            .mem_apply_num(pram_mem_apply_num[j]), 
            .mem_apply_req(pram_mem_apply_req[j]),
            .chip_apply_req(pram_chip_apply_reg[j]),

            .mem_apply_num_port(mem_apply_num_port[j]),
            .mem_apply_sig(mem_apply_sig[j]),        
            .chip_apply_sig(chip_apply_sig[j])  
        );
    end
endgenerate

assign o_read_addr_vld = read_addr_vld;

genvar k;
generate
    for (k = 0; k < 32; k = k + 1) begin : pram_ctor_inst
        pram_ctor #(
            .PRAM_NUMBER(k)
        )
        pram_ctor_u(
            .i_clk_250(i_clk_250),
            .i_rst_n(i_rst_n),

            .o_pram_state(pram_state[k]),
            .i_chip_apply_sig({chip_apply_sig[15][k], chip_apply_sig[14][k], chip_apply_sig[13][k], chip_apply_sig[12][k], chip_apply_sig[11][k], chip_apply_sig[10][k], chip_apply_sig[9][k], chip_apply_sig[8][k], chip_apply_sig[7][k], chip_apply_sig[6][k], chip_apply_sig[5][k], chip_apply_sig[4][k], chip_apply_sig[3][k], chip_apply_sig[2][k], chip_apply_sig[1][k], chip_apply_sig[0][k]}),          

            .o_chip_apply_refuse(chip_apply_refuse[k]),        
            .o_chip_apply_success(chip_apply_succcess[k]),         

            .i_mem_apply_num({mem_apply_num_port[15][k*7+:7], mem_apply_num_port[14][k*7+:7], mem_apply_num_port[13][k*7+:7], mem_apply_num_port[12][k*7+:7], mem_apply_num_port[11][k*7+:7], mem_apply_num_port[10][k*7+:7], mem_apply_num_port[9][k*7+:7], mem_apply_num_port[8][k*7+:7], mem_apply_num_port[7][k*7+:7], mem_apply_num_port[6][k*7+:7], mem_apply_num_port[5][k*7+:7], mem_apply_num_port[4][k*7+:7], mem_apply_num_port[3][k*7+:7], mem_apply_num_port[2][k*7+:7], mem_apply_num_port[1][k*7+:7], mem_apply_num_port[0][k*7+:7]}),          
            .i_mem_apply_sig({mem_apply_sig[15][k], mem_apply_sig[14][k], mem_apply_sig[13][k], mem_apply_sig[12][k], mem_apply_sig[11][k], mem_apply_sig[10][k], mem_apply_sig[9][k], mem_apply_sig[8][k], mem_apply_sig[7][k], mem_apply_sig[6][k], mem_apply_sig[5][k], mem_apply_sig[4][k], mem_apply_sig[3][k], mem_apply_sig[2][k], mem_apply_sig[1][k], mem_apply_sig[0][k]}),          
            .o_mem_addr(mem_vt_addr[k]),               
            .o_mem_addr_vld_sig(data_vld[k]),       
            .o_mem_apply_done(pram_apply_mem_done[k]),        
            .o_mem_apply_refuse(pram_apply_mem_refuse[k]),   
            .o_mem_clk(mem_clk_1[k]), 
            .o_mem_malloc_port(mem_malloc_port[k]),   
            
            .o_init_done(init_done[k]),

            .o_bigger_64(bigger_than_64[k]),
            .o_remaining_mem(pram_free_space[7*k+:7]),

            .i_read_apply_sig(read_apply_sig[k]),         
            .i_pd(pd[k]),                     
            .o_portb_addr(read_addr[k]),             
            .o_portb_addr_vld(read_addr_vld[k]),

            .o_aim_port_num(aim_port_num[k]),
            
            .o_read_clk(read_clk[k]) 
        );
    end
endgenerate

assign o_fifo_out_clk = read_clk[k];

genvar m;
generate
    for (m=0; m<32; m=m+1) begin : pram2arbi_inst
        interconnect_pram2arbi(
            .mem_malloc_port(mem_malloc_port[m]),
            .mem_vt_addr(mem_vt_addr[m]),
            .mem_vt_addr_port(mem_vt_addr_2[m]),
            .mem_addr_vld(data_vld[m]),
            .data_vld(data_vld_2[m]),
            .mem_malloc_done(pram_apply_mem_done[m]),
            .mem_apply_done(pram_apply_mem_done_2[m]),
            .data_vld_clk(mem_clk_1[m]),
            .mem_malloc_clk(mem_clk_2[m])   
        );
    end
endgenerate

genvar n;
generate
    for (n=0; n<16; n=m+1) begin : pram2arbi_16_inst
        interconnect_pram2arbi(
            .mem_apply_port(pram_mem_apply_port_num[n]),
            .mem_vt_addr(mem_vt_addr_arbi[n]),
            .mem_vt_addr_port({mem_vt_addr_2[31][16*n+:16], mem_vt_addr_2[30][16*n+:16], mem_vt_addr_2[29][16*n+:16], mem_vt_addr_2[28][16*n+:16], mem_vt_addr_2[27][16*n+:16], mem_vt_addr_2[26][16*n+:16], mem_vt_addr_2[25][16*n+:16], mem_vt_addr_2[24][16*n+:16], mem_vt_addr_2[23][16*n+:16], mem_vt_addr_2[22][16*n+:16], mem_vt_addr_2[21][16*n+:16], mem_vt_addr_2[20][16*n+:16], mem_vt_addr_2[19][16*n+:16], mem_vt_addr_2[18][16*n+:16], mem_vt_addr_2[17][16*n+:16], mem_vt_addr_2[16][16*n+:16], mem_vt_addr_2[15][16*n+:16], mem_vt_addr_2[14][16*n+:16], mem_vt_addr_2[13][16*n+:16], mem_vt_addr_2[12][16*n+:16], mem_vt_addr_2[11][16*n+:16], mem_vt_addr_2[10][16*n+:16], mem_vt_addr_2[9][16*n+:16], mem_vt_addr_2[8][16*n+:16], mem_vt_addr_2[7][16*n+:16], mem_vt_addr_2[6][16*n+:16], mem_vt_addr_2[5][16*n+:16], mem_vt_addr_2[4][16*n+:16], mem_vt_addr_2[3][16*n+:16], mem_vt_addr_2[2][16*n+:16], mem_vt_addr_2[1][16*n+:16], mem_vt_addr_2[0][16*n+:16]}),
            .mem_addr_vld(data_vld_arbi[n]),
            .data_vld({data_vld_2[31][n], data_vld_2[30][n], data_vld_2[29][n], data_vld_2[28][n], data_vld_2[27][n], data_vld_2[26][n], data_vld_2[25][n], data_vld_2[24][n], data_vld_2[23][n], data_vld_2[22][n], data_vld_2[21][n], data_vld_2[20][n], data_vld_2[19][n], data_vld_2[18][n], data_vld_2[17][n], data_vld_2[16][n], data_vld_2[15][n], data_vld_2[14][n], data_vld_2[13][n], data_vld_2[12][n], data_vld_2[11][n], data_vld_2[10][n], data_vld_2[9][n], data_vld_2[8][n], data_vld_2[7][n], data_vld_2[6][n], data_vld_2[5][n], data_vld_2[4][n], data_vld_2[3][n], data_vld_2[2][n], data_vld_2[1][n], data_vld_2[0][n]}),
            .mem_malloc_done({pram_apply_mem_done_2[31][n], pram_apply_mem_done_2[30][n], pram_apply_mem_done_2[29][n], pram_apply_mem_done_2[28][n], pram_apply_mem_done_2[27][n], pram_apply_mem_done_2[26][n], pram_apply_mem_done_2[25][n], pram_apply_mem_done_2[24][n], pram_apply_mem_done_2[23][n], pram_apply_mem_done_2[22][n], pram_apply_mem_done_2[21][n], pram_apply_mem_done_2[20][n], pram_apply_mem_done_2[19][n], pram_apply_mem_done_2[18][n], pram_apply_mem_done_2[17][n], pram_apply_mem_done_2[16][n], pram_apply_mem_done_2[15][n], pram_apply_mem_done_2[14][n], pram_apply_mem_done_2[13][n], pram_apply_mem_done_2[12][n], pram_apply_mem_done_2[11][n], pram_apply_mem_done_2[10][n], pram_apply_mem_done_2[9][n], pram_apply_mem_done_2[8][n], pram_apply_mem_done_2[7][n], pram_apply_mem_done_2[6][n], pram_apply_mem_done_2[5][n], pram_apply_mem_done_2[4][n], pram_apply_mem_done_2[3][n], pram_apply_mem_done_2[2][n], pram_apply_mem_done_2[1][n], pram_apply_mem_done_2[0][n]}),
            .mem_apply_done(pram_apply_mem_done_arbi[n]),
            .data_vld_clk(mem_clk_arbi[n]),
            .mem_malloc_clk({mem_clk_2[31][n], mem_clk_2[30][n], mem_clk_2[29][n], mem_clk_2[28][n], mem_clk_2[27][n], mem_clk_2[26][n], mem_clk_2[25][n], mem_clk_2[24][n], mem_clk_2[23][n], mem_clk_2[22][n], mem_clk_2[1][n], mem_clk_2[21][n], mem_clk_2[20][n], mem_clk_2[19][n], mem_clk_2[18][n], mem_clk_2[17][n], mem_clk_2[16][n], mem_clk_2[15][n], mem_clk_2[14][n], mem_clk_2[13][n], mem_clk_2[12][n], mem_clk_2[11][n], mem_clk_2[10][n], mem_clk_2[9][n], mem_clk_2[8][n], mem_clk_2[7][n], mem_clk_2[6][n], mem_clk_2[5][n], mem_clk_2[4][n], mem_clk_2[3][n], mem_clk_2[2][n], mem_clk_2[1][n], mem_clk_2[0][n]}),   
            .mem_refuse({pram_apply_mem_refuse[31][n], pram_apply_mem_refuse[30][n], pram_apply_mem_refuse[29][n], pram_apply_mem_refuse[28][n], pram_apply_mem_refuse[27][n], pram_apply_mem_refuse[26][n], pram_apply_mem_refuse[25][n], pram_apply_mem_refuse[24][n], pram_apply_mem_refuse[23][n], pram_apply_mem_refuse[22][n], pram_apply_mem_refuse[1][n], pram_apply_mem_refuse[21][n], pram_apply_mem_refuse[20][n], pram_apply_mem_refuse[19][n], pram_apply_mem_refuse[18][n], pram_apply_mem_refuse[17][n], pram_apply_mem_refuse[16][n], pram_apply_mem_refuse[15][n], pram_apply_mem_refuse[14][n], pram_apply_mem_refuse[13][n], pram_apply_mem_refuse[12][n], pram_apply_mem_refuse[11][n], pram_apply_mem_refuse[10][n], pram_apply_mem_refuse[9][n], pram_apply_mem_refuse[8][n], pram_apply_mem_refuse[7][n], pram_apply_mem_refuse[6][n], pram_apply_mem_refuse[5][n], pram_apply_mem_refuse[4][n], pram_apply_mem_refuse[3][n], pram_apply_mem_refuse[2][n], pram_apply_mem_refuse[1][n], pram_apply_mem_refuse[0][n]}),
            .mem_apply_refuse(mem_apply_refuse_arbi[n])
        );
    end
endgenerate

genvar a;
generate
    for (a=0; a<32; a=a+1) begin 
        sram_ctor #(
            .RR_INIT_VAL(i)
        )
        sram_u (
            .i_clk(i_clk_250),
            .i_rst_n(i_rst_n),
            .i_wr_apply_sig(i_wr_req),          
            .i_wr_phy_addr(i_vt_addr),          
            .i_wr_data(i_data),                 
            .i_wea(i_wea),                    
            .i_write_done(i_wr_done),               
            .o_wr_apply_success(o_wr_apply_success),
            .o_wr_apply_refuse(o_wr_apply_refuse),
            .i_rd_phy_addr(read_addr[a]),
            .o_rd_data(o_data)      
        );
    end
endgenerate

genvar c;
generate
    for (c=0; c<32; c=c+1) begin 
        assign read_apply_sig[c] = i_read_apply_req;
    end
endgenerate

endmodule
