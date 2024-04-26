
import uvm_pkg::*;

class base_test extends uvm_test;
   my_env     env;

   `uvm_component_utils(base_test)
   
   function new(string name = "base_test", uvm_component parent = null);
      super.new(name,parent);
   endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env  =  my_env::type_id::create("env", this); 
    endfunction

    virtual task run_phase(uvm_phase phase);
        case0_sequence seq;

        // notify that run_phase has started
        // NOTE: simulation terminates once all objections are dropped
        phase.raise_objection(.obj(this));

        seq = case0_sequence::type_id::create("seq");
        seq.start(env.agt.sqr);

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase     
endclass
