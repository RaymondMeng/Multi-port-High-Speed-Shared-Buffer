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

reg [79:0]   wr_sel;
reg [79:0]   rd_sel;
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
    wr_sel = 80'd0;
    rd_sel = 80'd0;
    wr_clk = 'd0;

    #10
    rst_n = 1;
    wr_sel = {5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0};
    rd_sel = {5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0};

    #10
    mem_req = 'hff11;
    mem_apply_num = 'haaaa_aaaa_aaaa_aaaa_aaaa_aaaa_aaaa;

    wr_apply_sig = 'hffff;
    wr_vt_addr = {16{16'd0}};
    wr_data = {16{128'd34762}};
    wea = 'hffff;

    #20
    wr_vt_addr = {16{16'd1}};
    wr_apply_sig = 'd0;
    wr_data = {16{128'd34763}};

    #20
    wr_vt_addr = {16{16'd2}};
    wr_data = {16{128'd34764}};

    #20
    wr_vt_addr = {16{16'd3}};
    wr_data = {16{128'd34765}};

    #20
    wr_vt_addr = {16{16'd4}};
    wr_data = {16{128'd34766}};

    #20
    wr_vt_addr = {16{16'd5}};
    wr_data = {16{128'd34767}};

    #20
    wr_vt_addr = {16{16'd6}};
    wr_data = {16{128'd34768}};

    #20
    wr_vt_addr = {16{16'd7}};
    wr_data = {16{128'd34769}};

    #20
    wr_vt_addr = {16{16'd8}};
    wr_data = {16{128'd34770}};

    #50
    write_done = 'hffff;

    rd_req = 'hffff;
    rd_pd = {16{9'd0, 16'd0, 7'd8}};
    
end

always #5 clk = ~clk;
always #10 wr_clk = ~wr_clk;

MMU_top MMU_top_u(
    .i_clk(clk),
    .i_rst_n(rst_n),

    .i_mem_req(mem_req),
    .i_mem_apply_num(mem_apply_num),

    // write
    .i_wr_clk(wr_clk),
    .i_wr_port_sel(wr_sel),
    .i_wr_apply_sig(wr_apply_sig),
    .i_wr_vt_addr(wr_vt_addr),             
    .i_wr_data(wr_data),                 
    .i_wea(wea),                     
    .i_write_done(write_done),

    // read 
    .i_rd_port_sel(rd_sel),
    .i_read_apply(rd_req),
    .i_pd(rd_pd)
);


endmodule
