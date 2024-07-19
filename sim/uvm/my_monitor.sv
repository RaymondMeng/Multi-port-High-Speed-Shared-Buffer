import uvm_pkg::*;


//从DUT中读取数据
class my_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_monitor_output)

    uvm_analysis_port#(randdata) mon_output_port;

    virtual port_interface port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual port_interface)::get(this, "", "port", port))
            `uvm_fatal("my_monitor", "virtual interface must be set for port!!!")
        mon_output_port = new("mon_output_port", this);
    endfunction

    virtual task run_phase(uvm_phase phase);

        randdata rd_out;
        int i;
        logic [10:0] len;

        
        // wait for reset
        @(posedge port.clk) begin
            port.rd_rdy = 1'b1;
            rd_out = randdata::type_id::create("rd_out");
        end
        

        forever begin
            @(negedge port.rd_sop) begin
                rd_out = randdata::type_id::create("rd_out");
                @(negedge port.clk);
                @(negedge port.clk) begin
                    i = 2;
                    len = port.rd_data[17:7];
                    // `uvm_info("my_monitor_output", $sformatf("output data sod is: %h", port.rd_data), UVM_LOW)
                    // `uvm_info("my_monitor_output", $sformatf("output data length is: %d", len), UVM_LOW)
                    if($isunknown(len)) begin
                        len = 2048;
                    end
                    rd_out.data_c.constraint_mode(0);
                    if (!(rd_out.randomize() with 
                        {length == len;
                        if ((length*8) % 128 == 0)
                            data.size() == (((length*8) / 128)*2 + 2);
                        else data.size() == (((length*8) / 128 + 1)*2 + 2);})) begin
                            `uvm_fatal("my_monitor_output", "Randomization failed");
                    end
                    // if (!(rd_out.randomize() with {length == len;})) begin
                    //     `uvm_fatal("my_monitor_output", "Randomization failed");
                    // end
                    rd_out.data[0] = 64'b0;
                    rd_out.data[1] = port.rd_data;  
                end
                while(!port.rd_eop) begin
                    @(negedge port.clk) begin
                        if(port.rd_vld) begin
                            rd_out.data[i] = port.rd_data;
                            i++;
                        end
                    end
                end
                rd_out.dest_port    = rd_out.data[1][3:0];
                rd_out.prior        = rd_out.data[1][6:4];
                rd_out.length       = rd_out.data[1][17:7];
                rd_out.in_port      = rd_out.data[1][21:18];
                rd_out.sod          = rd_out.data[1][21:0];
                mon_output_port.write(rd_out);
            end
        end
    endtask
endclass


//从driver中读取数据
class my_monitor_input extends uvm_monitor;

    `uvm_component_utils(my_monitor_input)

    uvm_analysis_export#(randdata)      mon_input_export;
    uvm_analysis_port#(randdata)        mon_compare_port;

    uvm_tlm_analysis_fifo #(randdata)   mon_input_fifo;

    virtual port_interface port;
    randdata rd_compare;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual port_interface)::get(this, "", "port", port))
            `uvm_fatal("my_monitor", "virtual interface must be set for port!!!")

        mon_input_export    = new("mon_input_export", this);
        mon_input_fifo      = new("mon_input_fifo", this);
        mon_compare_port    = new("mon_compare_port", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon_input_export.connect(mon_input_fifo.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // wait for reset
        // @(posedge port.clk) begin
        //     rd_compare = randdata::type_id::create("rd_compare");
        // end

        forever begin
            @(negedge port.wr_eop) begin
                rd_compare = randdata::type_id::create("rd_compare");
                if (!rd_compare.randomize()) begin
                    `uvm_fatal("my_monitor_input", "Randomization failed");
                end   
                mon_input_fifo.get(rd_compare);
                mon_compare_port.write(rd_compare);
            end
        end      
    endtask
endclass
