// Top level environment tying gen, agent, driver, monitor, sb and checker together
class bus_env #(parameter int width = 16, parameter int drvs = 4);

    generator      #(width, drvs) gen;
    bus_agent      #(width, drvs) agent;
    bus_driver     #(width, drvs) driver;
    bus_monitor    #(width, drvs) monitor;
    bus_scoreboard #(width, drvs) sb;
    bus_checker    #(width, drvs) checker;

    mailbox #(transaction #(width, drvs))   mbx_gen_agent;
    mailbox #(transaction #(width, drvs))   mbx_agent_drv;
    mailbox #(transaction #(width, drvs))   mbx_agent_sb;
    mailbox #(expected_item #(width, drvs)) mbx_sb_chk;
    mailbox #(transaction #(width, drvs))   mbx_mon_chk;

    virtual dut_compl_if #(width, drvs) vif;

    string csv_name = "reporte.csv";

    // hooking up all the mailboxes and instantiating all the subcomponents
    function new(virtual dut_compl_if #(width, drvs) vif_in, int num_tx, int unsigned fifo_depth = 16);
        this.vif = vif_in;

        mbx_gen_agent = new();
        mbx_agent_drv = new();
        mbx_agent_sb  = new();
        mbx_sb_chk    = new();
        mbx_mon_chk   = new();

        gen     = new(mbx_gen_agent, num_tx);
        agent   = new(mbx_gen_agent, mbx_agent_drv, mbx_agent_sb);
        driver  = new(vif, mbx_agent_drv, fifo_depth);
        monitor = new(vif, mbx_mon_chk);
        sb      = new(mbx_agent_sb, mbx_sb_chk);
        checker = new(mbx_sb_chk, mbx_mon_chk);
    endfunction

    // timeout hack to catch hangs if the bus gets stuck. scaled based on width/drvs to account for worst case bus contention so wide packets dont falsely timeout
    task wait_drain();
        fork
            begin
                fork
                    begin
                        while (!driver.is_empty()) @(posedge vif.clk);
                        while (!checker.idle()) @(posedge vif.clk);
                        repeat (4 * width) @(posedge vif.clk);
                    end
                    begin
                        #(gen.total_tx * (width + 3) * drvs * 10 * 2 + 20000);
                        $error("[ENV] Tiempo de espera: el autobús no se vació");
                    end
                join_any
                disable fork;
            end
        join
    endtask

    // kicks off all the components, waits for gen to finish, drains the fifos, and dumps the final reports
    task run();
        $display("[ENV] ==================================================");
        $display("[ENV] INICIANDO AMBIENTE DE VERIFICACION");
        $display("[ENV] ==================================================");

        fork
            agent.run();
            driver.run();
            monitor.run();
            sb.run();
            checker.run();
        join_none

        gen.run();

        wait (gen.done);
        $display("[ENV] Generacion de estimulos completada. Esperando vaciado de FIFOs...");

        wait_drain();

        driver.report_fifo_stats();
        sb.report();
        checker.report();
        checker.write_csv(csv_name);

        $display("[ENV] ==================================================");
        $display("[ENV] SIMULACION FINALIZADA");
        $display("[ENV] ==================================================");
    endtask
endclass
