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
    // 模块使能信号
    input        sel_mem_apply_port_en,                 // 内存申请分配使能
    input        sel_chip_apply_port_en,                // 芯片申请分配使能

    // 分配片选信号
    input  [4:0] sel_mem_apply_port_num,                // 内存申请端口号选择 
    input  [4:0] sel_chip_apply_port_num,               // 芯片申请端口号选择
    
    // 待分配数据
    input  [7:0] mem_apply_num,                         // 内存申请数量

    // 内存分配信号分配后输出端口
    output reg [255:0] mem_apply_num_port,
    output reg [31:0]  mem_apply_num_vld_port,   

    // 芯片分配信号分配后输出端口
    output reg [31:0]  chip_apply_sig_port  
);

// 芯片申请信号分配
always @(sel_chip_apply_port_en or sel_chip_apply_port_num) begin 
    if (~sel_chip_apply_port_en) begin 
        chip_apply_sig_port = 32'd0;
    end
    else begin 
        chip_apply_sig_port = 32'd0;
        case(sel_chip_apply_port_num) 
            32'd0: chip_apply_sig_port[0] = 1'b1;
            32'd1: chip_apply_sig_port[1] = 1'b1;
            32'd2: chip_apply_sig_port[2] = 1'b1;
            32'd3: chip_apply_sig_port[3] = 1'b1;
            32'd4: chip_apply_sig_port[4] = 1'b1;
            32'd5: chip_apply_sig_port[5] = 1'b1;
            32'd6: chip_apply_sig_port[6] = 1'b1;
            32'd7: chip_apply_sig_port[7] = 1'b1;
            32'd8: chip_apply_sig_port[8] = 1'b1;
            32'd9: chip_apply_sig_port[9] = 1'b1;
            32'd10: chip_apply_sig_port[10] = 1'b1;
            32'd11: chip_apply_sig_port[11] = 1'b1;
            32'd12: chip_apply_sig_port[12] = 1'b1;
            32'd13: chip_apply_sig_port[13] = 1'b1;
            32'd14: chip_apply_sig_port[14] = 1'b1;
            32'd15: chip_apply_sig_port[15] = 1'b1;
            32'd16: chip_apply_sig_port[16] = 1'b1;
            32'd17: chip_apply_sig_port[17] = 1'b1;
            32'd18: chip_apply_sig_port[18] = 1'b1;
            32'd19: chip_apply_sig_port[19] = 1'b1;
            32'd20: chip_apply_sig_port[20] = 1'b1;
            32'd21: chip_apply_sig_port[21] = 1'b1;
            32'd22: chip_apply_sig_port[22] = 1'b1;
            32'd23: chip_apply_sig_port[23] = 1'b1;
            32'd24: chip_apply_sig_port[24] = 1'b1;
            32'd25: chip_apply_sig_port[25] = 1'b1;
            32'd26: chip_apply_sig_port[26] = 1'b1;
            32'd27: chip_apply_sig_port[27] = 1'b1;
            32'd28: chip_apply_sig_port[28] = 1'b1;
            32'd29: chip_apply_sig_port[29] = 1'b1;
            32'd30: chip_apply_sig_port[30] = 1'b1;
            32'd31: chip_apply_sig_port[31] = 1'b1;
        default:
            chip_apply_sig_port = 32'd0;
        endcase
    end
end

// 内存申请信号分配
always @(sel_mem_apply_port_en or sel_mem_apply_port_num) begin 
    if (~sel_mem_apply_port_en) begin 
        mem_apply_num_port = 256'd0;
        mem_apply_num_vld_port = 32'd0;
    end
    else begin 
        mem_apply_num_vld_port = 32'd0;
        mem_apply_num_port = 256'd0;
        case(sel_mem_apply_port_num) 
            32'd0: begin
                mem_apply_num_vld_port[0] = 1'b1;
                mem_apply_num_port[7:0] = mem_apply_num;
            end
            32'd1: begin 
                mem_apply_num_vld_port[1] = 1'b1;
                mem_apply_num_port[15:8] = mem_apply_num;
            end
            32'd2: begin 
                mem_apply_num_vld_port[2] = 1'b1;
                mem_apply_num_port[23:16] = mem_apply_num;
            end
            32'd3: begin
                mem_apply_num_vld_port[3] = 1'b1;
                mem_apply_num_port[31:24] = mem_apply_num;
            end
            32'd4: begin
                mem_apply_num_vld_port[4] = 1'b1;
                mem_apply_num_port[39:32] = mem_apply_num;
            end
            32'd5: begin
                mem_apply_num_vld_port[5] = 1'b1;
                mem_apply_num_port[47:40] = mem_apply_num;
            end
            32'd6: begin
                mem_apply_num_vld_port[6] = 1'b1;
                mem_apply_num_port[55:48] = mem_apply_num;
            end
            32'd7: begin
                mem_apply_num_vld_port[7] = 1'b1;
                mem_apply_num_port[63:56] = mem_apply_num;
            end
            32'd8: begin
                mem_apply_num_vld_port[8] = 1'b1;
                mem_apply_num_port[71:64] = mem_apply_num;
            end
            32'd9: begin
                mem_apply_num_vld_port[9] = 1'b1;
                mem_apply_num_port[79:72] = mem_apply_num;
            end
            32'd10: begin
                mem_apply_num_vld_port[10] = 1'b1;
                mem_apply_num_port[87:80] = mem_apply_num;
            end
            32'd11: begin
                mem_apply_num_vld_port[11] = 1'b1;
                mem_apply_num_port[95:88] = mem_apply_num;
            end
            32'd12: begin
                mem_apply_num_vld_port[12] = 1'b1;
                mem_apply_num_port[103:96] = mem_apply_num;
            end
            32'd13: begin
                mem_apply_num_vld_port[13] = 1'b1;
                mem_apply_num_port[111:104] = mem_apply_num;
            end
            32'd14: begin
                mem_apply_num_vld_port[14] = 1'b1;
                mem_apply_num_port[119:112] = mem_apply_num;
            end
            32'd15: begin
                mem_apply_num_vld_port[15] = 1'b1;
                mem_apply_num_port[127:120] = mem_apply_num;
            end
            32'd16: begin
                mem_apply_num_vld_port[16] = 1'b1;
                mem_apply_num_port[135:128] = mem_apply_num;
            end
            32'd17: begin
                mem_apply_num_vld_port[17] = 1'b1;
                mem_apply_num_port[143:136] = mem_apply_num;
            end
            32'd18: begin
                mem_apply_num_vld_port[18] = 1'b1;
                mem_apply_num_port[151:144] = mem_apply_num;
            end
            32'd19: begin
                mem_apply_num_vld_port[19] = 1'b1;
                mem_apply_num_port[159:152] = mem_apply_num;
            end
            32'd20: begin
                mem_apply_num_vld_port[20] = 1'b1;
                mem_apply_num_port[167:160] = mem_apply_num;
            end
            32'd21: begin
                mem_apply_num_vld_port[21] = 1'b1;
                mem_apply_num_port[175:168] = mem_apply_num;
            end
            32'd22: begin
                mem_apply_num_vld_port[22] = 1'b1;
                mem_apply_num_port[183:176] = mem_apply_num;
            end
            32'd23: begin
                mem_apply_num_vld_port[23] = 1'b1;
                mem_apply_num_port[191:184] = mem_apply_num;
            end
            32'd24: begin
                mem_apply_num_vld_port[24] = 1'b1;
                mem_apply_num_port[199:192] = mem_apply_num;
            end
            32'd25: begin
                mem_apply_num_vld_port[25] = 1'b1;
                mem_apply_num_port[207:200] = mem_apply_num;
            end
            32'd26: begin
                mem_apply_num_vld_port[26] = 1'b1;
                mem_apply_num_port[215:208] = mem_apply_num;
            end
            32'd27: begin
                mem_apply_num_vld_port[27] = 1'b1;
                mem_apply_num_port[223:216] = mem_apply_num;
            end
            32'd28: begin
                mem_apply_num_vld_port[28] = 1'b1;
                mem_apply_num_port[231:224] = mem_apply_num;
            end
            32'd29: begin
                mem_apply_num_vld_port[29] = 1'b1;
                mem_apply_num_port[239:232] = mem_apply_num;
            end
            32'd30: begin
                mem_apply_num_vld_port[30] = 1'b1;
                mem_apply_num_port[247:240] = mem_apply_num;
            end
            32'd31: begin
                mem_apply_num_vld_port[31] = 1'b1;
                mem_apply_num_port[255:248] = mem_apply_num;
            end
        default: begin
            mem_apply_num_vld_port = 32'd0;
            mem_apply_num_port = 256'd0;
        end
        endcase
    end
end


endmodule
