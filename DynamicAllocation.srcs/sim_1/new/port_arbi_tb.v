`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/15 17:18:58
// Design Name: 
// Module Name: port_arbi_tb
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


module port_arbi_tb();
reg clk;
reg rst_n;
reg [31:0] pram_state;
reg        pram_apply_mem_done;
reg [223:0] pram_free_space;
reg [31:0] bigger_than_128;

reg pram_chip_apply_fail;
reg pram_chip_apply_success;

reg mem_req;
reg [6:0] mem_apply_num;
reg pram_addr;

port_arbi #(
    .PRIORITY_PRAM_NUM(11)
)
port_arbi_u (
    .i_clk(clk),
    .i_rst_n(rst_n),

    .i_pram_state(pram_state),
    .i_pram_apply_mem_done(pram_apply_mem_done),
    .i_pram_free_space(pram_free_space),
    .i_bigger_than_64(bigger_than_128),

    .i_pram_chip_apply_success(pram_chip_apply_success),
    .i_pram_chip_apply_fail(pram_chip_apply_fail),

    .i_mem_req(mem_req),
    .i_mem_apply_num(mem_apply_num)
);

initial begin 
    clk = 1'b0;
    rst_n = 1'b0;

    #10
    rst_n = 1'b1; 

    bigger_than_128 = 32'h0000_0000;

    //bigger_than_128 = 32'h8000_0010;
    pram_free_space = 224'hff_ff_ff_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_ff_00_00_00_00;
    pram_state = 32'hffff_ffff;

    #50
    pram_chip_apply_success = 1'b1;
    pram_chip_apply_fail = 1'b0;

    #20
    mem_req = 1'b1;
    mem_apply_num = 7'd55;
    #100
    pram_apply_mem_done = 1'b1;
end

always #5 clk = ~clk;

endmodule
