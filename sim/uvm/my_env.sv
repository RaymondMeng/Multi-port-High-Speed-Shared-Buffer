import uvm_pkg::*;

class my_env extends uvm_env;

   `uvm_component_utils(my_env)

   my_agent_in    agt_in0;
   my_agent_in    agt_in1;
   my_agent_in    agt_in2;
   my_agent_in    agt_in3;
   my_agent_in    agt_in4;
   my_agent_in    agt_in5;
   my_agent_in    agt_in6;
   my_agent_in    agt_in7;
   my_agent_in    agt_in8;
   my_agent_in    agt_in9;
   my_agent_in    agt_in10;
   my_agent_in    agt_in11;
   my_agent_in    agt_in12;
   my_agent_in    agt_in13;
   my_agent_in    agt_in14;
   my_agent_in    agt_in15;

   my_agent_out    agt_out0;
   my_agent_out    agt_out1;
   my_agent_out    agt_out2;
   my_agent_out    agt_out3;
   my_agent_out    agt_out4;
   my_agent_out    agt_out5;
   my_agent_out    agt_out6;
   my_agent_out    agt_out7;
   my_agent_out    agt_out8;
   my_agent_out    agt_out9;
   my_agent_out    agt_out10;
   my_agent_out    agt_out11;
   my_agent_out    agt_out12;
   my_agent_out    agt_out13;
   my_agent_out    agt_out14;
   my_agent_out    agt_out15;

   my_scoreboard  sb0;
   my_scoreboard  sb1;
   my_scoreboard  sb2;
   my_scoreboard  sb3;
   my_scoreboard  sb4;
   my_scoreboard  sb5;
   my_scoreboard  sb6;
   my_scoreboard  sb7;
   my_scoreboard  sb8;
   my_scoreboard  sb9;
   my_scoreboard  sb10;
   my_scoreboard  sb11;
   my_scoreboard  sb12;
   my_scoreboard  sb13;
   my_scoreboard  sb14;
   my_scoreboard  sb15;
   
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agt_in0  = my_agent_in::type_id::create("agt_in0", this);
      agt_in1  = my_agent_in::type_id::create("agt_in1", this);
      agt_in2  = my_agent_in::type_id::create("agt_in2", this);
      agt_in3  = my_agent_in::type_id::create("agt_in3", this);
      agt_in4  = my_agent_in::type_id::create("agt_in4", this);
      agt_in5  = my_agent_in::type_id::create("agt_in5", this);
      agt_in6  = my_agent_in::type_id::create("agt_in6", this);
      agt_in7  = my_agent_in::type_id::create("agt_in7", this);
      agt_in8  = my_agent_in::type_id::create("agt_in8", this);
      agt_in9  = my_agent_in::type_id::create("agt_in9", this);
      agt_in10 = my_agent_in::type_id::create("agt_in10", this);
      agt_in11 = my_agent_in::type_id::create("agt_in11", this);
      agt_in12 = my_agent_in::type_id::create("agt_in12", this);
      agt_in13 = my_agent_in::type_id::create("agt_in13", this);
      agt_in14 = my_agent_in::type_id::create("agt_in14", this);
      agt_in15 = my_agent_in::type_id::create("agt_in15", this);

      agt_out0  = my_agent_out::type_id::create("agt_out0", this);
      agt_out1  = my_agent_out::type_id::create("agt_out1", this);
      agt_out2  = my_agent_out::type_id::create("agt_out2", this);
      agt_out3  = my_agent_out::type_id::create("agt_out3", this);
      agt_out4  = my_agent_out::type_id::create("agt_out4", this);
      agt_out5  = my_agent_out::type_id::create("agt_out5", this);
      agt_out6  = my_agent_out::type_id::create("agt_out6", this);
      agt_out7  = my_agent_out::type_id::create("agt_out7", this);
      agt_out8  = my_agent_out::type_id::create("agt_out8", this);
      agt_out9  = my_agent_out::type_id::create("agt_out9", this);
      agt_out10 = my_agent_out::type_id::create("agt_out10", this);
      agt_out11 = my_agent_out::type_id::create("agt_out11", this);
      agt_out12 = my_agent_out::type_id::create("agt_out12", this);
      agt_out13 = my_agent_out::type_id::create("agt_out13", this);
      agt_out14 = my_agent_out::type_id::create("agt_out14", this);
      agt_out15 = my_agent_out::type_id::create("agt_out15", this);

      sb0   = my_scoreboard::type_id::create("sb0", this);
      sb1   = my_scoreboard::type_id::create("sb1", this);
      sb2   = my_scoreboard::type_id::create("sb2", this);
      sb3   = my_scoreboard::type_id::create("sb3", this);
      sb4   = my_scoreboard::type_id::create("sb4", this);
      sb5   = my_scoreboard::type_id::create("sb5", this);
      sb6   = my_scoreboard::type_id::create("sb6", this);
      sb7   = my_scoreboard::type_id::create("sb7", this);
      sb8   = my_scoreboard::type_id::create("sb8", this);
      sb9   = my_scoreboard::type_id::create("sb9", this);
      sb10  = my_scoreboard::type_id::create("sb10", this);
      sb11  = my_scoreboard::type_id::create("sb11", this);
      sb12  = my_scoreboard::type_id::create("sb12", this);
      sb13  = my_scoreboard::type_id::create("sb13", this);
      sb14  = my_scoreboard::type_id::create("sb14", this);
      sb15  = my_scoreboard::type_id::create("sb15", this);

   endfunction

   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      for(int i = 0; i< 8; i++) begin
         agt_in0.agent_compare_port[i].connect(sb0.sb_imp_compare[i]);
         agt_in1.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 8]);
         agt_in2.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 16]);
         agt_in3.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 24]);
         agt_in4.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 32]);
         agt_in5.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 40]);
         agt_in6.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 48]);
         agt_in7.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 56]);
         agt_in8.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 64]);
         agt_in9.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 72]);
         agt_in10.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 80]);
         agt_in11.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 88]);
         agt_in12.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 96]);
         agt_in13.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 104]);
         agt_in14.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 112]);
         agt_in15.agent_compare_port[i].connect(sb0.sb_imp_compare[i + 120]);
      end
      for(int i = 8; i< 16; i++) begin
         agt_in0.agent_compare_port[i].connect(sb1.sb_imp_compare[i - 8]);
         agt_in1.agent_compare_port[i].connect(sb1.sb_imp_compare[i]);
         agt_in2.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 8]);
         agt_in3.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 16]);
         agt_in4.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 24]);
         agt_in5.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 32]);
         agt_in6.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 40]);
         agt_in7.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 48]);
         agt_in8.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 56]);
         agt_in9.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 64]);
         agt_in10.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 72]);
         agt_in11.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 80]);
         agt_in12.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 88]);
         agt_in13.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 96]);
         agt_in14.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 104]);
         agt_in15.agent_compare_port[i].connect(sb1.sb_imp_compare[i + 112]);
      end
      for(int i = 16; i< 24; i++) begin
         agt_in0.agent_compare_port[i].connect(sb2.sb_imp_compare[i - 16]);
         agt_in1.agent_compare_port[i].connect(sb2.sb_imp_compare[i - 8]);
         agt_in2.agent_compare_port[i].connect(sb2.sb_imp_compare[i]);
         agt_in3.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 8]);
         agt_in4.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 16]);
         agt_in5.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 24]);
         agt_in6.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 32]);
         agt_in7.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 40]);
         agt_in8.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 48]);
         agt_in9.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 56]);
         agt_in10.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 64]);
         agt_in11.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 72]);
         agt_in12.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 80]);
         agt_in13.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 88]);
         agt_in14.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 96]);
         agt_in15.agent_compare_port[i].connect(sb2.sb_imp_compare[i + 104]);
      end
      for(int i = 24; i< 32; i++) begin
         agt_in0.agent_compare_port[i].connect(sb3.sb_imp_compare[i - 24]);
         agt_in1.agent_compare_port[i].connect(sb3.sb_imp_compare[i - 16]);
         agt_in2.agent_compare_port[i].connect(sb3.sb_imp_compare[i - 8]);
         agt_in3.agent_compare_port[i].connect(sb3.sb_imp_compare[i]);
         agt_in4.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 8]);
         agt_in5.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 16]);
         agt_in6.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 24]);
         agt_in7.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 32]);
         agt_in8.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 40]);
         agt_in9.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 48]);
         agt_in10.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 56]);
         agt_in11.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 64]);
         agt_in12.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 72]);
         agt_in13.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 80]);
         agt_in14.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 88]);
         agt_in15.agent_compare_port[i].connect(sb3.sb_imp_compare[i + 96]);
      end
      for(int i = 32; i< 40; i++) begin
         agt_in0.agent_compare_port[i].connect(sb4.sb_imp_compare[i - 32]);
         agt_in1.agent_compare_port[i].connect(sb4.sb_imp_compare[i - 24]);
         agt_in2.agent_compare_port[i].connect(sb4.sb_imp_compare[i - 16]);
         agt_in3.agent_compare_port[i].connect(sb4.sb_imp_compare[i - 8]);
         agt_in4.agent_compare_port[i].connect(sb4.sb_imp_compare[i]);
         agt_in5.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 8]);
         agt_in6.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 16]);
         agt_in7.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 24]);
         agt_in8.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 32]);
         agt_in9.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 40]);
         agt_in10.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 48]);
         agt_in11.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 56]);
         agt_in12.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 64]);
         agt_in13.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 72]);
         agt_in14.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 80]);
         agt_in15.agent_compare_port[i].connect(sb4.sb_imp_compare[i + 88]); 
      end
      for(int i = 40; i< 48; i++) begin
         agt_in0.agent_compare_port[i].connect(sb5.sb_imp_compare[i - 40]);
         agt_in1.agent_compare_port[i].connect(sb5.sb_imp_compare[i - 32]);
         agt_in2.agent_compare_port[i].connect(sb5.sb_imp_compare[i - 24]);
         agt_in3.agent_compare_port[i].connect(sb5.sb_imp_compare[i - 16]);
         agt_in4.agent_compare_port[i].connect(sb5.sb_imp_compare[i - 8]);
         agt_in5.agent_compare_port[i].connect(sb5.sb_imp_compare[i]);
         agt_in6.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 8]);
         agt_in7.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 16]);
         agt_in8.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 24]);
         agt_in9.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 32]);
         agt_in10.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 40]);
         agt_in11.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 48]);
         agt_in12.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 56]);
         agt_in13.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 64]);
         agt_in14.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 72]);
         agt_in15.agent_compare_port[i].connect(sb5.sb_imp_compare[i + 80]);
      end
      for(int i = 48; i< 56; i++) begin
         agt_in0.agent_compare_port[i].connect(sb6.sb_imp_compare[i - 48]);
         agt_in1.agent_compare_port[i].connect(sb6.sb_imp_compare[i - 40]);
         agt_in2.agent_compare_port[i].connect(sb6.sb_imp_compare[i - 32]);
         agt_in3.agent_compare_port[i].connect(sb6.sb_imp_compare[i - 24]);
         agt_in4.agent_compare_port[i].connect(sb6.sb_imp_compare[i - 16]);
         agt_in5.agent_compare_port[i].connect(sb6.sb_imp_compare[i - 8]);
         agt_in6.agent_compare_port[i].connect(sb6.sb_imp_compare[i]);
         agt_in7.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 8]);
         agt_in8.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 16]);
         agt_in9.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 24]);
         agt_in10.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 32]);
         agt_in11.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 40]);
         agt_in12.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 48]);
         agt_in13.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 56]);
         agt_in14.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 64]);
         agt_in15.agent_compare_port[i].connect(sb6.sb_imp_compare[i + 72]);
      end
      for(int i = 56; i< 64; i++) begin
         agt_in0.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 56]);
         agt_in1.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 48]);
         agt_in2.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 40]);
         agt_in3.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 32]);
         agt_in4.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 24]);
         agt_in5.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 16]);
         agt_in6.agent_compare_port[i].connect(sb7.sb_imp_compare[i - 8]);
         agt_in7.agent_compare_port[i].connect(sb7.sb_imp_compare[i]);
         agt_in8.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 8]);
         agt_in9.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 16]);
         agt_in10.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 24]);
         agt_in11.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 32]);
         agt_in12.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 40]);
         agt_in13.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 48]);
         agt_in14.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 56]);
         agt_in15.agent_compare_port[i].connect(sb7.sb_imp_compare[i + 64]);
      end
      for(int i = 64; i< 72; i++) begin
         agt_in0.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 64]);
         agt_in1.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 56]);
         agt_in2.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 48]);
         agt_in3.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 40]);
         agt_in4.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 32]);
         agt_in5.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 24]);
         agt_in6.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 16]);
         agt_in7.agent_compare_port[i].connect(sb8.sb_imp_compare[i - 8]);
         agt_in8.agent_compare_port[i].connect(sb8.sb_imp_compare[i]);
         agt_in9.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 8]);
         agt_in10.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 16]);
         agt_in11.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 24]);
         agt_in12.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 32]);
         agt_in13.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 40]);
         agt_in14.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 48]);
         agt_in15.agent_compare_port[i].connect(sb8.sb_imp_compare[i + 56]);
      end
      for(int i = 72; i< 80; i++) begin
         agt_in0.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 72]);
         agt_in1.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 64]);
         agt_in2.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 56]);
         agt_in3.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 48]);
         agt_in4.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 40]);
         agt_in5.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 32]);
         agt_in6.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 24]);
         agt_in7.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 16]);
         agt_in8.agent_compare_port[i].connect(sb9.sb_imp_compare[i - 8]);
         agt_in9.agent_compare_port[i].connect(sb9.sb_imp_compare[i]);
         agt_in10.agent_compare_port[i].connect(sb9.sb_imp_compare[i + 8]);
         agt_in11.agent_compare_port[i].connect(sb9.sb_imp_compare[i + 16]);
         agt_in12.agent_compare_port[i].connect(sb9.sb_imp_compare[i + 24]);
         agt_in13.agent_compare_port[i].connect(sb9.sb_imp_compare[i + 32]);
         agt_in14.agent_compare_port[i].connect(sb9.sb_imp_compare[i + 40]);
         agt_in15.agent_compare_port[i].connect(sb9.sb_imp_compare[i + 48]);
      end
      for(int i = 80; i< 88; i++) begin
         agt_in0.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 80]);
         agt_in1.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 72]);
         agt_in2.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 64]);
         agt_in3.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 56]);
         agt_in4.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 48]);
         agt_in5.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 40]);
         agt_in6.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 32]);
         agt_in7.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 24]);
         agt_in8.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 16]);
         agt_in9.agent_compare_port[i].connect(sb10.sb_imp_compare[i - 8]);
         agt_in10.agent_compare_port[i].connect(sb10.sb_imp_compare[i]);
         agt_in11.agent_compare_port[i].connect(sb10.sb_imp_compare[i + 8]);
         agt_in12.agent_compare_port[i].connect(sb10.sb_imp_compare[i + 16]);
         agt_in13.agent_compare_port[i].connect(sb10.sb_imp_compare[i + 24]);
         agt_in14.agent_compare_port[i].connect(sb10.sb_imp_compare[i + 32]);
         agt_in15.agent_compare_port[i].connect(sb10.sb_imp_compare[i + 40]);
      end
      for(int i = 88; i< 96; i++) begin
         agt_in0.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 88]);
         agt_in1.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 80]);
         agt_in2.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 72]);
         agt_in3.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 64]);
         agt_in4.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 56]);
         agt_in5.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 48]);
         agt_in6.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 40]);
         agt_in7.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 32]);
         agt_in8.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 24]);
         agt_in9.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 16]);
         agt_in10.agent_compare_port[i].connect(sb11.sb_imp_compare[i - 8]);
         agt_in11.agent_compare_port[i].connect(sb11.sb_imp_compare[i]);
         agt_in12.agent_compare_port[i].connect(sb11.sb_imp_compare[i + 8]);
         agt_in13.agent_compare_port[i].connect(sb11.sb_imp_compare[i + 16]);
         agt_in14.agent_compare_port[i].connect(sb11.sb_imp_compare[i + 24]);
         agt_in15.agent_compare_port[i].connect(sb11.sb_imp_compare[i + 32]);
      end
      for(int i = 96; i< 104; i++) begin
         agt_in0.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 96]);
         agt_in1.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 88]);
         agt_in2.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 80]);
         agt_in3.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 72]);
         agt_in4.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 64]);
         agt_in5.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 56]);
         agt_in6.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 48]);
         agt_in7.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 40]);
         agt_in8.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 32]);
         agt_in9.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 24]);
         agt_in10.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 16]);
         agt_in11.agent_compare_port[i].connect(sb12.sb_imp_compare[i - 8]);
         agt_in12.agent_compare_port[i].connect(sb12.sb_imp_compare[i]);
         agt_in13.agent_compare_port[i].connect(sb12.sb_imp_compare[i + 8]);
         agt_in14.agent_compare_port[i].connect(sb12.sb_imp_compare[i + 16]);
         agt_in15.agent_compare_port[i].connect(sb12.sb_imp_compare[i + 24]);
      end
      for(int i = 104; i< 112; i++) begin
         agt_in0.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 104]);
         agt_in1.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 96]);
         agt_in2.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 88]);
         agt_in3.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 80]);
         agt_in4.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 72]);
         agt_in5.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 64]);
         agt_in6.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 56]);
         agt_in7.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 48]);
         agt_in8.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 40]);
         agt_in9.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 32]);
         agt_in10.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 24]);
         agt_in11.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 16]);
         agt_in12.agent_compare_port[i].connect(sb13.sb_imp_compare[i - 8]);
         agt_in13.agent_compare_port[i].connect(sb13.sb_imp_compare[i]);
         agt_in14.agent_compare_port[i].connect(sb13.sb_imp_compare[i + 8]);
         agt_in15.agent_compare_port[i].connect(sb13.sb_imp_compare[i + 16]);
      end
      for(int i = 112; i< 120; i++) begin
         agt_in0.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 112]);
         agt_in1.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 104]);
         agt_in2.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 96]);
         agt_in3.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 88]);
         agt_in4.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 80]);
         agt_in5.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 72]);
         agt_in6.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 64]);
         agt_in7.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 56]);
         agt_in8.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 48]);
         agt_in9.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 40]);
         agt_in10.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 32]);
         agt_in11.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 24]);
         agt_in12.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 16]);
         agt_in13.agent_compare_port[i].connect(sb14.sb_imp_compare[i - 8]);
         agt_in14.agent_compare_port[i].connect(sb14.sb_imp_compare[i]);
         agt_in15.agent_compare_port[i].connect(sb14.sb_imp_compare[i + 8]);
      end
      for(int i = 120; i< 128; i++) begin
         agt_in0.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 120]);
         agt_in1.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 112]);
         agt_in2.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 104]);
         agt_in3.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 96]);
         agt_in4.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 88]);
         agt_in5.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 80]);
         agt_in6.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 72]);
         agt_in7.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 64]);
         agt_in8.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 56]);
         agt_in9.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 48]);
         agt_in10.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 40]);
         agt_in11.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 32]);
         agt_in12.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 24]);
         agt_in13.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 16]);
         agt_in14.agent_compare_port[i].connect(sb15.sb_imp_compare[i - 8]);
         agt_in15.agent_compare_port[i].connect(sb15.sb_imp_compare[i]);
      end


      agt_out0.agent_output_port.connect(sb0.sb_imp_output);
      agt_out1.agent_output_port.connect(sb1.sb_imp_output);
      agt_out2.agent_output_port.connect(sb2.sb_imp_output);
      agt_out3.agent_output_port.connect(sb3.sb_imp_output);
      agt_out4.agent_output_port.connect(sb4.sb_imp_output);
      agt_out5.agent_output_port.connect(sb5.sb_imp_output);
      agt_out6.agent_output_port.connect(sb6.sb_imp_output);
      agt_out7.agent_output_port.connect(sb7.sb_imp_output);
      agt_out8.agent_output_port.connect(sb8.sb_imp_output);
      agt_out9.agent_output_port.connect(sb9.sb_imp_output);
      agt_out10.agent_output_port.connect(sb10.sb_imp_output);
      agt_out11.agent_output_port.connect(sb11.sb_imp_output);
      agt_out12.agent_output_port.connect(sb12.sb_imp_output);
      agt_out13.agent_output_port.connect(sb13.sb_imp_output);
      agt_out14.agent_output_port.connect(sb14.sb_imp_output);
      agt_out15.agent_output_port.connect(sb15.sb_imp_output);

   endfunction
endclass
