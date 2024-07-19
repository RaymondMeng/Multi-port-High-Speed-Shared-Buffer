import uvm_pkg::*;

class my_driver extends uvm_driver#(randdata); 

   `uvm_component_utils(my_driver)

    uvm_analysis_port#(randdata) datain_collected_port;

    virtual port_interface port;
    // int i, buff_lenth;

    function new(string name, uvm_component parent); 
        super.new(name, parent); 
    endfunction

    virtual function void build_phase(uvm_phase phase); 
        super.build_phase(phase);
        if(!uvm_config_db#(virtual port_interface)::get(this, "", "port", port))
            `uvm_fatal("my_driver", "virtual interface must be set for port!!!")

        datain_collected_port = new("datain_collected_port", this);   
    endfunction

    virtual task run_phase(uvm_phase phase);
        // #30000;
        // i = 0;
        // buff_lenth = 0;
        // port.wr_sop = 0;
        // port.wr_eop = 0;
        // port.wr_vld = 0;
        // port.wr_data = 64'd0;
        while(1) begin
            drive_transaction();
        end
    endtask

    virtual task drive_transaction();
        randdata rd;
        int i;
        int buff_lenth;

        if (port.full == 1) begin
            @(negedge port.full) begin
                i = 0;
                buff_lenth = 0;
                port.wr_sop = 0;
                port.wr_eop = 0;
                port.wr_vld = 0;
                port.wr_data = 64'd0;
            end
        end

        @(posedge port.clk) begin
            port.wr_sop = 1'b1;
        end

        @(posedge port.clk) begin
            port.wr_sop = 1'b0;
            seq_item_port.get_next_item(rd);
            // `uvm_info("driver", rd.sprint(), UVM_LOW)
            // if((rd.length*8) % 128 === 0) begin
            //     buff_lenth = (((rd.length*8) / 128)*2 + 2); 
            // end
            // else begin
            //     buff_lenth = (((rd.length*8) / 128 + 1)*2 + 2);
            // end
            while ( i < (((rd.length*8) / 128 + 1)*2 + 2)) begin
                if (port.full == 1'b0) begin
                    if(rd.data[i] === 64'dx) begin
                        port.wr_vld = 1'b0;
                        break;  
                    end
                    else begin
                        port.wr_vld = 1'b1;
                        // $display("origin data is %h", rd.data[i]);
                        port.wr_data = rd.data[i];
                        // $display("write data is %h", port.wr_data);      
                    end               
                end
                else begin
                    port.wr_vld = 1'b0;
                end
                i++;
                @(posedge port.clk);
            end
            datain_collected_port.write(rd);
            seq_item_port.item_done();
        end

        port.wr_vld = 1'b0;
        port.wr_eop = 1'b1;

        @(posedge port.clk) begin
            port.wr_eop = 1'b0;
            i = 0;
            buff_lenth = 0;
        end
    endtask
endclass