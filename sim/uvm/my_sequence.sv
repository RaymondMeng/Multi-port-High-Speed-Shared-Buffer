import uvm_pkg::*;

// class random_delay;
//     rand int delay;

//     constraint delay_range {
//     delay inside {[200:400]}; }

//     task send_delay();
//         #delay;
//     endtask

// endclass

class randdata extends uvm_sequence_item;
    rand logic [63:0] data[];
    rand bit [10:0] length;
    rand logic [3:0]  dest_port;//目标端口
    rand logic [3:0]  in_port;//输入端口
    rand logic [2:0]  prior;//优先级
    rand logic [21:0] sod;//包头数据

    `uvm_object_utils_begin(randdata)
        `uvm_field_array_int(data, UVM_ALL_ON)
        `uvm_field_int(length, UVM_ALL_ON)
        `uvm_field_int(dest_port, UVM_ALL_ON)
        `uvm_field_int(in_port, UVM_ALL_ON)
        `uvm_field_int(prior, UVM_ALL_ON)
        `uvm_field_int(sod, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name = "");
        super.new(name);
    endfunction       

    constraint data_c {
        length >= 64;
        length <= 1024;
        if ((length*8) % 128 == 0)
            data.size() == (((length*8) / 128)*2 + 2);
        else data.size() == (((length*8) / 128 + 1)*2 + 2);//根据长度确定信元数量，获得粗略长度的数据
        dest_port <= 15;
        in_port <= 15;
        prior <= 7;
    }

    function void post_randomize();
        /*根据长度，将超出长度的部分清零，从而获得精确长度的数据*/
        foreach(data[i]) begin
            foreach (data[i][j]) begin 
                if(((i-2)*64 + j) > ((length*8) - 1)) begin 
                    data[i][j] = 1'b0;
                end
            end
        end

        sod = {in_port, length, prior, dest_port};

        for(int i = 0; i<=21; i++) begin
            data[1][i] = sod[i];
        end

        for(int i = 22; i < 64; i++) begin
            data[1][i] = 0;
        end

        data[0] = 64'b0;

        foreach (data[i]) begin
            if(data[i] === 64'dx) begin
               $display("Element %d of data is unknown: %h", i, data[i]);
            end
        end
    endfunction
endclass

class case0_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case0_sequence)

   function  new(string name= "case0_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd0;
        rd0 = randdata::type_id::create("rd0");
        repeat(200) begin
            start_item(rd0);            
            rd_generate(rd0, 4'b0000);                
            finish_item(rd0);
      end
   endtask
endclass

class case1_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case1_sequence)

   function  new(string name= "case1_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd1;
        repeat(200) begin
            rd1 = randdata::type_id::create("rd1");
            start_item(rd1);            
            rd_generate(rd1, 4'b0001);                
            finish_item(rd1);
      end
   endtask
endclass

class case2_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case2_sequence)

   function  new(string name= "case2_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd2;
        rd2 = randdata::type_id::create("rd2");
        repeat(200) begin
            start_item(rd2);            
            rd_generate(rd2, 4'b0010);                
            finish_item(rd2);
      end
   endtask
endclass

class case3_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case3_sequence)

   function  new(string name= "case3_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd3;
        rd3 = randdata::type_id::create("rd3");
        repeat(200) begin
            start_item(rd3);            
            rd_generate(rd3, 4'b0011);                
            finish_item(rd3);
      end
   endtask
endclass

class case4_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case4_sequence)

   function  new(string name= "case4_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd4;
        rd4 = randdata::type_id::create("rd4");
        repeat(200) begin
            start_item(rd4);            
            rd_generate(rd4, 4'b0100);                
            finish_item(rd4);
      end
   endtask
endclass

class case5_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case5_sequence)

   function  new(string name= "case5_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd5;
        rd5 = randdata::type_id::create("rd5");
        repeat(200) begin
            start_item(rd5);            
            rd_generate(rd5, 4'b0101);                
            finish_item(rd5);
      end
   endtask
endclass

class case6_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case6_sequence)

   function  new(string name= "case6_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd6;
        rd6 = randdata::type_id::create("rd6");
        repeat(200) begin
            start_item(rd6);            
            rd_generate(rd6, 4'b0110);                
            finish_item(rd6);
      end
   endtask
endclass

class case7_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case7_sequence)

   function  new(string name= "case7_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd7;
        rd7 = randdata::type_id::create("rd7");
        repeat(200) begin
            start_item(rd7);            
            rd_generate(rd7, 4'b0111);                
            finish_item(rd7);
      end
   endtask
endclass

class case8_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case8_sequence)

   function  new(string name= "case8_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd8;
        rd8 = randdata::type_id::create("rd8");
        repeat(200) begin
            start_item(rd8);            
            rd_generate(rd8, 4'b1000);                
            finish_item(rd8);
      end
   endtask
endclass

class case9_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case9_sequence)

   function  new(string name= "case9_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd9;
        rd9 = randdata::type_id::create("rd9");
        repeat(200) begin
            start_item(rd9);            
            rd_generate(rd9, 4'b1001);                
            finish_item(rd9);
      end
   endtask
endclass

class case10_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case10_sequence)

   function  new(string name= "case10_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd10;
        rd10 = randdata::type_id::create("rd10");
        repeat(200) begin
            start_item(rd10);            
            rd_generate(rd10, 4'b1010);                
            finish_item(rd10);
      end
   endtask
endclass

class case11_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case11_sequence)

   function  new(string name= "case11_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd11;
        rd11 = randdata::type_id::create("rd11");
        repeat(200) begin
            start_item(rd11);            
            rd_generate(rd11, 4'b1011);                
            finish_item(rd11);
      end
   endtask
endclass

class case12_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case12_sequence)

   function  new(string name= "case12_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd12;
        rd12 = randdata::type_id::create("rd12");
        repeat(200) begin
            start_item(rd12);            
            rd_generate(rd12, 4'b1100);                
            finish_item(rd12);
      end
   endtask
endclass

class case13_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case13_sequence)

   function  new(string name= "case13_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd13;
        rd13 = randdata::type_id::create("rd13");
        repeat(200) begin
            start_item(rd13);            
            rd_generate(rd13, 4'b1101);                
            finish_item(rd13);
      end
   endtask
endclass

class case14_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case14_sequence)

   function  new(string name= "case14_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd14;
        rd14 = randdata::type_id::create("rd14");
        repeat(200) begin
            start_item(rd14);            
            rd_generate(rd14, 4'b1110);                
            finish_item(rd14);
      end
   endtask
endclass

class case15_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case15_sequence)

   function  new(string name= "case15_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd15;
        rd15 = randdata::type_id::create("rd15");
        repeat(200) begin
            start_item(rd15);            
            rd_generate(rd15, 4'b1111);                
            finish_item(rd15);
      end
   endtask
endclass

class my_sequencer extends uvm_sequencer #(randdata);
    `uvm_component_utils(my_sequencer)

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction 
endclass

task rd_generate(input randdata rd, input logic [3:0] in_port);
    if (!rd.randomize()) begin
        `uvm_fatal("case0_sequence", "Randomization failed");
    end
    rd.in_port          = in_port;
    rd.data[1][21:18]   = rd.in_port;
    rd.sod              = rd.data[1][21:0];                
endtask