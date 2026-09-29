// Class bus_env.sv. The bus_env class is responsible for creating all the verification components, connecting them through mailboxes and running the simulation until the report is printed.
class bus_env #(parameter int width = 16, parameter int drvs = 4);

    generator #(width) gen;
    bus_agent #(width, drvs) agent;
    monitor #(.drvs(drvs), .width(width)) mon;
    scoreboard #(.drvs(drvs), .width(width)) sb;
    bus_checker #(.drvs(drvs), .width(width)) chk;

    mailbox #(transaction #(width)) mbx_gen_agent;
    mailbox #(transaction #(width)) mbx_agent_sb;
    mailbox #(expected_item #(width)) mbx_sb_chk;
    mailbox #(transaction #(width)) mbx_mon_chk;

    virtual dut_compl_if #(width, drvs, 16) vif;

    function new(
        virtual dut_compl_if #(width, drvs, 16) vif_in,
        int num_tx
    );
        this.vif = vif_in;

        mbx_gen_agent = new();
        mbx_agent_sb = new();
        mbx_sb_chk = new();
        mbx_mon_chk = new();

        gen = new(mbx_gen_agent, num_tx);
        agent = new(mbx_gen_agent, mbx_agent_sb, vif.DRV);
        mon = new(vif.MON, mbx_mon_chk);
        sb = new(mbx_agent_sb, mbx_sb_chk);
        chk = new(mbx_sb_chk, mbx_mon_chk);
    endfunction

    task run();
        $display("[ENV] ==================================================");
        $display("[ENV] STARTING VERIFICATION ENVIRONMENT");
        $display("[ENV] ==================================================");

        fork
            agent.run();
            mon.run();
            sb.run();
            chk.run();
        join_none

        gen.run();

        wait(gen.gen_completed.triggered);
        $display("[ENV] Stimulus generation done. Waiting for the FIFOs to drain...");

        #6000;

        sb.report();
        chk.report();
        // chk.write_csv();

        $display("[ENV] ==================================================");
        $display("[ENV] SIMULATION FINISHED");
        $display("[ENV] ==================================================");
    endtask

endclass