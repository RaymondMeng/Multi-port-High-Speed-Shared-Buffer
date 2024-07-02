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

string IN_FILE_NAME0  = "../../../../p1_data.txt"; //932字节，目的端�?0，优先级3
string IN_FILE_NAME1 = "../../../../p2_data.txt";
string IN_FILE_NAME2 = "../../../../p3_data.txt";
string IN_FILE_NAME3 = "../../../../p4_data.txt";
string IN_FILE_NAME4 = "../../../../p5_data.txt"; //932字节，目的端�?0，优先级3
string IN_FILE_NAME5 = "../../../../p6_data.txt";
string IN_FILE_NAME6 = "../../../../p7_data.txt";
string IN_FILE_NAME7 = "../../../../p8_data.txt";
string IN_FILE_NAME8 = "../../../../p9_data.txt"; //932字节，目的端�?0，优先级3
string IN_FILE_NAME9 = "../../../../p10_data.txt";
string IN_FILE_NAME10 = "../../../../p11_data.txt";
string IN_FILE_NAME11 = "../../../../p12_data.txt";
string IN_FILE_NAME12 = "../../../../p13_data.txt"; //932字节，目的端�?0，优先级3
string IN_FILE_NAME13 = "../../../../p14_data.txt";
string IN_FILE_NAME14 = "../../../../p15_data.txt";
string IN_FILE_NAME15 = "../../../../p16_data.txt";

localparam int DATA_SIZE = 118; //932字节�?�?118�?64位信�?
localparam int CLOCK_PERIOD = 10;

logic clk, rst_n;

port_interface port1();
port_interface port2();
port_interface port3();
port_interface port4();
port_interface port5();
port_interface port6();
port_interface port7();
port_interface port8();
port_interface port9();
port_interface port10();
port_interface port11();
port_interface port12();
port_interface port13();
port_interface port14();
port_interface port15();
port_interface port16();

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
    .p4_full              (port4.full),

    .p5_wr_sop            (port5.wr_sop),
    .p5_wr_eop            (port5.wr_eop),
    .p5_wr_vld            (port5.wr_vld),
    .p5_wr_data           (port5.wr_data),
    .p5_almost_full       (port5.almost_full),
    .p5_full              (port5.full),

    .p6_wr_sop            (port6.wr_sop),
    .p6_wr_eop            (port6.wr_eop),
    .p6_wr_vld            (port6.wr_vld),
    .p6_wr_data           (port6.wr_data),
    .p6_almost_full       (port6.almost_full),
    .p6_full              (port6.full),

    .p7_wr_sop            (port7.wr_sop),
    .p7_wr_eop            (port7.wr_eop),
    .p7_wr_vld            (port7.wr_vld),
    .p7_wr_data           (port7.wr_data),
    .p7_almost_full       (port7.almost_full),
    .p7_full              (port7.full),

    .p8_wr_sop            (port8.wr_sop),
    .p8_wr_eop            (port8.wr_eop),
    .p8_wr_vld            (port8.wr_vld),
    .p8_wr_data           (port8.wr_data),
    .p8_almost_full       (port8.almost_full),
    .p8_full              (port8.full),

    .p9_wr_sop            (port9.wr_sop),
    .p9_wr_eop            (port9.wr_eop),
    .p9_wr_vld            (port9.wr_vld),
    .p9_wr_data           (port9.wr_data),
    .p9_almost_full       (port9.almost_full),
    .p9_full              (port9.full),

    .p10_wr_sop           (port10.wr_sop),
    .p10_wr_eop           (port10.wr_eop),
    .p10_wr_vld           (port10.wr_vld),
    .p10_wr_data          (port10.wr_data),
    .p10_almost_full      (port10.almost_full),  
    .p10_full             (port10.full),

    .p11_wr_sop           (port11.wr_sop),
    .p11_wr_eop           (port11.wr_eop),
    .p11_wr_vld           (port11.wr_vld),
    .p11_wr_data          (port11.wr_data),
    .p11_almost_full      (port11.almost_full),
    .p11_full             (port11.full),

    .p12_wr_sop           (port12.wr_sop),
    .p12_wr_eop           (port12.wr_eop),
    .p12_wr_vld           (port12.wr_vld),
    .p12_wr_data          (port12.wr_data),
    .p12_almost_full      (port12.almost_full), 
    .p12_full             (port12.full),

    .p13_wr_sop           (port13.wr_sop),
    .p13_wr_eop           (port13.wr_eop),
    .p13_wr_vld           (port13.wr_vld),
    .p13_wr_data          (port13.wr_data),
    .p13_almost_full      (port13.almost_full),
    .p13_full             (port13.full),

    .p14_wr_sop           (port14.wr_sop),
    .p14_wr_eop           (port14.wr_eop),
    .p14_wr_vld           (port14.wr_vld),
    .p14_wr_data          (port14.wr_data),
    .p14_almost_full      (port14.almost_full),
    .p14_full             (port14.full),

    .p15_wr_sop           (port15.wr_sop),
    .p15_wr_eop           (port15.wr_eop),
    .p15_wr_vld           (port15.wr_vld),
    .p15_wr_data          (port15.wr_data),
    .p15_almost_full      (port15.almost_full),
    .p15_full             (port15.full),

    .p16_wr_sop           (port16.wr_sop),
    .p16_wr_eop           (port16.wr_eop),
    .p16_wr_vld           (port16.wr_vld),
    .p16_wr_data          (port16.wr_data),
    .p16_almost_full      (port16.almost_full),
    .p16_full             (port16.full)
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

    wait(port1.write_done & port2.write_done & port3.write_done & port4.write_done & port5.write_done & port6.write_done & port7.write_done & port8.write_done & port9.write_done & port10.write_done & port11.write_done & port12.write_done & port13.write_done & port14.write_done & port15.write_done & port16.write_done);
    #(CLOCK_PERIOD*5) end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    //$display("Total error count: %0d", out_errors);
    $finish;
end

//用任务来创建重复的内�?
task automatic port_work(    
    ref  string       IN_FILE_NAME,
    ref  logic        full,
    ref  logic        wr_sop,
    ref  logic        wr_eop,
    ref  logic        wr_vld,
    ref  logic [63:0] wr_data,
    ref  logic        write_done);

    int i, in_file, count;
    logic [127:0] din;

    packet p;
    wr_sop = 'dz;
    wr_eop = 'dz;
    wr_vld = 'dz;
    wr_data = 64'dz;
    write_done = 'dz;
    @(posedge rst_n);
    $display("@ %0t: Loading file %s...", $time, IN_FILE_NAME);
    in_file = $fopen(IN_FILE_NAME, "r");
    // i = 0;
    //p = new();
    wr_sop = 0;
    wr_eop = 0;
    wr_vld = 0;
    wr_data = 64'dz;
    write_done = 0;
    #(CLOCK_PERIOD*100);
    //$display("%d", in_file);
    @(posedge clk);
    wr_sop = 1'b1;
    /*read data from text file*/
    while ( i < DATA_SIZE ) begin
        @(negedge clk);
        wr_sop = 1'b0;
        if (full == 1'b0) begin
            count = $fscanf(in_file,"%032h", din);
            $display("%032h", din);
            //p.randomize();
            wr_data = din[127:64];
            wr_vld = 1'b1;
            @(negedge clk);
            wr_data = din[63:0];
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
        port_work(IN_FILE_NAME0,  port1.full, port1.wr_sop, port1.wr_eop, port1.wr_vld, port1.wr_data, port1.write_done);
        port_work(IN_FILE_NAME1, port2.full, port2.wr_sop, port2.wr_eop, port2.wr_vld, port2.wr_data, port2.write_done);
        port_work(IN_FILE_NAME2, port3.full, port3.wr_sop, port3.wr_eop, port3.wr_vld, port3.wr_data, port3.write_done);
        port_work(IN_FILE_NAME3, port4.full, port4.wr_sop, port4.wr_eop, port4.wr_vld, port4.wr_data, port4.write_done);
        port_work(IN_FILE_NAME4, port5.full, port5.wr_sop, port5.wr_eop, port5.wr_vld, port5.wr_data, port5.write_done);
        port_work(IN_FILE_NAME5, port6.full, port6.wr_sop, port6.wr_eop, port6.wr_vld, port6.wr_data, port6.write_done);
        port_work(IN_FILE_NAME6, port7.full, port7.wr_sop, port7.wr_eop, port7.wr_vld, port7.wr_data, port7.write_done);
        port_work(IN_FILE_NAME7, port8.full, port8.wr_sop, port8.wr_eop, port8.wr_vld, port8.wr_data, port8.write_done);
        port_work(IN_FILE_NAME8, port9.full, port9.wr_sop, port9.wr_eop, port9.wr_vld, port9.wr_data, port9.write_done);
        port_work(IN_FILE_NAME9, port10.full, port10.wr_sop, port10.wr_eop, port10.wr_vld, port10.wr_data, port10.write_done);
        port_work(IN_FILE_NAME10, port11.full, port11.wr_sop, port11.wr_eop, port11.wr_vld, port11.wr_data, port11.write_done);
        port_work(IN_FILE_NAME11, port12.full, port12.wr_sop, port12.wr_eop, port12.wr_vld, port12.wr_data, port12.write_done);
        port_work(IN_FILE_NAME12, port13.full, port13.wr_sop, port13.wr_eop, port13.wr_vld, port13.wr_data, port13.write_done);
        port_work(IN_FILE_NAME13, port14.full, port14.wr_sop, port14.wr_eop, port14.wr_vld, port14.wr_data, port14.write_done);
        port_work(IN_FILE_NAME14, port15.full, port15.wr_sop, port15.wr_eop, port15.wr_vld, port15.wr_data, port15.write_done);
        port_work(IN_FILE_NAME15, port16.full, port16.wr_sop, port16.wr_eop, port16.wr_vld, port16.wr_data, port16.write_done);
    join
end

endmodule