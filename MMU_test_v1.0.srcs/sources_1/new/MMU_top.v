`timescale 1ns / 1ps

`include "defines.v"


module MMU_top(
    input                                            i_clk,
    input                                            i_rst_n,

    input      [`PORT_NUM-1:0]                       i_mem_req,
    input      [`PORT_NUM*`DATA_FRAME_NUM_WIDTH-1:0] i_mem_apply_num,

    output reg [`PORT_NUM-1:0]                       o_data_vld,
    output reg [`PORT_NUM*`VT_ADDR_WIDTH-1:0]        o_mem_vt_addr,
    output reg [`PORT_NUM-1:0]                       o_malloc_clk,

    // write
    input      [`PORT_NUM-1:0]                       i_wr_apply_sig,
    input      [`VT_ADDR_WIDTH*`PORT_NUM-1:0]        i_wr_vt_addr,             
    input      [`DATA_FRAME_NUM*`PORT_NUM-1:0]       i_wr_data,                 
    input      [`PORT_NUM-1:0]                       i_wea,                     
    input      [`PORT_NUM-1:0]                       i_write_done 

    // read
    // input      [`PORT_NUM-1:0]                       i_read_apply,
    // input      [`PORT_NUM*32-1:0]                    i_pd,

    // output     [`PORT_NUM*`MEM_ADDR_WIDTH-1:0]       o_addr,
    // output     [`PORT_NUM-1:0]                       o_addr_vld,

    // output     [`DATA_FRAME_NUM-1:0]                 o_rd_data,
    // output     [`PORT_NUM-1:0]                       o_read_clk
);

/* port_arbi */ 
wire [`PRAM_NUM-1:0]                                 init_done_sig;
wire [`PRAM_NUM-1:0]                                 pram_state_sig;                                     // pram工作状态
wire [`PRAM_NUM-1:0]                                 pram_apply_mem_done_sig       [`PORT_NUM-1:0];      // pram分配结束标志位
wire [`PRAM_NUM-1:0]                                 pram_apply_mem_refuse_sig     [`PORT_NUM-1:0];      // 在mem_apply状态拒绝提供空闲地址
wire [`PRAM_NUM*`DATA_FRAME_NUM_WIDTH-1:0]           pram_free_space_sig;                                // pram剩余空间（低于64的部分）
wire [`PRAM_NUM-1:0]                                 bigger_than_64_sig;                                 // 32片pram剩余空间大于64的标志位

wire [`PRAM_NUM-1:0]                                 data_vld_sig                  [`PORT_NUM-1:0];      // 输出数据有效位（作为FIFO的使能信号）
wire [(`VT_ADDR_WIDTH*`PRAM_NUM)-1:0]                mem_vt_addr_sig               [`PORT_NUM-1:0];      // 分配内存的虚拟地址

//wire [`PRAM_NUM*`PRAM_NUM_WIDTH-1:0]                 pram_mem_apply_port_num_sig;  // 目标pram号，输出至接口模块进行分配
wire [`PRAM_NUM-1:0]                                 pram_mem_apply_req_sig        [`PORT_NUM-1:0];      // 数据请求信号
wire [`PRAM_NUM*`DATA_FRAME_NUM_WIDTH-1:0]           pram_mem_apply_num_sig        [`PORT_NUM-1:0];      // 缓存申请数量

wire [`PRAM_NUM-1:0]                                 pram_chip_apply_success_sig   [`PORT_NUM-1:0];      // pram片申请成功信号
wire [`PRAM_NUM-1:0]                                 pram_chip_apply_fail_sig      [`PORT_NUM-1:0];      // pram片申请失败信号

wire [`PRAM_NUM-1:0]                                 pram_chip_apply_req_sig       [`PORT_NUM-1:0];      // pram片申请信号
//wire [`PRAM_NUM*`PRAM_NUM_WIDTH-1:0]                 pram_chip_port_num_sig;      // 申请的pram号   

wire [`PRAM_NUM-1:0]                                 mem_malloc_clk_in_sig         [`PORT_NUM-1:0]; 

genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : port_arbi_inst
        port_arbi #(
            .PRIORITY_PRAM_NUM(i),
            .PORT_NUM(i)
        ) port_arbi_u(
            .i_clk(i_clk),
            .i_rst_n(i_rst_n),

            .i_init_done(init_done_sig),

            // pram交互信号
            .i_pram_state(pram_state_sig),                                           // pram工作状态
            .i_pram_apply_mem_done(pram_apply_mem_done_sig[i]),                                  // pram分配结束标志位
            .i_pram_apply_mem_refuse(pram_apply_mem_refuse_sig[i]),                                // 在mem_apply状态拒绝提供空闲地址
            .i_pram_free_space(pram_free_space_sig),                                      // pram剩余空间（低于64的部分）
            .i_bigger_than_64(bigger_than_64_sig),                                       // 32片pram剩余空间大于64的标志位
                            
            .i_data_vld(data_vld_sig[i]),                                             // 输出数据有效位（作为FIFO的使能信号）
            .i_mem_vt_addr(mem_vt_addr_sig[i]),                                          // 分配内存的虚拟地址
                            
            //.o_pram_mem_apply_port_num(pram_mem_apply_port_num_sig),                              // 目标pram号，输出至接口模块进行分配
            .o_pram_mem_apply_req(pram_mem_apply_req_sig[i]),                                   // 数据请求信号
            .o_pram_mem_apply_num(pram_mem_apply_num_sig[i]),                                   // 缓存申请数量
                            
            .i_pram_chip_apply_success(pram_chip_apply_success_sig[i]),                              // pram片申请成功信号
            .i_pram_chip_apply_fail(pram_chip_apply_fail_sig[i]),                                 // pram片申请失败信号
                            
            .o_pram_chip_apply_req(pram_chip_apply_req_sig[i]),                                  // pram片申请信号
            //.o_pram_chip_port_num(pram_chip_port_num_sig),                                   // 申请的pram号   
                            
            .i_mem_malloc_clk(mem_malloc_clk_in_sig[i]),                            
            .o_mem_malloc_clk(o_malloc_clk[i]),                               
                            
            // free list交互信号                            
            .i_mem_req(i_mem_req[i]),                                              // 端口发起内存申请
            .i_mem_apply_num(i_mem_apply_num[i*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH]),                                        // 申请内存数量
                            
            .o_data_vld(o_data_vld[i]),                                             // 输出数据有效位（作为FIFO的使能信号）
            .o_mem_vt_addr(o_mem_vt_addr[i*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH])                                           // 分配内存的虚拟地址
        );
    end
endgenerate

// genvar j;
// generate
//     for (j = 0; j < 32; j = j + 1) begin : pram_ctor_inst
//         pram_ctor #(
//             .PRAM_NUMBER(j)
//         ) pram_ctor_u(
//             .i_clk(i_clk),
//             .i_rst_n(i_rst_n),

//             // 芯片申请
//             .i_chip_apply_sig({pram_chip_apply_req_sig[0][j], 
//                                pram_chip_apply_req_sig[1][j], 
//                                pram_chip_apply_req_sig[2][j],
//                                pram_chip_apply_req_sig[3][j],
//                                pram_chip_apply_req_sig[4][j],
//                                pram_chip_apply_req_sig[5][j],
//                                pram_chip_apply_req_sig[6][j],
//                                pram_chip_apply_req_sig[7][j],
//                                pram_chip_apply_req_sig[8][j],
//                                pram_chip_apply_req_sig[9][j],
//                                pram_chip_apply_req_sig[10][j],
//                                pram_chip_apply_req_sig[11][j],
//                                pram_chip_apply_req_sig[12][j],
//                                pram_chip_apply_req_sig[13][j],
//                                pram_chip_apply_req_sig[14][j],
//                                pram_chip_apply_req_sig[15][j]}),             // 芯片申请信号

//             .o_chip_apply_refuse({pram_chip_apply_fail_sig[0][j], 
//                                   pram_chip_apply_fail_sig[1][j], 
//                                   pram_chip_apply_fail_sig[2][j],
//                                   pram_chip_apply_fail_sig[3][j],
//                                   pram_chip_apply_fail_sig[4][j],
//                                   pram_chip_apply_fail_sig[5][j],
//                                   pram_chip_apply_fail_sig[6][j],
//                                   pram_chip_apply_fail_sig[7][j],
//                                   pram_chip_apply_fail_sig[8][j],
//                                   pram_chip_apply_fail_sig[9][j],
//                                   pram_chip_apply_fail_sig[10][j],
//                                   pram_chip_apply_fail_sig[11][j],
//                                   pram_chip_apply_fail_sig[12][j],
//                                   pram_chip_apply_fail_sig[13][j],
//                                   pram_chip_apply_fail_sig[14][j],
//                                   pram_chip_apply_fail_sig[15][j]}),          // 芯片申请拒绝信号

//             .o_chip_apply_success({pram_chip_apply_success_sig[0][j], 
//                                    pram_chip_apply_success_sig[1][j], 
//                                    pram_chip_apply_success_sig[2][j],
//                                    pram_chip_apply_success_sig[3][j],
//                                    pram_chip_apply_success_sig[4][j],
//                                    pram_chip_apply_success_sig[5][j],
//                                    pram_chip_apply_success_sig[6][j],
//                                    pram_chip_apply_success_sig[7][j],
//                                    pram_chip_apply_success_sig[8][j],
//                                    pram_chip_apply_success_sig[9][j],
//                                    pram_chip_apply_success_sig[10][j],
//                                    pram_chip_apply_success_sig[11][j],
//                                    pram_chip_apply_success_sig[12][j],
//                                    pram_chip_apply_success_sig[13][j],
//                                    pram_chip_apply_success_sig[14][j],
//                                    pram_chip_apply_success_sig[15][j]}),         // 芯片申请同意信号

//             // 内存申请
//             .i_mem_apply_num({pram_mem_apply_num_sig[0][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH], 
//                               pram_mem_apply_num_sig[1][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH], 
//                               pram_mem_apply_num_sig[2][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[3][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[4][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[5][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[6][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[7][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[8][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[9][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[10][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[11][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[12][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[13][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[14][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH],
//                               pram_mem_apply_num_sig[15][j*`DATA_FRAME_NUM_WIDTH+:`DATA_FRAME_NUM_WIDTH]}),          // 内存申请数量

//             .i_mem_apply_sig({pram_mem_apply_req_sig[0][j], 
//                               pram_mem_apply_req_sig[1][j], 
//                               pram_mem_apply_req_sig[2][j],
//                               pram_mem_apply_req_sig[3][j],
//                               pram_mem_apply_req_sig[4][j],
//                               pram_mem_apply_req_sig[5][j],
//                               pram_mem_apply_req_sig[6][j],
//                               pram_mem_apply_req_sig[7][j],
//                               pram_mem_apply_req_sig[8][j],
//                               pram_mem_apply_req_sig[9][j],
//                               pram_mem_apply_req_sig[10][j],
//                               pram_mem_apply_req_sig[11][j],
//                               pram_mem_apply_req_sig[12][j],
//                               pram_mem_apply_req_sig[13][j],
//                               pram_mem_apply_req_sig[14][j],
//                               pram_mem_apply_req_sig[15][j]}),          // 内存申请信号

//             .o_mem_addr({mem_vt_addr_sig[0][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH], 
//                          mem_vt_addr_sig[1][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH], 
//                          mem_vt_addr_sig[2][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[3][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[4][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[5][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[6][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[7][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[8][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[9][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[10][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[11][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[12][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[13][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[14][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH],
//                          mem_vt_addr_sig[15][j*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH]}),               // 输出内存地址（pram号 + 物理地址）

//             .o_mem_addr_vld_sig({data_vld_sig[0][j], 
//                                  data_vld_sig[1][j], 
//                                  data_vld_sig[2][j],
//                                  data_vld_sig[3][j],
//                                  data_vld_sig[4][j],
//                                  data_vld_sig[5][j],
//                                  data_vld_sig[6][j],
//                                  data_vld_sig[7][j],
//                                  data_vld_sig[8][j],
//                                  data_vld_sig[9][j],
//                                  data_vld_sig[10][j],
//                                  data_vld_sig[11][j],
//                                  data_vld_sig[12][j],
//                                  data_vld_sig[13][j],
//                                  data_vld_sig[14][j],
//                                  data_vld_sig[15][j]}),       // 输出内存地址有效标志位

//             .o_mem_apply_done({pram_apply_mem_done_sig[0][j], 
//                                pram_apply_mem_done_sig[1][j], 
//                                pram_apply_mem_done_sig[2][j],
//                                pram_apply_mem_done_sig[3][j],
//                                pram_apply_mem_done_sig[4][j],
//                                pram_apply_mem_done_sig[5][j],
//                                pram_apply_mem_done_sig[6][j],
//                                pram_apply_mem_done_sig[7][j],
//                                pram_apply_mem_done_sig[8][j],
//                                pram_apply_mem_done_sig[9][j],
//                                pram_apply_mem_done_sig[10][j],
//                                pram_apply_mem_done_sig[11][j],
//                                pram_apply_mem_done_sig[12][j],
//                                pram_apply_mem_done_sig[13][j],
//                                pram_apply_mem_done_sig[14][j],
//                                pram_apply_mem_done_sig[15][j]}),         // 内存分配结束标志位

//             .o_mem_apply_refuse({pram_apply_mem_refuse_sig[0][j], 
//                                  pram_apply_mem_refuse_sig[1][j], 
//                                  pram_apply_mem_refuse_sig[2][j],
//                                  pram_apply_mem_refuse_sig[3][j],
//                                  pram_apply_mem_refuse_sig[4][j],
//                                  pram_apply_mem_refuse_sig[5][j],
//                                  pram_apply_mem_refuse_sig[6][j],
//                                  pram_apply_mem_refuse_sig[7][j],
//                                  pram_apply_mem_refuse_sig[8][j],
//                                  pram_apply_mem_refuse_sig[9][j],
//                                  pram_apply_mem_refuse_sig[10][j],
//                                  pram_apply_mem_refuse_sig[11][j],
//                                  pram_apply_mem_refuse_sig[12][j],
//                                  pram_apply_mem_refuse_sig[13][j],
//                                  pram_apply_mem_refuse_sig[14][j],
//                                  pram_apply_mem_refuse_sig[15][j]}),       // 申请拒绝标志位

//             .o_mem_clk({mem_malloc_clk_in_sig[0][j], 
//                         mem_malloc_clk_in_sig[1][j], 
//                         mem_malloc_clk_in_sig[2][j],
//                         mem_malloc_clk_in_sig[3][j],
//                         mem_malloc_clk_in_sig[4][j],
//                         mem_malloc_clk_in_sig[5][j],
//                         mem_malloc_clk_in_sig[6][j],
//                         mem_malloc_clk_in_sig[7][j],
//                         mem_malloc_clk_in_sig[8][j],
//                         mem_malloc_clk_in_sig[9][j],
//                         mem_malloc_clk_in_sig[10][j],
//                         mem_malloc_clk_in_sig[11][j],
//                         mem_malloc_clk_in_sig[12][j],
//                         mem_malloc_clk_in_sig[13][j],
//                         mem_malloc_clk_in_sig[14][j],
//                         mem_malloc_clk_in_sig[15][j]}),                // fifo时钟

//             .o_init_done(init_done_sig[j]),

//             // pram状态输出
//             .o_bigger_64(bigger_than_64_sig[j]),
//             .o_remaining_mem(pram_free_space_sig[j]),
//             .o_pram_state(pram_state_sig[j]),

//             /* -------------数据读取、内存回收端口----------- */
//             .i_read_apply_sig(),         // 读申请信号 
//             .i_pd(),                     // 数据包描述信息
//             .o_portb_addr(),
//             .o_portb_addr_vld(),
//             .o_aim_port_num(),           // 输出目的端口号

//             .o_read_clk()    
//         );
//     end
// endgenerate

// convert ------ sram_ctor
wire [`PRAM_NUM-1:0]                 wr_req_sig       [`PORT_NUM-1:0];
wire [`PRAM_NUM-1:0]                 wr_en_sig        [`PORT_NUM-1:0];
wire [`PRAM_NUM*`MEM_ADDR_WIDTH-1:0] wr_phy_addr_sig  [`PORT_NUM-1:0];
wire [`PRAM_NUM*`DATA_FRAME_NUM-1:0] wr_data_sig      [`PORT_NUM-1:0];
wire [`PRAM_NUM-1:0]                 wr_done_sig      [`PORT_NUM-1:0];

genvar m;
generate
    for (m = 0; m < 16; m = m + 1) begin : wr_convert_port2sram_inst
        wr_convert_port2sram wr_convert_port2sram_u(
            .i_wr_req(i_wr_apply_sig[m]),
            .i_wr_en(i_wea[m]),
            .i_wr_vt_addr(i_wr_vt_addr[m*`VT_ADDR_WIDTH+:`VT_ADDR_WIDTH]),
            .i_wr_data(i_wr_data[m*`DATA_FRAME_NUM+:`DATA_FRAME_NUM]),
            .i_wr_done(i_write_done[m]),

            .o_wr_req(wr_req_sig[m]),
            .o_wr_en(wr_en_sig[m]),
            .o_wr_phy_addr(wr_phy_addr_sig[m]),
            .o_wr_data(wr_data_sig[m]),
            .o_wr_done(wr_done_sig[m])
        );
    end
endgenerate

genvar k;
generate
    for (k = 0; k < 32; k=k+1) begin : sram_ctor_inst
        sram_ctor #(
            .RR_INIT_VAL(k)
        ) 
        sram_ctor_u(
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),

                .i_wr_apply_sig({wr_req_sig[0][k],
                                 wr_req_sig[1][k],
                                 wr_req_sig[2][k],
                                 wr_req_sig[3][k],
                                 wr_req_sig[4][k],
                                 wr_req_sig[5][k],
                                 wr_req_sig[6][k],
                                 wr_req_sig[7][k],
                                 wr_req_sig[8][k],
                                 wr_req_sig[9][k],
                                 wr_req_sig[10][k],
                                 wr_req_sig[11][k],
                                 wr_req_sig[12][k],
                                 wr_req_sig[13][k],
                                 wr_req_sig[14][k],
                                 wr_req_sig[15][k]}),             // 写入申请

                .i_wr_phy_addr({wr_phy_addr_sig[0][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[1][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[2][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[3][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[4][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[5][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[6][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[7][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[8][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[9][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[10][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[11][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[12][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[13][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[14][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH],
                                wr_phy_addr_sig[15][k*`MEM_ADDR_WIDTH+:`MEM_ADDR_WIDTH]}),              // 16组物理地址

                .i_wr_data({wr_data_sig[0][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[1][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[2][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[3][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[4][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[5][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[6][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[7][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[8][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[9][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[10][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[11][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[12][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[13][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[14][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM],
                            wr_data_sig[15][k*`DATA_FRAME_NUM+:`DATA_FRAME_NUM]}),                  // 16组写入数据

                .i_wea({wr_en_sig[0][k],
                        wr_en_sig[1][k],
                        wr_en_sig[2][k],
                        wr_en_sig[3][k],
                        wr_en_sig[4][k],
                        wr_en_sig[5][k],
                        wr_en_sig[6][k],
                        wr_en_sig[7][k],
                        wr_en_sig[8][k],
                        wr_en_sig[9][k],
                        wr_en_sig[10][k],
                        wr_en_sig[11][k],
                        wr_en_sig[12][k],
                        wr_en_sig[13][k],
                        wr_en_sig[14][k],
                        wr_en_sig[15][k]}),                      // 16组写使能信号

                .i_write_done({wr_done_sig[0][k],
                               wr_done_sig[1][k],
                               wr_done_sig[2][k],
                               wr_done_sig[3][k],
                               wr_done_sig[4][k],
                               wr_done_sig[5][k],
                               wr_done_sig[6][k],
                               wr_done_sig[7][k],
                               wr_done_sig[8][k],
                               wr_done_sig[9][k],
                               wr_done_sig[10][k],
                               wr_done_sig[11][k],
                               wr_done_sig[12][k],
                               wr_done_sig[13][k],
                               wr_done_sig[14][k],
                               wr_done_sig[15][k]}),               // 写入结束标志位

                .o_wr_apply_success(),
                .o_wr_apply_refuse(),

                .i_rd_clk(),
                .i_rd_phy_addr(),
                .o_rd_data()      
        );
    end
endgenerate

endmodule
