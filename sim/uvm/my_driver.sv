import uvm_pkg::*;

class my_driver extends uvm_driver#(randdata); 

   `uvm_component_utils(my_driver)

    uvm_analysis_port#(randdata) datain_collected_port;

    virtual port_interface port;

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
        while(1) begin
            drive_transaction();
        end
    endtask

    virtual task drive_transaction();
        int i;
        randdata rd;

        @(posedge port.clk) begin
            i = 0;
            port.wr_sop = 0;
            port.wr_eop = 0;
            port.wr_vld = 0;
            port.wr_data = 64'dz;
            port.write_done = 0;
        end

        @(posedge port.clk) begin
            port.wr_sop = 1'b1;
        end

        @(posedge port.clk) begin
            port.wr_sop = 1'b0;
            seq_item_port.get_next_item(rd);
            `uvm_info("my_driver", "start writing", UVM_LOW);
            while ( i <= rd.length / 64 ) begin
                if (port.full == 1'b0) begin
                    port.wr_vld = 1'b1;
                    port.wr_data = rd.data[i];
                    $display("data: %h", port.wr_data);                
                    end
                else begin
                    port.wr_vld = 1'b0;
                end
                i++;
                @(posedge port.clk);
            end
            $display("length: %0d, len_sod: %h, len_data: %h", rd.length, rd.sod[17:7], rd.data[0][17:7]);
            $display("prior: %h, prior_sod: %h, prior_data: %h", rd.prior, rd.sod[6:4], rd.data[0][6:4]);
            $display("port: %0d, port_sod: %h, port_data: %h", rd.dest_port, rd.sod[3:0], rd.data[0][3:0]);
            datain_collected_port.write(rd);
            seq_item_port.item_done();
        end

        @(posedge port.clk) begin
            port.wr_vld = 1'b0;
            port.wr_eop = 1'b1;
        end
        @(posedge port.clk) begin
            port.wr_eop = 1'b0;
            port.write_done = 1'b1;
        end
        `uvm_info("my_driver", "end write one pkt", UVM_LOW);
    endtask
endclass