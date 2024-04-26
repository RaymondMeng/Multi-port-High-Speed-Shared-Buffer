import uvm_pkg::*;

class my_driver extends uvm_driver#(randdata); 

   virtual port_interface port;

   `uvm_component_utils(my_driver)

   function new(string name = "my_driver", uvm_component parent = null); 
      super.new(name, parent); 
   endfunction

   virtual function void build_phase(uvm_phase phase); 
      super.build_phase(phase);
      if(!uvm_config_db#(virtual port_interface)::get(this, "", "port", port))
         `uvm_fatal("my_driver", "virtual interface must be set for port!!!")
   endfunction

    virtual task run_phase(uvm_phase phase);
        repeat(15) begin
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
            $display("start writing");
            while ( i <= rd.length / 64 ) begin
                if (port.full == 1'b0) begin
                    port.wr_vld = 1'b1;
                    port.wr_data = rd.data[i];
                    $display("rddata:%h", rd.data[i]);                   
                    end
                else begin
                    port.wr_vld = 1'b0;
                    // port.wr_data = rd.data[i];
                    $display("222");
                end
                i++;
                @(posedge port.clk);
            end
            $display("length: %0d, len_sod: %h, len_data: %h", rd.length, rd.sod[17:7], rd.data[0][17:7]);
            $display("prior: %h, prior_sod: %h, prior_data: %h", rd.prior, rd.sod[6:4], rd.data[0][6:4]);
            $display("port: %0d, port_sod: %h, port_data: %h", rd.dest_port, rd.sod[3:0], rd.data[0][3:0]);
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
        `uvm_info("my_driver", "end drive one pkt", UVM_LOW);
    endtask
endclass