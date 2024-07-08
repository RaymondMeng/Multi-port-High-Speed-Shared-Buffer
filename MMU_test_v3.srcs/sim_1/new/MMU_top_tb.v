`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2024 09:25:07 AM
// Design Name: 
// Module Name: MMU_top_tb
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

module MMU_top_tb();

reg [79:0]    sel;
reg clk;
reg rst_n;

reg [15:0]   mem_req;
reg [111:0]  mem_apply_num;

reg [15:0]   wr_apply_sig;
reg [255:0]  wr_vt_addr;
reg [2047:0] wr_data;
reg [15:0]   wea;
reg [15:0]   write_done;

reg [15:0]   wr_clk;

reg [15:0]  rd_req;
reg [511:0] rd_pd;

initial begin 
    clk = 0;
    rst_n = 0;
    write_done = 'h0000;
    sel = 'd0;
    wr_clk = 'd0;

    #10
    rst_n = 1;

    #10
    mem_req = 'hff11;
    mem_apply_num = 'haaaa_aaaa_aaaa_aaaa_aaaa_aaaa_aaaa;

    wr_apply_sig = 'h0001;
    wr_vt_addr = 'd0;
    wr_data = {16{128'd34762}};
    wea = 'h0001;

    #20
    wr_vt_addr = 'd1;
    wr_data = {16{128'd34763}};

    #20
    wr_data = {16{128'd34787}};

    #50
    write_done = 'h0001;

    rd_req = 'h0001;
    rd_pd = {480'd0, 9'd0, 16'd0, 7'd33};
    
end

always #5 clk = ~clk;
always #10 wr_clk[0] = ~wr_clk[0];

MMU_top MMU_top_u(
    .i_clk(clk),
    .i_rst_n(rst_n),

    .i_mem_req(mem_req),
    .i_mem_apply_num(mem_apply_num),

    // write
    .i_wr_clk(wr_clk),
    .i_wr_port_sel(sel),
    .i_wr_apply_sig(wr_apply_sig),
    .i_wr_vt_addr(wr_vt_addr),             
    .i_wr_data(wr_data),                 
    .i_wea(wea),                     
    .i_write_done(write_done),

    // read 
    .i_rd_port_sel(sel),
    .i_read_apply(rd_req),
    .i_pd(rd_pd)
);


endmodule
