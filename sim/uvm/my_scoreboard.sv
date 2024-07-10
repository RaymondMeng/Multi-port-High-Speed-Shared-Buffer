import uvm_pkg::*;

// `uvm_analysis_imp_decl(_output)
// `uvm_analysis_imp_decl(_compare)

class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    uvm_analysis_export #(randdata) sb_export_output;
    uvm_analysis_export #(randdata) sb_export_compare;

    uvm_tlm_analysis_fifo #(randdata) output_fifo;
    uvm_tlm_analysis_fifo #(randdata) compare_fifo;

    randdata rd_out_sb;
    randdata rd_cmp_sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        rd_out_sb = randdata::type_id::create("rd_out_sb");
        rd_cmp_sb = randdata::type_id::create("rd_cmp_sb");

        sb_export_output    = new("sb_export_output", this);
        sb_export_compare   = new("sb_export_compare", this);

        output_fifo         = new("output_fifo", this);
        compare_fifo        = new("compare_fifo", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction

    virtual task run();
        forever begin
            `uvm_info("SB", "waiting for input fifo", UVM_LOW);
            compare_fifo.get(rd_cmp_sb);
            `uvm_info("SB", "waiting for output fifo", UVM_LOW);
            output_fifo.get(rd_out_sb);       
            dataprint();
            `uvm_info("SB", "print complete", UVM_LOW);
        end
    endtask

    virtual function void dataprint();
        if (rd_out_sb.data == rd_cmp_sb.data) begin
            `uvm_info("SB_PRT", rd_out_sb.sprint(), UVM_LOW);
            `uvm_info("SB_PRT", rd_cmp_sb.sprint(), UVM_LOW);
            `uvm_error("SB_PRT", $sformatf("Test: Failed! Expecting: %h, Received: %h", rd_cmp_sb.data, rd_out_sb.data))
        end
    endfunction
endclass
