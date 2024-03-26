`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 极链缘起 
// Engineer: mengcheng cgc
// 
// Create Date: 2024/03/12 09:55:26
// Design Name: 
// Module Name: multiport_sbuffer_top_tb
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
interface port_interface();
    logic        wr_sop;
    logic        wr_eop;
    logic        wr_vld;
    logic [63:0] wr_data;
    logic        full;
    logic        almost_full;
    logic        write_done;
endinterface //port_interface

class packet;
rand logic [63:0] data;
constraint c {data > 64'd0; data < 64'hFFFFFFFF_FFFFFFFF;}
endclass

module multiport_sbuffer_top_tb;

string IN_FILE_NAME = "../../../../data.txt";
string IN_FILE_NAME1 = "../../../../data1.txt";
string IN_FILE_NAME2 = "../../../../data2.txt";
string IN_FILE_NAME3 = "../../../../data3.txt";

localparam int DATA_SIZE = 100;
localparam int CLOCK_PERIOD = 10;

logic clk, rst_n;

port_interface port1();
port_interface port2();
port_interface port3();
port_interface port4();

Multiport_sBuffer_top Multiport_sBuffer_top_inst(
    .clk                  (clk),
    .rst_n                (rst_n),

    .p1_wr_sop            (port1.wr_sop),
    .p1_wr_eop            (port1.wr_eop),
    .p1_wr_vld            (port1.wr_vld),
    .p1_wr_data           (port1.wr_data),
    .p1_almost_full       (port1.almost_full),
    .p1_full              (port1.full),

    .p2_wr_sop            (port2.wr_sop),
    .p2_wr_eop            (port2.wr_eop),
    .p2_wr_vld            (port2.wr_vld),
    .p2_wr_data           (port2.wr_data),
    .p2_almost_full       (port2.almost_full),
    .p2_full              (port2.full),

    .p3_wr_sop            (port3.wr_sop),
    .p3_wr_eop            (port3.wr_eop),
    .p3_wr_vld            (port3.wr_vld),
    .p3_wr_data           (port3.wr_data),
    .p3_almost_full       (port3.almost_full),
    .p3_full              (port3.full),

    .p4_wr_sop            (port4.wr_sop),
    .p4_wr_eop            (port4.wr_eop),
    .p4_wr_vld            (port4.wr_vld),
    .p4_wr_data           (port4.wr_data),
    .p4_almost_full       (port4.almost_full),
    .p4_full              (port4.full)

    );

initial begin
    forever begin
        #(CLOCK_PERIOD/2) clk = 0;
        #(CLOCK_PERIOD/2) clk = 1;
    end
end

initial begin
    @(posedge clk);
    rst_n = 1'b0;
    #(CLOCK_PERIOD*10)
    @(posedge clk);
    rst_n = 1'b1;
end

initial begin: tb_process
    longint start_time, end_time;

    @(posedge rst_n);
    @(posedge clk);
    start_time = $time;

    $display("@ %0t: Beginning simulation...", start_time);
    @(posedge clk);

    wait(port1.write_done & port2.write_done & port3.write_done & port4.write_done);
    #(CLOCK_PERIOD*5) end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    //$display("Total error count: %0d", out_errors);
    $finish;
end

//用任务来创建重复的内容
task automatic port_work(    
    ref  string       IN_FILE_NAME,
    ref  logic        full,
    ref  logic        wr_sop,
    ref  logic        wr_eop,
    ref  logic        wr_vld,
    ref  logic [63:0] wr_data,
    ref  logic        write_done);

    int i, in_file, count;
    logic [63:0] din;

    packet p;

    @(posedge rst_n);
    $display("@ %0t: Loading file %s...", $time, IN_FILE_NAME);
    in_file = $fopen(IN_FILE_NAME, "r");
    // i = 0;
    p = new();
    wr_sop = 0;
    wr_eop = 0;
    wr_vld = 0;
    wr_data = 64'dz;
    write_done = 0;

    //$display("%d", in_file);
    @(posedge clk);
    wr_sop = 1'b1;
    /*read data from text file*/
    while ( i < DATA_SIZE ) begin
        @(negedge clk);
        wr_sop = 1'b0;
        if (full == 1'b0) begin
            count = $fscanf(in_file,"%016h", din);
            $display("%d", din);
            p.randomize();
            wr_data = p.data;
            wr_vld = 1'b1;
        end else begin
            wr_vld = 1'b0;
        end
        i++;
    end

    @(negedge clk);
    wr_vld = 1'b0;
    wr_eop = 1'b1;
    @(negedge clk);
    wr_eop = 1'b0;
    $display("CLOSING IN FILE");
    $fclose(in_file);
    write_done = 1'b1;
endtask

/* 多线程执行多端口任务 */
initial begin
    fork
        port_work(IN_FILE_NAME,  port1.full, port1.wr_sop, port1.wr_eop, port1.wr_vld, port1.wr_data, port1.write_done);
        port_work(IN_FILE_NAME1, port2.full, port2.wr_sop, port2.wr_eop, port2.wr_vld, port2.wr_data, port2.write_done);
        port_work(IN_FILE_NAME2, port3.full, port3.wr_sop, port3.wr_eop, port3.wr_vld, port3.wr_data, port3.write_done);
        port_work(IN_FILE_NAME3, port4.full, port4.wr_sop, port4.wr_eop, port4.wr_vld, port4.wr_data, port4.write_done);
    join
end

endmodule