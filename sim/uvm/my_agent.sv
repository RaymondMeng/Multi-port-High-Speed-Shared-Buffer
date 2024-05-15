import uvm_pkg::*;

class my_agent extends uvm_agent;

   `uvm_component_utils(my_agent)

    uvm_analysis_port#(randdata) agent_output;
    uvm_analysis_port#(randdata) agent_compare;

   my_sequencer         sqr;
   my_driver            drv;
   my_monitor_output    mon_out;
   my_monitor_input     mon_in;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction 
   
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent_output  = new("agent_output", this);
        agent_compare = new("agent_compare",  this);

        sqr     =   my_sequencer::type_id::create("sqr", this);
        drv     =   my_driver::type_id::create("drv", this);
        mon_out =   my_monitor_output::type_id::create("mon_out", this);
        mon_in  =   my_monitor_input::type_id::create("mon_in", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        drv.datain_collected_port.connect(mon_in.mon_input);
        mon_out.mon_output.connect(agent_output);
        mon_in.mon_compare.connect(agent_compare);
    endfunction
endclass
