import uvm_pkg::*;

class randdata extends uvm_sequence_item;
    rand logic [63:0] data[];
    rand logic [10:0] length;
    rand logic [3:0]  dest_port;
    rand logic [2:0]  prior;
    rand logic [17:0] sod;

    `uvm_object_utils_begin(randdata)
        `uvm_field_array_int(data, UVM_ALL_ON)
        `uvm_field_int(length, UVM_ALL_ON)
        `uvm_field_int(dest_port, UVM_ALL_ON)
        `uvm_field_int(prior, UVM_ALL_ON)
        `uvm_field_int(sod, UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name = "");
        super.new(name);
    endfunction       

    constraint data_c {
        length >= 64;
        length <= 1024;
        if (length % 64 == 0)
            data.size() == ((length / 64));
        else data.size() == ((length / 64) + 1);
        dest_port <= 15;
        prior <= 7;
    }

    function void post_randomize();
        foreach(data[i]) begin
            foreach (data[i][j]) begin 
                if((i*64 + j) > (length - 1)) begin 
                    data[i][j] = 0;
                end
            end
        end

        sod = {length, prior, dest_port};

        for(int i = 0; i<=17; i++) begin
            data[0][i] = sod[i];
        end
    endfunction
endclass

class case0_sequence extends uvm_sequence #(randdata);
   `uvm_object_utils(case0_sequence)

   function  new(string name= "case0_sequence");
      super.new(name);
   endfunction 
   
   virtual task body();
        randdata rd;
        int i;
        repeat(50) begin
            rd = randdata::type_id::create("rd");
            start_item(rd);            
            if (!rd.randomize()) begin
                `uvm_fatal("case0_sequence", "Randomization failed");
                end                      
            finish_item(rd);
      end
   endtask
endclass

class my_sequencer extends uvm_sequencer #(randdata);
    `uvm_component_utils(my_sequencer)

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction 
endclass