`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/13 15:13:31
// Design Name: 
// Module Name: sram_ctor_tb
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


module sram_ctor_tb();

reg         clk;
reg         rst_n;

reg  [15:0]          wr_apply_sig;
reg  [11 * 16 - 1:0] wr_phy_addr;
reg  [128 * 16 - 1:0] wr_data;
reg  [15:0]          wea;
reg  [15:0]          write_done;

reg  [10:0] rd_phy_addr;
wire [127:0] rd_data;

initial begin 
    clk = 0;
    rst_n = 0;
    #10
    rst_n = 1;
    # 20
    wr_apply_sig = 16'hff00;
    wr_phy_addr = 176'hffff_eeee_dddd_cccc_bbbb_aaaa_9999_8888_7777_6666_5555;
    wr_data = 2048'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_eeee_eeee_eeee_eeee_eeee_eeee_eeee_eeee_dddd_dddd_dddd_dddd_dddd_dddd_dddd_dddd_cccc_cccc_cccc_cccc_cccc_cccc_cccc_cccc_bbbb_bbbb_bbbb_bbbb_bbbb_bbbb_bbbb_bbbb_aaaa_aaaa_aaaa_aaaa_aaaa_aaaa_aaaa_aaaa_9999_9999_9999_9999_9999_9999_9999_9999_8888_8888_8888_8888_8888_8888_8888_8888_7777_7777_7777_7777_7777_7777_7777_7777_6666_6666_6666_6666_6666_6666_6666_6666_5555_5555_5555_5555_5555_5555_5555_5555_4444_4444_4444_4444_4444_4444_4444_4444_3333_3333_3333_3333_3333_3333_3333_3333_2222_2222_2222_2222_2222_2222_2222_2222_1111_1111_1111_1111_1111_1111_1111_1111_0001_0001_0001_0001_0001_0001_0001_0001;
    wea = 0;
end

always #5 clk = ~clk;

sram_ctor sram_ctor0(
    .i_clk(clk),
    .i_rst_n(rst_n),
    .i_wr_apply_sig(wr_apply_sig),
    .i_wr_phy_addr(wr_phy_addr),
    .i_wr_data(wr_data),
    .i_wea(wea),
    .i_write_done(write_done)
);

endmodule
