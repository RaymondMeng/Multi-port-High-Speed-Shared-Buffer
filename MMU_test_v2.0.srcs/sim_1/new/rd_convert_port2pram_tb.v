`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2024 02:18:22 PM
// Design Name: 
// Module Name: rd_convert_port2pram_tb
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


module rd_convert_port2pram_tb();

reg clk;
reg rd_req;
reg rd_ready;
reg [22:0] rd_pd;
reg [31:0] rd_done;

always #5 clk = ~clk;

initial begin
    clk = 0;
    rd_req = 0;
    rd_ready = 0;
    rd_pd = 'd0;
    rd_done = 'd0;

    #10
    rd_pd = {16'd0, 7'd33};
    rd_req = 1;
    rd_ready = 1;

    #50
    rd_done = 'h0001;
end

rd_convert_port2pram rd_convert_port2pram_u(
    .i_clk(clk),

    .i_rd_req(rd_req),
    .i_rd_ready(rd_ready),
    .i_rd_pd(rd_pd),
    
    .i_rd_done(rd_done),

    .o_rd_req(),
    .o_rd_ready(),
    .o_rd_pd(),

    .o_rd_done()
);


endmodule
