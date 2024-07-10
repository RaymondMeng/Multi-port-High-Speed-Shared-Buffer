import uvm_pkg::*;

class my_env extends uvm_env;

   `uvm_component_utils(my_env)

   my_agent   agt1;
   // my_agent   agt2;
   // my_agent   agt3;
   // my_agent   agt4;

   my_scoreboard sb;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agt1 = my_agent::type_id::create("agt1", this);
      // agt2 = my_agent::type_id::create("agt2", this);
      // agt3 = my_agent::type_id::create("agt3", this);
      // agt4 = my_agent::type_id::create("agt4", this);
      sb   = my_scoreboard::type_id::create("sb", this);
   endfunction

   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agt1.agent_output.connect(sb.sb_export_output);
      agt1.agent_compare.connect(sb.sb_export_compare);
   endfunction
endclass
