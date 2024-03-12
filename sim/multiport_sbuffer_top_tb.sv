`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
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


module multiport_sbuffer_top_tb;

localparam IN_FILE_NAME = "../../../../data.txt";
localparam IN_FILE_NAME1 = "../../../../data1.txt";
localparam IN_FILE_NAME2 = "../../../../data2.txt";
localparam IN_FILE_NAME3 = "../../../../data3.txt";

localparam int CLOCK_PERIOD = 10;
localparam int DATA_SIZE = 100;

logic clk, rst_n;

logic p1_wr_sop, p1_wr_eop, p1_wr_vld,
      p2_wr_sop, p2_wr_eop, p2_wr_vld, 
      p3_wr_sop, p3_wr_eop, p3_wr_vld,
      p4_wr_sop, p4_wr_eop, p4_wr_vld;

logic [63:0] p1_wr_data, p2_wr_data, p3_wr_data, p4_wr_data;
logic p1_almost_full, p1_full, p2_almost_full, p2_full, 
      p3_almost_full, p3_full, p4_almost_full, p4_full;

logic write_done = 'd0;
logic write1_done = 'd0;
logic write2_done = 'd0;
logic write3_done = 'd0;
// integer out_errors = 0;

Multiport_sBuffer_top Multiport_sBuffer_top_inst(
    .clk                  (clk),
    .rst_n                (rst_n),

    .p1_wr_sop            (p1_wr_sop),
    .p1_wr_eop            (p1_wr_eop),
    .p1_wr_vld            (p1_wr_vld),
    .p1_wr_data           (p1_wr_data),
    .p1_almost_full       (p1_almost_full),
    .p1_full              (p1_full),

    .p2_wr_sop            (p2_wr_sop),
    .p2_wr_eop            (p2_wr_eop),
    .p2_wr_vld            (p2_wr_vld),
    .p2_wr_data           (p2_wr_data),
    .p2_almost_full       (p2_almost_full),
    .p2_full              (p2_full),

    .p3_wr_sop            (p3_wr_sop),
    .p3_wr_eop            (p3_wr_eop),
    .p3_wr_vld            (p3_wr_vld),
    .p3_wr_data           (p3_wr_data),
    .p3_almost_full       (p3_almost_full),
    .p3_full              (p3_full),

    .p4_wr_sop            (p4_wr_sop),
    .p4_wr_eop            (p4_wr_eop),
    .p4_wr_vld            (p4_wr_vld),
    .p4_wr_data           (p4_wr_data),
    .p4_almost_full       (p4_almost_full),
    .p4_full              (p4_full)

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

    wait(write_done & write1_done & write2_done & write3_done);
    #(CLOCK_PERIOD*5) end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    //$display("Total error count: %0d", out_errors);
    $finish;
end

/*定向测试：四个端口同时工作且转发内容相同*/
initial begin: p1_read_process
    int i, in_file, count;
    logic [63:0] din;
    @(posedge rst_n);
    $display("@ %0t: Loading file %s...", $time, IN_FILE_NAME);
    in_file = $fopen(IN_FILE_NAME, "r");
    p1_wr_sop = 0;
    p1_wr_eop = 0;
    p1_wr_vld = 0;
    p1_wr_data = 64'dz;

    @(posedge clk);
    p1_wr_sop = 1'b1;
    /*read data from text file*/
    while ( i < DATA_SIZE ) begin
        @(negedge clk);
        p1_wr_sop = 1'b0;
        if (p1_full == 1'b0) begin
            count = $fscanf(in_file,"%016h", din);
            //$display("%d", din);
            p1_wr_data = din;
            p1_wr_vld = 1'b1;
        end else begin
            p1_wr_vld = 1'b0;
        end
        i++;
    end

    @(negedge clk);
    p1_wr_vld = 1'b0;
    p1_wr_eop = 1'b1;
    @(negedge clk);
    p1_wr_eop = 1'b0;
    $display("CLOSING IN FILE");
    $fclose(in_file);
    write_done = 1'b1;
end

initial begin: p2_read_process
    int i, in_file, count;
    logic [63:0] din;
    @(posedge rst_n);
    $display("@ %0t: Loading file %s...", $time, IN_FILE_NAME1);
    in_file = $fopen(IN_FILE_NAME1, "r");
    p2_wr_sop = 0;
    p2_wr_eop = 0;
    p2_wr_vld = 0;
    p2_wr_data = 64'dz;

    @(posedge clk);
    p2_wr_sop = 1'b1;
    /*read data from text file*/
    while ( i < DATA_SIZE ) begin
        @(negedge clk);
        p2_wr_sop = 1'b0;
        if (p2_full == 1'b0) begin
            count = $fscanf(in_file,"%016h", din);
            //$display("%d", din);
            p2_wr_data = din;
            p2_wr_vld = 1'b1;
        end else begin
            p2_wr_vld = 1'b0;
        end
        i++;
    end

    @(negedge clk);
    p2_wr_vld = 1'b0;
    p2_wr_eop = 1'b1;
    @(negedge clk);
    p2_wr_eop = 1'b0;
    $display("CLOSING IN FILE1");
    $fclose(in_file);
    write1_done = 1'b1;
end

initial begin: p3_read_process
    int i, in_file, count;
    logic [63:0] din;
    @(posedge rst_n);
    $display("@ %0t: Loading file %s...", $time, IN_FILE_NAME2);
    in_file = $fopen(IN_FILE_NAME2, "r");
    p3_wr_sop = 0;
    p3_wr_eop = 0;
    p3_wr_vld = 0;
    p3_wr_data = 64'dz;

    @(posedge clk);
    p3_wr_sop = 1'b1;
    /*read data from text file*/
    while ( i < DATA_SIZE ) begin
        @(negedge clk);
        p3_wr_sop = 1'b0;
        if (p3_full == 1'b0) begin
            count = $fscanf(in_file,"%016h", din);
            //$display("%d", din);
            p3_wr_data = din;
            p3_wr_vld = 1'b1;
        end else begin
            p3_wr_vld = 1'b0;
        end
        i++;
    end

    @(negedge clk);
    p3_wr_vld = 1'b0;
    p3_wr_eop = 1'b1;
    @(negedge clk);
    p3_wr_eop = 1'b0;
    $display("CLOSING IN FILE2");
    $fclose(in_file);
    write2_done = 1'b1;
end

initial begin: p4_read_process
    int i, in_file, count;
    logic [63:0] din;
    @(posedge rst_n);
    $display("@ %0t: Loading file %s...", $time, IN_FILE_NAME3);
    in_file = $fopen(IN_FILE_NAME3, "r");
    p4_wr_sop = 0;
    p4_wr_eop = 0;
    p4_wr_vld = 0;
    p4_wr_data = 64'dz;

    @(posedge clk);
    p4_wr_sop = 1'b1;
    /*read data from text file*/
    while ( i < DATA_SIZE ) begin
        @(negedge clk);
        p4_wr_sop = 1'b0;
        if (p4_full == 1'b0) begin
            count = $fscanf(in_file,"%016h", din);
            //$display("%d", din);
            p4_wr_data = din;
            p4_wr_vld = 1'b1;
        end else begin
            p4_wr_vld = 1'b0;
        end
        i++;
    end

    @(negedge clk);
    p4_wr_vld = 1'b0;
    p4_wr_eop = 1'b1;
    @(negedge clk);
    p4_wr_eop = 1'b0;
    $display("CLOSING IN FILE3");
    $fclose(in_file);
    write3_done = 1'b1;
end

endmodule
