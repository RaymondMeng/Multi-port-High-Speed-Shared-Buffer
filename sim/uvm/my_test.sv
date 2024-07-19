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
        case0_sequence seq0;
        case1_sequence seq1;
        case2_sequence seq2;
        case3_sequence seq3;
        case4_sequence seq4;
        case5_sequence seq5;
        case6_sequence seq6;
        case7_sequence seq7;
        case8_sequence seq8;
        case9_sequence seq9;
        case10_sequence seq10;
        case11_sequence seq11;
        case12_sequence seq12;
        case13_sequence seq13;
        case14_sequence seq14;
        case15_sequence seq15;


        phase.raise_objection(.obj(this));
        fork
            begin
            seq0 = case0_sequence::type_id::create("seq0");
            seq0.start(env.agt_in0.sqr);
            end
            begin
            seq1 = case1_sequence::type_id::create("seq1");
            seq1.start(env.agt_in1.sqr);
            end
            begin
            seq2 = case2_sequence::type_id::create("seq2");
            seq2.start(env.agt_in2.sqr);
            end
            begin
            seq3 = case3_sequence::type_id::create("seq3");
            seq3.start(env.agt_in3.sqr);
            end
            begin
            seq4 = case4_sequence::type_id::create("seq4");
            seq4.start(env.agt_in4.sqr);
            end
            begin
            seq5 = case5_sequence::type_id::create("seq5");
            seq5.start(env.agt_in5.sqr);
            end
            begin
            seq6 = case6_sequence::type_id::create("seq6");
            seq6.start(env.agt_in6.sqr);
            end
            begin
            seq7 = case7_sequence::type_id::create("seq7");
            seq7.start(env.agt_in7.sqr);
            end
            begin
            seq8 = case8_sequence::type_id::create("seq8");
            seq8.start(env.agt_in8.sqr);
            end
            begin
            seq9 = case9_sequence::type_id::create("seq9");
            seq9.start(env.agt_in9.sqr);
            end
            begin
            seq10 = case10_sequence::type_id::create("seq10");
            seq10.start(env.agt_in10.sqr);
            end
            begin
            seq11 = case11_sequence::type_id::create("seq11");
            seq11.start(env.agt_in11.sqr);
            end
            begin
            seq12 = case12_sequence::type_id::create("seq12");
            seq12.start(env.agt_in12.sqr);
            end
            begin
            seq13 = case13_sequence::type_id::create("seq13");
            seq13.start(env.agt_in13.sqr);
            end
            begin
            seq14 = case14_sequence::type_id::create("seq14");
            seq14.start(env.agt_in14.sqr);
            end
            begin
            seq15 = case15_sequence::type_id::create("seq15");
            seq15.start(env.agt_in15.sqr);
            end
        join

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask    
endclass
