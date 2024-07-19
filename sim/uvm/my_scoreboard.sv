import uvm_pkg::*;
`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    uvm_analysis_imp_output#(randdata, my_scoreboard) sb_imp_output;
    uvm_analysis_imp_compare#(randdata, my_scoreboard) sb_imp_compare[];

    uvm_tlm_fifo #(randdata) compare_fifo[128];
    uvm_tlm_fifo #(randdata) output_fifo;

    covergroup cov_sb;
        coverpoint total_pkg{
            bins total_pkg_cov ={1};
        }

        coverpoint normal_work{
            bins normal_work_cov ={1};
        }

        // coverpoint error_work{
        //     bins error_work_cov ={1};
        // }
    endgroup

    randdata rd_cmp_sb;
    randdata rd_out_sb;
    randdata rd_write_out;
    randdata rd_write_com;
    int num_prior = 8;
    int num_port = 16;
    int input_port_read;
    int input_port_write;
    int normal_work = 0;
    int error_work = 0;
    int total_pkg = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cov_sb = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        rd_cmp_sb = randdata::type_id::create("rd_cmp_sb");
        rd_out_sb = randdata::type_id::create("rd_out_sb");
        rd_write_out = randdata::type_id::create("rd_write_out");
        rd_write_com = randdata::type_id::create("rd_write_com");

        sb_imp_output    = new("sb_imp_output", this);
        sb_imp_compare   = new[num_prior * num_port];
        for(int i = 0; i < num_prior*num_port; i++) begin
            sb_imp_compare[i]  = new($sformatf("sb_imp_compare_%0d", i), this);
        end  

        output_fifo         = new("output_fifo", this);
        // compare_fifo        = new[num_prior * num_port];
        for(int i = 0; i < num_prior*num_port; i++) begin
            compare_fifo[i]  = new($sformatf("compare_fifo_%0d", i), this);
        end

    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            input_port_read = 0;

            if (!rd_out_sb.randomize()) begin
                `uvm_fatal("my_scoreboard", "Randomization failed");
            end

            if (!rd_cmp_sb.randomize()) begin
                `uvm_fatal("my_scoreboard", "Randomization failed");
            end
            
            output_fifo.get(rd_out_sb);
            total_pkg += 1;
            // `uvm_info("my_scoreboard_output", rd_out_sb.sprint(), UVM_LOW)

            input_port_read = rd_out_sb.in_port*8 + rd_out_sb.prior;
            // `uvm_info("my_scoreboard", $sformatf("compare_fifo input_port_read is %0d", input_port_read), UVM_LOW)
            compare_fifo[input_port_read].get(rd_cmp_sb);
            // `uvm_info("my_scoreboard_compare", rd_cmp_sb.sprint(), UVM_LOW)

            // datacompare();

            if (rd_out_sb.data != rd_cmp_sb.data) begin
                error_work += 1;
                `uvm_info("SB_datacompare_error", rd_out_sb.sprint(), UVM_LOW)
                `uvm_info("SB_datacompare_error", rd_cmp_sb.sprint(), UVM_LOW)
                `uvm_error("SB_datacompare_error", $sformatf("Test: Failed! error work: %d, total pkg: %d", error_work, total_pkg))
            end
            else begin
                normal_work += 1;
                `uvm_info("SB_datacompare_success", rd_out_sb.sprint(), UVM_LOW)
                `uvm_info("SB_datacompare_success", rd_cmp_sb.sprint(), UVM_LOW)
                `uvm_info("SB_datacompare_success", $sformatf("Test success:%0d, Total pkg:%0d", normal_work, total_pkg), UVM_LOW)
            end
            cov_sb.sample();
            `uvm_info("Coverage", $sformatf("total coverage:%0d", $get_coverage()), UVM_LOW)
            `uvm_info("Coverage", $sformatf("sb coverage:%0.2f", cov_sb.get_inst_coverage()), UVM_LOW)
        end
    endtask

    virtual function void write_output(randdata rd);
        rd_write_out = randdata::type_id::create("rd_write_out");
        rd_write_out.data       = rd.data;
        rd_write_out.length     = rd.length;
        rd_write_out.dest_port  = rd.dest_port;
        rd_write_out.in_port    = rd.in_port;
        rd_write_out.prior      = rd.prior;
        rd_write_out.sod        = rd.sod;
        output_fifo.try_put(rd_write_out);
    endfunction

    virtual function void write_compare(randdata rd);
        rd_write_com = randdata::type_id::create("rd_write_com");
        input_port_write = 0;
        rd_write_com.data       = rd.data;
        rd_write_com.length     = rd.length;
        rd_write_com.dest_port  = rd.dest_port;
        rd_write_com.in_port    = rd.in_port;
        rd_write_com.prior      = rd.prior;
        rd_write_com.sod        = rd.sod;

        input_port_write = rd.in_port*8 + rd.prior;
        compare_fifo[input_port_write].try_put(rd_write_com);
        // `uvm_info("SB_write_compare", $sformatf("input_port_write is %0d", input_port_write), UVM_LOW)
        // `uvm_info("SB_write_compare", rd.sprint(), UVM_LOW)
        // `uvm_info("SB_write_compare", rd_write_com.sprint(), UVM_LOW)
    endfunction

    // virtual function void datacompare();
    //     if (rd_out_sb.data != rd_cmp_sb.data) begin
    //         `uvm_info("SB_datacompare", rd_out_sb.sprint(), UVM_LOW)
    //         `uvm_info("SB_datacompare", rd_cmp_sb.sprint(), UVM_LOW)
    //         `uvm_error("SB_datacompare", $sformatf("Test: Failed! Expecting: %h, Received: %h", rd_cmp_sb.data, rd_out_sb.data))
    //     end
    //     else begin
    //         `uvm_info("SB_datacompare", "Test success:%d", normal_work, UVM_LOW)
    //         normal_work += 1;
    //     end
    // endfunction
endclass