import uvm_pkg::*;

class my_agent_in extends uvm_agent;

   `uvm_component_utils(my_agent_in)

    uvm_analysis_port#(randdata) agent_compare_port[];
    uvm_analysis_export#(randdata) agent_in_export;

    uvm_tlm_analysis_fifo #(randdata) agent_in_fifo;

   my_sequencer         sqr;
   my_driver            drv;
   my_monitor_input     mon_in;
   randdata             rd_agtin;
   int port;
   int num_prior = 8;
   int num_port = 16;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction 
   
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent_in_export  = new("agent_in_export", this);
        agent_in_fifo    = new("agent_in_fifo", this);

        agent_compare_port = new[num_prior * num_port];
        for(int i = 0; i < num_prior * num_port; i++) begin
            agent_compare_port[i]  = new($sformatf("agent_compare_port_%0d", i), this);
        end

        rd_agtin    =   randdata::type_id::create("rd_agtin");
        sqr         =   my_sequencer::type_id::create("sqr", this);
        drv         =   my_driver::type_id::create("drv", this);
        mon_in      =   my_monitor_input::type_id::create("mon_in", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        drv.datain_collected_port.connect(mon_in.mon_input_export);
        mon_in.mon_compare_port.connect(agent_in_export);
        agent_in_export.connect(agent_in_fifo.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (agent_compare_port.size() == 0) begin
            `uvm_error("AGENT_IN_ERROR", "agent_compare_port array not properly initialized")
            return;
        end
        else begin
            `uvm_info("my_agent_in", "agent_compare_port initialization success", UVM_LOW)
            `uvm_info("my_agent_in", $sformatf("agent_compare_port size is %0d", agent_compare_port.size()), UVM_LOW)
        end

        forever begin
            rd_agtin    =   randdata::type_id::create("rd_agtin");
            port = 0;
            if (!rd_agtin.randomize()) begin
                `uvm_fatal("my_agent_input", "Randomization failed");
            end
            agent_in_fifo.get(rd_agtin);
            // `uvm_info("my_agent_in", rd_agtin.sprint(), UVM_LOW)
            port = rd_agtin.dest_port * 8 + rd_agtin.prior;
            agent_compare_port[port].write(rd_agtin);
            // `uvm_info("my_agent_in", $sformatf("write success, the port is %0d", port), UVM_LOW)
        end    
    endtask
endclass

class my_agent_out extends uvm_agent;

   `uvm_component_utils(my_agent_out)

    uvm_analysis_port#(randdata) agent_output_port;
    uvm_analysis_export#(randdata) agent_output_export;

    uvm_tlm_analysis_fifo #(randdata) agent_out_fifo;

    my_monitor_output    mon_out;
    randdata             rd_agtout;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction 
   
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent_output_port    = new("agent_output_port", this);
        agent_output_export  = new("agent_output_export", this);
        agent_out_fifo       = new("agent_out_fifo", this);

        mon_out   =   my_monitor_output::type_id::create("mon_out", this);
        rd_agtout =   randdata::type_id::create("rd_agtout");
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon_out.mon_output_port.connect(agent_output_export);
        agent_output_export.connect(agent_out_fifo.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            rd_agtout =   randdata::type_id::create("rd_agtout");
            if (!rd_agtout.randomize()) begin
                `uvm_fatal("my_agent_output", "Randomization failed");
            end
            agent_out_fifo.get(rd_agtout);
            // `uvm_info("my_agent_out", rd_agtout.sprint(), UVM_LOW)
            agent_output_port.write(rd_agtout);           
        end    
    endtask
endclass
