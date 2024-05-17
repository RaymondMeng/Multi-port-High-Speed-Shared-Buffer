import uvm_pkg::*;

class base_test extends uvm_test;

   `uvm_component_utils(base_test)

   my_env     env;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env  =  my_env::type_id::create("env", this); 
    endfunction

    virtual task run_phase(uvm_phase phase);
        case0_sequence seq1;
        case0_sequence seq2;
        case0_sequence seq3;
        case0_sequence seq4;


        phase.raise_objection(.obj(this));
        fork
            begin
            seq1 = case0_sequence::type_id::create("seq1");
            seq1.start(env.agt1.sqr);
            end
            begin
            seq2 = case0_sequence::type_id::create("seq2");
            seq2.start(env.agt2.sqr);
            end
            begin
            seq3 = case0_sequence::type_id::create("seq3");
            seq3.start(env.agt3.sqr);
            end
            begin
            seq4 = case0_sequence::type_id::create("seq4");
            seq4.start(env.agt4.sqr);
            end
        join

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask    
endclass
