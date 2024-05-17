import uvm_pkg::*;

class my_env extends uvm_env;

   `uvm_component_utils(my_env)

   my_agent   agt1;
   my_agent   agt2;
   my_agent   agt3;
   my_agent   agt4;

   my_scoreboard sb1;
   my_scoreboard sb2;
   my_scoreboard sb3;
   my_scoreboard sb4;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agt1 = my_agent::type_id::create("agt1", this);
      agt2 = my_agent::type_id::create("agt2", this);
      agt3 = my_agent::type_id::create("agt3", this);
      agt4 = my_agent::type_id::create("agt4", this);
      sb1  = my_scoreboard::type_id::create("sb1", this);
      sb2  = my_scoreboard::type_id::create("sb2", this);
      sb3  = my_scoreboard::type_id::create("sb3", this);
      sb4  = my_scoreboard::type_id::create("sb4", this);
   endfunction

   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agt1.agent_output.connect(sb1.sb_export_output);
      agt1.agent_compare.connect(sb1.sb_export_compare);
      agt2.agent_output.connect(sb2.sb_export_output);
      agt2.agent_compare.connect(sb2.sb_export_compare);
      agt3.agent_output.connect(sb3.sb_export_output);
      agt3.agent_compare.connect(sb3.sb_export_compare);
      agt4.agent_output.connect(sb4.sb_export_output);
      agt4.agent_compare.connect(sb4.sb_export_compare);
   endfunction
endclass
