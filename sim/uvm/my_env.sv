import uvm_pkg::*;

class my_env extends uvm_env;
   my_agent   agt;

    `uvm_component_utils(my_env)
   
   function new(string name = "my_env", uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agt = my_agent::type_id::create("agt", this);
   endfunction
endclass
