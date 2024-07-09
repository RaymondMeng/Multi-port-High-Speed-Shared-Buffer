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

    #20
    rst_n = 1;
    wr_sel = {5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd5, 
              5'd0, 
              5'd3, 
              5'd2, 
              5'd1, 
              5'd0};

    wr_apply_sig = 'h002f;

    wr_vt_addr = {16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0,
                  16'd0};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               {64'd0, 64'd11},
               128'd0,
               {64'd0, 64'd12},
               {64'd0, 64'd13},
               {64'd0, 64'd14},
               {64'd0, 64'd15}};
    wea = 'h002f;

    #20
    wr_vt_addr = {16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1,
                  16'd1};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55001,
               128'd0,
               128'd44001,
               128'd33001,
               128'd22001,
               128'd1};

    #20
    wr_vt_addr = {16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2,
                  16'd2};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55002,
               128'd0,
               128'd44002,
               128'd33002,
               128'd22002,
               128'd1};

    #20
    wr_vt_addr = {16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3,
                  16'd3};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55003,
               128'd0,
               128'd44003,
               128'd33003,
               128'd22003,
               128'd1};

    #20
    wr_vt_addr = {16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4,
                  16'd4};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55004,
               128'd0,
               128'd44004,
               128'd33004,
               128'd22004,
               128'd1};

    #20
    wr_vt_addr = {16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5,
                  16'd5};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55005,
               128'd0,
               128'd44005,
               128'd33005,
               128'd22005,
               128'd1};

    #20
    wr_vt_addr = {16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6,
                  16'd6};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55006,
               128'd0,
               128'd44006,
               128'd33006,
               128'd22006,
               128'd1};

    #20
    wr_vt_addr = {16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7,
                  16'd7};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55007,
               128'd0,
               128'd44007,
               128'd33007,
               128'd22007,
               128'd1};

    #20
    wr_vt_addr = {16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8,
                  16'd8};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55008,
               128'd0,
               128'd44008,
               128'd33008,
               128'd22008,
               128'd1};

    #100
    wr_sel = {5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd5, 
              5'd0, 
              5'd3, 
              5'd2, 
              5'd1, 
              5'd0};

    wr_apply_sig = 'h002f;

    wr_vt_addr = {16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9,
                  16'd9};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               {64'd0, 64'd8},
               128'd0,
               {64'd0, 64'd7},
               {64'd0, 64'd6},
               {64'd0, 64'd5},
               {64'd0, 64'd4}};
    wea = 'h002f;

    #20
    wr_vt_addr = {16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10,
                  16'd10};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55010,
               128'd0,
               128'd44010,
               128'd33010,
               128'd22010,
               128'd11010};

    #20
    wr_vt_addr = {16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11,
                  16'd11};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55011,
               128'd0,
               128'd44011,
               128'd33011,
               128'd22011,
               128'd11011};

    #20
    wr_vt_addr = {16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12,
                  16'd12};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55012,
               128'd0,
               128'd44012,
               128'd33012,
               128'd22012,
               128'd11012};

    #20
    wr_vt_addr = {16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13,
                  16'd13};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd550013,
               128'd0,
               128'd440013,
               128'd330013,
               128'd220013,
               128'd110013};

    write_done = 'h0003;
    wr_apply_sig = 'h0;
    wea = 'h002c;

    #20
    wr_vt_addr = {16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14,
                  16'd14};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd55014,
               128'd0,
               128'd44014,
               128'd33014,
               128'd22005,
               128'd1};

    #20
    wr_vt_addr = {16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15,
                  16'd15};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd550015,
               128'd0,
               128'd440015,
               128'd330015,
               128'd22006,
               128'd1};

    #20
    wr_vt_addr = {16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16,
                  16'd16};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd550016,
               128'd0,
               128'd440016,
               128'd330016,
               128'd22007,
               128'd1};

    #20
    wr_vt_addr = {16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17,
                  16'd17};

    wr_data = {128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd0,
               128'd550017,
               128'd0,
               128'd440017,
               128'd330017,
               128'd22008,
               128'd1};

    #20
    wea = 'd0;
    write_done = 'h002c;
    wr_apply_sig = 'd0;

    #30000
    rd_sel = {5'd0, 
              5'd1, 
              5'd2, 
              5'd3, 
              5'd0, 
              5'd5, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0};

    rd_req = 'hf400;

    rd_pd = {{9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9},
             {9'd0, 16'd0, 7'd9}};

    #20
    rd_sel = {5'd0, 
              5'd1, 
              5'd2, 
              5'd3, 
              5'd0, 
              5'd5, 
              5'd0, 
              5'd5, 
              5'd3, 
              5'd2, 
              5'd1, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0, 
              5'd0};

    rd_req = 'h01f0;

    rd_pd = {{9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd4},
             {9'd0, 16'd9, 7'd4},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9},
             {9'd0, 16'd9, 7'd9}};



    // #10
    // rst_n = 1;
    // wr_sel = {5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0};
    // rd_sel = {5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0};

    // #10
    // mem_req = 'hff11;
    // mem_apply_num = 'haaaa_aaaa_aaaa_aaaa_aaaa_aaaa_aaaa;

    // wr_apply_sig = 'hffff;
    // wr_vt_addr = {16{16'd0}};
    // wr_data = {16{128'd34762}};
    // wea = 'hffff;

    // #20
    // wr_vt_addr = {16{16'd1}};
    // wr_apply_sig = 'd0;
    // wr_data = {16{128'd34763}};

    // #20
    // wr_vt_addr = {16{16'd2}};
    // wr_data = {16{128'd34764}};

    // #20
    // wr_vt_addr = {16{16'd3}};
    // wr_data = {16{128'd34765}};

    // #20
    // wr_vt_addr = {16{16'd4}};
    // wr_data = {16{128'd34766}};

    // #20
    // wr_vt_addr = {16{16'd5}};
    // wr_data = {16{128'd34767}};

    // #20
    // wr_vt_addr = {16{16'd6}};
    // wr_data = {16{128'd34768}};

    // #20
    // wr_vt_addr = {16{16'd7}};
    // wr_data = {16{128'd34769}};

    // #20
    // wr_vt_addr = {16{16'd8}};
    // wr_data = {16{128'd34770}};

    // #50
    // write_done = 'hffff;

    // rd_req = 'hffff;
    // rd_pd = {16{9'd0, 16'd0, 7'd8}};
    
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
