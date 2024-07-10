`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/14 17:29
// Design Name: 
// Module Name: priority_schedule
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  priority: high -> low
//                           0  -> 7
//               strategy: sp WRR
//                         
//             /* pq_sel划分优先级队列 */   
//      分组索引号  3    2     1     0    优先级队列索引号
//                12    8     4     0        0 ~ 7
//                13    9     5     1        8 ~ 15
//                14    10    6     2       16 ~ 23
//                15    11    7     3       24 ~ 31
//                                 
//              
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module Priority_strategy (
    input                                    i_clk,
    input                                    i_rst_n,
    input        [7:0]                       i_pq_empty,
    input        [39:0]                      i_queue_cnt,
    output       [7:0]                       o_pq_rd_en,
    output       [2:0]                       o_pq_sel,
    output                                   o_cache_en
);

//还是得加empty信号

reg [1:0] state;
reg [2:0] RR;
reg pq_rd_en;
reg [2:0] pq_sel;
reg cache_en;
reg [4:0] queue_weight [7:0];
wire [4:0] queue_cnt [7:0]; //在priority queue fifo中例化
reg [4:0] queue_weight_rep;
//reg [`DISPATCH_WIDTH-1:0] pq_rd_dat;

assign queue_cnt[0] = i_queue_cnt[4:0];
assign queue_cnt[1] = i_queue_cnt[9:5];
assign queue_cnt[2] = i_queue_cnt[14:10];
assign queue_cnt[3] = i_queue_cnt[19:15];
assign queue_cnt[4] = i_queue_cnt[24:20];
assign queue_cnt[5] = i_queue_cnt[29:25];
assign queue_cnt[6] = i_queue_cnt[34:30];
assign queue_cnt[7] = i_queue_cnt[39:35];


always @(*) begin
    queue_weight_rep = (pq_sel == 'd0) ? queue_weight[0] :
                        (pq_sel == 'd1) ? queue_weight[1] :
                        (pq_sel == 'd2) ? queue_weight[2] :
                        (pq_sel == 'd3) ? queue_weight[3] :
                        (pq_sel == 'd4) ? queue_weight[4] :
                        (pq_sel == 'd5) ? queue_weight[5] :
                        (pq_sel == 'd6) ? queue_weight[6] : queue_weight[7];
end

assign o_pq_rd_en = pq_rd_en ? (8'd1 << pq_sel) : 'd0;

assign o_cache_en = cache_en;
// assign o_pq_rd_en = pq_rd_en;
assign o_pq_sel = pq_sel;

//SP strategy: strict priority
`ifdef SP_STRATEGY
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state <= 'd0;
        pq_sel <= 'd0;
        pq_rd_en <= 'd0;
        cache_en <= 1'b0;
    end
    else begin
        pq_sel <= pq_sel;
        pq_rd_en <= 'd0; //每次轮询初始不读
        cache_en <= 1'b0;
        case (state)
            'd0: begin //from high to low priority
                if (~i_pq_empty[0]) begin
                    pq_sel <= 'd0;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[1]) begin
                    pq_sel <= 'd1;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[2]) begin
                    pq_sel <= 'd2;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[3]) begin
                    pq_sel <= 'd3;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[4]) begin
                    pq_sel <= 'd4;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[5]) begin
                    pq_sel <= 'd5;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[6]) begin
                    pq_sel <= 'd6;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else if (~i_pq_empty[7]) begin
                    pq_sel <= 'd7;
                    pq_rd_en <= 1'b1; //拉高使能
                    state <= 'd1;
                end
                else begin
                    state <= 'd0; //考虑边界情况，如果8个优先级队列都是空的，则一直困在此状态
                end   
            end
            'd1: begin
                state <= 'd2;
            end 
            'd2: begin //调度数据
                cache_en <= 1'b1; //queue cache wr_en enable
                state <= 'd0;
            end
        endcase
    end
end

//权重轮询调度：WRR
`elsif WRR_STRATEGY
/*TODO*/
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state <= 'd0;
        pq_sel <= 'd0;
        pq_rd_en <= 'd0;
        cache_en <= 1'b0;
        queue_weight[0] <= 'd0;
        queue_weight[1] <= 'd0;
        queue_weight[2] <= 'd0;
        queue_weight[3] <= 'd0;
        queue_weight[4] <= 'd0;
        queue_weight[5] <= 'd0;
        queue_weight[6] <= 'd0;
        queue_weight[7] <= 'd0;
        RR <= 'd0;
    end
    else begin
        pq_sel <= pq_sel;
        pq_rd_en <= 1'b0; //每次轮询初始不读
        cache_en <= 1'b0;
        case (state)
            'd0: begin //from high to low priority
                /* 每一轮调度完更新一次权重 */
                queue_weight[0] <= queue_cnt[0];
                queue_weight[1] <= queue_cnt[1];
                queue_weight[2] <= queue_cnt[2];
                queue_weight[3] <= queue_cnt[3];
                queue_weight[4] <= queue_cnt[4];
                queue_weight[5] <= queue_cnt[5];
                queue_weight[6] <= queue_cnt[6];
                queue_weight[7] <= queue_cnt[7];
                RR <= RR;
                //state <= state;
                case (RR)
                //选择好哪一个队列
                    'd0: begin
                        if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                    'd1: begin
                        if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                    'd2: begin
                        if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                    'd3: begin
                        if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end   
                    'd4: begin
                        if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                    'd5: begin
                        if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                    'd6: begin
                        if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                    'd7: begin
                        if (~i_pq_empty[7]) begin
                            pq_sel <= 'd7;
                            //pq_rd_en[7] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[0]) begin
                            pq_sel <= 'd0;
                            //pq_rd_en[0] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[1]) begin
                            pq_sel <= 'd1;
                            //pq_rd_en[1] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[2]) begin
                            pq_sel <= 'd2;
                            //pq_rd_en[2] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[3]) begin
                            pq_sel <= 'd3;
                            //pq_rd_en[3] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[4]) begin
                            pq_sel <= 'd4;
                            //pq_rd_en[4] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else if (~i_pq_empty[5]) begin
                            pq_sel <= 'd5;
                            //pq_rd_en[5] <= 1'b1; //拉高使能
                            state <= 'd1;
                        end
                        else if (~i_pq_empty[6]) begin
                            pq_sel <= 'd6;
                            //pq_rd_en[6] <= 1'b1; //拉高使能
                            state <= 'd1;    
                        end
                        else begin
                            state <= 'd0; //考虑边界情况，如果8个fifo都是空的，则一直困在此状态
                        end
                    end
                endcase
            end
            'd1: begin
                pq_rd_en <= 1'b1; //读使能
                state <= 'd2;
            end 
            'd2: begin //一定是有数据
                cache_en <= 1'b1;
                pq_rd_en <= (queue_weight_rep == 'd1) ? 1'b0 : 1'b1;
                state <= 'd3;
            end
            'd3: begin //数据读取到
                queue_weight_rep <= queue_weight_rep - 1'b1;
                if (queue_weight_rep < 'd3) begin //when queue_weight_rep==2, we need to stop reading at next poseedge.
                    pq_rd_en <= 1'b0;
                    if (queue_weight_rep == 'd1) begin//if queue_weight_rep == 'd1, it means the data we gain is last one.
                        state <= 'd0;
                        cache_en <= 1'b0; 
                    end
                    else begin
                        state <= 'd4;
                        cache_en <= 1'b1; //也写入缓存
                    end
                end
                else begin
                    cache_en <= 1'b1; //也写入缓存
                    pq_rd_en <= 1'b1;
                    state <= 'd3;                    
                end
            end
            'd4: begin //最后一个数据
                //cache_en <= 1'b0; //也写入缓存
                state <= 'd0;
            end
        endcase
    end
end
`endif

endmodule