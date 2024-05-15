import uvm_pkg::*;


// Reads data from output fifo to scoreboard
class my_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_monitor_output)

    uvm_analysis_port#(randdata) mon_output;

    virtual port_interface port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_output = new("mon_output", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual port_interface)::get(this, "", "port", port))
            `uvm_fatal("my_monitor", "virtual interface must be set for port!!!")
    endfunction

    virtual task run_phase(uvm_phase phase);

        randdata rd_out;
        int i;
        logic [10:0] len;


        // wait for reset
        @(posedge port.clk) begin
            rd_out = randdata::type_id::create("rd_out");
        end
        @(posedge port.clk) begin
            port.rdy = 1'b1;
        end

        forever begin
            @(negedge port.rd_sop) begin
                i = 0;
                len = port.rd_data[17:7];
                rd_out.data_c.constraint_mode(0);
                if (!(rd_out.randomize() with 
                    {length == len;
                    if (length % 64 == 0)
                        data.size() == ((length / 64));
                    else data.size() == ((length / 64) + 1);})) begin
                        `uvm_fatal("my_monitor_output", "Randomization failed");
                end 
                while(!port.rd_eop) begin
                    @(negedge port.clk) begin
                        port.rd_vld = 1'b1;
                        rd_out.data[i] = port.rd_data;
                        i++;
                    end
                end
                rd_out.dest_port = rd_out.data[0][3:0];
                rd_out.prior = rd_out.data[0][6:4];
                rd_out.length = rd_out.data[0][17:7];
                rd_out.sod = rd_out.data[0][17:0];
                mon_output.write(rd_out);
                port.rd_vld = 1'b0;
            end
        end
    endtask
endclass


// Reads data from compare file to scoreboard
class my_monitor_input extends uvm_monitor;

    `uvm_component_utils(my_monitor_input)

    uvm_analysis_export#(randdata)      mon_input;
    uvm_analysis_port#(randdata)        mon_compare;

    uvm_tlm_analysis_fifo #(randdata)   input_fifo;

    virtual port_interface port;
    randdata rd_compare;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_input   = new("mon_input", this);
        mon_compare = new("mon_compare", this);
        input_fifo  = new("input_fifo", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual port_interface)::get(this, "", "port", port))
            `uvm_fatal("my_monitor", "virtual interface must be set for port!!!")
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        mon_input.connect(input_fifo.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);

        // wait for reset
        @(posedge port.clk) begin
            rd_compare = randdata::type_id::create("rd_compare");
        end

        forever begin
            @(negedge port.rd_sop) begin
                if (!rd_compare.randomize()) begin
                    `uvm_fatal("my_monitor_input", "Randomization failed");
                end     
                input_fifo.get(rd_compare);
                mon_compare.write(rd_compare);
            end
        end      
    endtask
endclass
