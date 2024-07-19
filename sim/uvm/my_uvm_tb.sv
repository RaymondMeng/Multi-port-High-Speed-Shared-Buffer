`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 极链缘起 
// Engineer: mengcheng
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
import uvm_pkg::*;
import my_package::*;

interface port_interface(input clk, input rst_n);
    logic        wr_sop;
    logic        wr_eop;
    logic        wr_vld;
    logic [63:0] wr_data;

    logic        full;
    logic        almost_full;

    logic        rd_sop;
    logic        rd_eop;
    logic        rd_vld;
    logic [63:0] rd_data;
    logic        rd_rdy;    
endinterface

module multiport_sbuffer_top_tb;

localparam int DATA_SIZE = 100;
localparam int CLOCK_PERIOD = 10;

logic clk, rst_n;

port_interface port1(clk, rst_n);
port_interface port2(clk, rst_n);
port_interface port3(clk, rst_n);
port_interface port4(clk, rst_n);
port_interface port5(clk, rst_n);
port_interface port6(clk, rst_n);
port_interface port7(clk, rst_n);
port_interface port8(clk, rst_n);
port_interface port9(clk, rst_n);
port_interface port10(clk, rst_n);
port_interface port11(clk, rst_n);
port_interface port12(clk, rst_n);
port_interface port13(clk, rst_n);
port_interface port14(clk, rst_n);
port_interface port15(clk, rst_n);
port_interface port16(clk, rst_n);

Multiport_sBuffer_top Multiport_sBuffer_top_inst(
    .clk                  (clk),
    .rst_n                (rst_n),

    .p1_wr_sop            (port1.wr_sop),
    .p1_wr_eop            (port1.wr_eop),
    .p1_wr_vld            (port1.wr_vld),
    .p1_wr_data           (port1.wr_data),
    .p1_almost_full       (port1.almost_full),
    .p1_full              (port1.full),
    .p1_rd_sop            (port1.rd_sop),
    .p1_rd_eop            (port1.rd_eop),
    .p1_rd_vld            (port1.rd_vld),
    .p1_rd_data           (port1.rd_data),
    .p1_rd_ready          (port1.rd_rdy),
    

    .p2_wr_sop            (port2.wr_sop),
    .p2_wr_eop            (port2.wr_eop),
    .p2_wr_vld            (port2.wr_vld),
    .p2_wr_data           (port2.wr_data),
    .p2_almost_full       (port2.almost_full),
    .p2_full              (port2.full),
    .p2_rd_sop            (port2.rd_sop),
    .p2_rd_eop            (port2.rd_eop),
    .p2_rd_vld            (port2.rd_vld),
    .p2_rd_data           (port2.rd_data),
    .p2_rd_ready          (port2.rd_rdy),

    .p3_wr_sop            (port3.wr_sop),
    .p3_wr_eop            (port3.wr_eop),
    .p3_wr_vld            (port3.wr_vld),
    .p3_wr_data           (port3.wr_data),
    .p3_almost_full       (port3.almost_full),
    .p3_full              (port3.full),
    .p3_rd_sop            (port3.rd_sop),
    .p3_rd_eop            (port3.rd_eop),
    .p3_rd_vld            (port3.rd_vld),
    .p3_rd_data           (port3.rd_data),
    .p3_rd_ready          (port3.rd_rdy),

    .p4_wr_sop            (port4.wr_sop),
    .p4_wr_eop            (port4.wr_eop),
    .p4_wr_vld            (port4.wr_vld),
    .p4_wr_data           (port4.wr_data),
    .p4_almost_full       (port4.almost_full),
    .p4_full              (port4.full),
    .p4_rd_sop            (port4.rd_sop),
    .p4_rd_eop            (port4.rd_eop),
    .p4_rd_vld            (port4.rd_vld),
    .p4_rd_data           (port4.rd_data),
    .p4_rd_ready          (port4.rd_rdy),

    .p5_wr_sop            (port5.wr_sop),
    .p5_wr_eop            (port5.wr_eop),
    .p5_wr_vld            (port5.wr_vld),
    .p5_wr_data           (port5.wr_data),
    .p5_almost_full       (port5.almost_full),
    .p5_full              (port5.full),
    .p5_rd_sop            (port5.rd_sop),
    .p5_rd_eop            (port5.rd_eop),
    .p5_rd_vld            (port5.rd_vld),
    .p5_rd_data           (port5.rd_data),
    .p5_rd_ready          (port5.rd_rdy),

    .p6_wr_sop            (port6.wr_sop),
    .p6_wr_eop            (port6.wr_eop),
    .p6_wr_vld            (port6.wr_vld),
    .p6_wr_data           (port6.wr_data),
    .p6_almost_full       (port6.almost_full),
    .p6_full              (port6.full),
    .p6_rd_sop            (port6.rd_sop),
    .p6_rd_eop            (port6.rd_eop),
    .p6_rd_vld            (port6.rd_vld),
    .p6_rd_data           (port6.rd_data),
    .p6_rd_ready          (port6.rd_rdy),

    .p7_wr_sop            (port7.wr_sop),
    .p7_wr_eop            (port7.wr_eop),
    .p7_wr_vld            (port7.wr_vld),
    .p7_wr_data           (port7.wr_data),
    .p7_almost_full       (port7.almost_full),
    .p7_full              (port7.full),
    .p7_rd_sop            (port7.rd_sop),
    .p7_rd_eop            (port7.rd_eop),
    .p7_rd_vld            (port7.rd_vld),
    .p7_rd_data           (port7.rd_data),
    .p7_rd_ready          (port7.rd_rdy),

    .p8_wr_sop            (port8.wr_sop),
    .p8_wr_eop            (port8.wr_eop),
    .p8_wr_vld            (port8.wr_vld),
    .p8_wr_data           (port8.wr_data),
    .p8_almost_full       (port8.almost_full),
    .p8_full              (port8.full),
    .p8_rd_sop            (port8.rd_sop),
    .p8_rd_eop            (port8.rd_eop),
    .p8_rd_vld            (port8.rd_vld),
    .p8_rd_data           (port8.rd_data),
    .p8_rd_ready          (port8.rd_rdy),

    .p9_wr_sop            (port9.wr_sop),
    .p9_wr_eop            (port9.wr_eop),
    .p9_wr_vld            (port9.wr_vld),
    .p9_wr_data           (port9.wr_data),
    .p9_almost_full       (port9.almost_full),
    .p9_full              (port9.full),
    .p9_rd_sop            (port9.rd_sop),
    .p9_rd_eop            (port9.rd_eop),
    .p9_rd_vld            (port9.rd_vld),
    .p9_rd_data           (port9.rd_data),
    .p9_rd_ready          (port9.rd_rdy),

    .p10_wr_sop            (port10.wr_sop),
    .p10_wr_eop            (port10.wr_eop),
    .p10_wr_vld            (port10.wr_vld),
    .p10_wr_data           (port10.wr_data),
    .p10_almost_full       (port10.almost_full),
    .p10_full              (port10.full),
    .p10_rd_sop            (port10.rd_sop),
    .p10_rd_eop            (port10.rd_eop),
    .p10_rd_vld            (port10.rd_vld),
    .p10_rd_data           (port10.rd_data),
    .p10_rd_ready          (port10.rd_rdy),

    .p11_wr_sop            (port11.wr_sop),
    .p11_wr_eop            (port11.wr_eop),
    .p11_wr_vld            (port11.wr_vld),
    .p11_wr_data           (port11.wr_data),
    .p11_almost_full       (port11.almost_full),
    .p11_full              (port11.full),
    .p11_rd_sop            (port11.rd_sop),
    .p11_rd_eop            (port11.rd_eop),
    .p11_rd_vld            (port11.rd_vld),
    .p11_rd_data           (port11.rd_data),
    .p11_rd_ready          (port11.rd_rdy),

    .p12_wr_sop            (port12.wr_sop),
    .p12_wr_eop            (port12.wr_eop),
    .p12_wr_vld            (port12.wr_vld),
    .p12_wr_data           (port12.wr_data),
    .p12_almost_full       (port12.almost_full),
    .p12_full              (port12.full),
    .p12_rd_sop            (port12.rd_sop),
    .p12_rd_eop            (port12.rd_eop),
    .p12_rd_vld            (port12.rd_vld),
    .p12_rd_data           (port12.rd_data),
    .p12_rd_ready          (port12.rd_rdy),

    .p13_wr_sop            (port13.wr_sop),
    .p13_wr_eop            (port13.wr_eop),
    .p13_wr_vld            (port13.wr_vld),
    .p13_wr_data           (port13.wr_data),
    .p13_almost_full       (port13.almost_full),
    .p13_full              (port13.full),
    .p13_rd_sop            (port13.rd_sop),
    .p13_rd_eop            (port13.rd_eop),
    .p13_rd_vld            (port13.rd_vld),
    .p13_rd_data           (port13.rd_data),
    .p13_rd_ready          (port13.rd_rdy),

    .p14_wr_sop            (port14.wr_sop),
    .p14_wr_eop            (port14.wr_eop),
    .p14_wr_vld            (port14.wr_vld),
    .p14_wr_data           (port14.wr_data),
    .p14_almost_full       (port14.almost_full),
    .p14_full              (port14.full),
    .p14_rd_sop            (port14.rd_sop),
    .p14_rd_eop            (port14.rd_eop),
    .p14_rd_vld            (port14.rd_vld),
    .p14_rd_data           (port14.rd_data),
    .p14_rd_ready          (port14.rd_rdy),

    .p15_wr_sop            (port15.wr_sop),
    .p15_wr_eop            (port15.wr_eop),
    .p15_wr_vld            (port15.wr_vld),
    .p15_wr_data           (port15.wr_data),
    .p15_almost_full       (port15.almost_full),
    .p15_full              (port15.full),
    .p15_rd_sop            (port15.rd_sop),
    .p15_rd_eop            (port15.rd_eop),
    .p15_rd_vld            (port15.rd_vld),
    .p15_rd_data           (port15.rd_data),
    .p15_rd_ready          (port15.rd_rdy),

    .p16_wr_sop            (port16.wr_sop),
    .p16_wr_eop            (port16.wr_eop),
    .p16_wr_vld            (port16.wr_vld),
    .p16_wr_data           (port16.wr_data),
    .p16_almost_full       (port16.almost_full),
    .p16_full              (port16.full),
    .p16_rd_sop            (port16.rd_sop),
    .p16_rd_eop            (port16.rd_eop),
    .p16_rd_vld            (port16.rd_vld),
    .p16_rd_data           (port16.rd_data),
    .p16_rd_ready          (port16.rd_rdy)

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

initial begin
    #30000;
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in0.drv", "port", port1);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in1.drv", "port", port2);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in2.drv", "port", port3);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in3.drv", "port", port4);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in4.drv", "port", port5);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in5.drv", "port", port6);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in6.drv", "port", port7);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in7.drv", "port", port8);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in8.drv", "port", port9);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in9.drv", "port", port10);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in10.drv", "port", port11);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in11.drv", "port", port12);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in12.drv", "port", port13);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in13.drv", "port", port14);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in14.drv", "port", port15);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in15.drv", "port", port16);

    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out0.mon_out", "port", port1);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out1.mon_out", "port", port2);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out2.mon_out", "port", port3);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out3.mon_out", "port", port4);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out4.mon_out", "port", port5);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out5.mon_out", "port", port6);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out6.mon_out", "port", port7);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out7.mon_out", "port", port8);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out8.mon_out", "port", port9);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out9.mon_out", "port", port10);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out10.mon_out", "port", port11);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out11.mon_out", "port", port12);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out12.mon_out", "port", port13);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out13.mon_out", "port", port14);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out14.mon_out", "port", port15);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_out15.mon_out", "port", port16);

    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in0.mon_in", "port", port1);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in1.mon_in", "port", port2);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in2.mon_in", "port", port3);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in3.mon_in", "port", port4);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in4.mon_in", "port", port5);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in5.mon_in", "port", port6);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in6.mon_in", "port", port7);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in7.mon_in", "port", port8);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in8.mon_in", "port", port9);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in9.mon_in", "port", port10);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in10.mon_in", "port", port11);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in11.mon_in", "port", port12);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in12.mon_in", "port", port13);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in13.mon_in", "port", port14);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in14.mon_in", "port", port15);
    uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt_in15.mon_in", "port", port16);

    run_test("base_test");
end
endmodule