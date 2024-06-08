`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/30 20:48:01
// Design Name: 
// Module Name: interconnect_arbi2pram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: port_arbi模块分配至pram的交互模块
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module interconnect_arbi2pram( 
    // 分配片选信号
    input  [4:0] sel_mem_apply_port_num,                // 内存申请端口号选择 
    input  [4:0] sel_chip_apply_port_num,               // 芯片申请端口号选择
    
    // 待分配数据
    input  [6:0] mem_apply_num,                         // 内存申请数量
    input        mem_apply_req,

    input        chip_apply_req,

    // 内存分配信号分配后输出端口
    output reg [223:0] mem_apply_num_port,
    output reg [31:0]  mem_apply_sig,   

    // 芯片分配信号分配后输出端口
    output reg [31:0]  chip_apply_sig  
);

integer i;
always @(sel_chip_apply_port_num) begin 
    for (i=0; i<32; i=i+1) begin : chip_apply_sig_distribute
        if (i==sel_chip_apply_port_num)
            chip_apply_sig[i] = chip_apply_req;
        else
            chip_apply_sig[i] = 1'b0;
    end
end

integer j;
always @(sel_mem_apply_port_num) begin 
    for (j=0; j<32; j=j+1) begin : mem_apply_sig_distribute
        if (j==sel_mem_apply_port_num) begin 
            mem_apply_sig[j] = mem_apply_req;
            mem_apply_num_port[j*7+:7] = mem_apply_num;
        end
        else begin 
            mem_apply_sig[j] = 1'b0;
            mem_apply_num_port[j*7+:7] = 7'd0;
        end
    end
end

endmodule
