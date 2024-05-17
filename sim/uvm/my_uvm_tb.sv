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
    logic        write_done;
    logic        rdy;
    logic [63:0] rd_data;
    logic        rd_sop;
    logic        rd_eop;
    logic        rd_vld;    
endinterface

module multiport_sbuffer_top_tb;

localparam int DATA_SIZE = 100;
localparam int CLOCK_PERIOD = 10;

logic clk, rst_n;

port_interface port1(clk, rst_n);
port_interface port2(clk, rst_n);
port_interface port3(clk, rst_n);
port_interface port4(clk, rst_n);

Multiport_sBuffer_top Multiport_sBuffer_top_inst(
    .clk                  (clk),
    .rst_n                (rst_n),

    .p1_wr_sop            (port1.wr_sop),
    .p1_wr_eop            (port1.wr_eop),
    .p1_wr_vld            (port1.wr_vld),
    .p1_wr_data           (port1.wr_data),
    .p1_almost_full       (port1.almost_full),
    .p1_full              (port1.full),
    .p1_ready             (port1.rdy),
    .p1_rd_data           (port1.rd_data),
    .p1_rd_sop            (port1.rd_sop),
    .p1_rd_eop            (port1.rd_eop),
    .p1_rd_vld            (port1.rd_vld),

    .p2_wr_sop            (port2.wr_sop),
    .p2_wr_eop            (port2.wr_eop),
    .p2_wr_vld            (port2.wr_vld),
    .p2_wr_data           (port2.wr_data),
    .p2_almost_full       (port2.almost_full),
    .p2_full              (port2.full),
    .p2_ready             (port2.rdy),
    .p2_rd_data           (port2.rd_data),
    .p2_rd_sop            (port2.rd_sop),
    .p2_rd_eop            (port2.rd_eop),
    .p2_rd_vld            (port2.rd_vld),

    .p3_wr_sop            (port3.wr_sop),
    .p3_wr_eop            (port3.wr_eop),
    .p3_wr_vld            (port3.wr_vld),
    .p3_wr_data           (port3.wr_data),
    .p3_almost_full       (port3.almost_full),
    .p3_full              (port3.full),
    .p3_ready             (port3.rdy),
    .p3_rd_data           (port3.rd_data),
    .p3_rd_sop            (port3.rd_sop),
    .p3_rd_eop            (port3.rd_eop),
    .p3_rd_vld            (port3.rd_vld),

    .p4_wr_sop            (port4.wr_sop),
    .p4_wr_eop            (port4.wr_eop),
    .p4_wr_vld            (port4.wr_vld),
    .p4_wr_data           (port4.wr_data),
    .p4_almost_full       (port4.almost_full),
    .p4_full              (port4.full),
    .p4_ready             (port4.rdy),
    .p4_rd_data           (port4.rd_data),
    .p4_rd_sop            (port4.rd_sop),
    .p4_rd_eop            (port4.rd_eop),
    .p4_rd_vld            (port4.rd_vld)

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
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt1.drv", "port", port1);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt2.drv", "port", port2);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt3.drv", "port", port3);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt4.drv", "port", port4);

   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt1.mon_out", "port", port1);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt1.mon_in", "port", port1);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt2.mon_out", "port", port2);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt2.mon_in", "port", port2);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt3.mon_out", "port", port3);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt3.mon_in", "port", port3);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt4.mon_out", "port", port4);
   uvm_config_db#(virtual port_interface)::set(null, "uvm_test_top.env.agt4.mon_in", "port", port4);

	run_test("base_test");
end
endmodule