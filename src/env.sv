// Class bus_env.sv. The bus_env class is responsible for creating all the verification components, connecting them through mailboxes and running the simulation until the report is printed.
class bus_env #(parameter int width = 16, parameter int drvs = 4);

    virtual dut_compl_if #(width, drvs) vif;

    generator #(width, drvs) gen;
    bus_agent #(width, drvs) agent;
    bus_driver #(width, drvs) drv;
    bus_monitor #(width, drvs) mon;
    bus_scoreboard #(width, drvs) sb;
    bus_checker #(width, drvs) chk;

    mailbox #(transaction #(width, drvs)) gen_agent_mbx;
    mailbox #(transaction #(width, drvs)) agent_drv_mbx;
    mailbox #(transaction #(width, drvs)) agent_sb_mbx;
    mailbox #(transaction #(width, drvs)) mon_chk_mbx;
    mailbox #(expected_item #(width, drvs)) sb_chk_mbx;

    // Cycles allowed for the DUT to pop every packet (the bus is shared, so packets are serialized one after another)
    int pop_timeout;

    // Cycles to wait for the expected packets after the FIFOs are empty
    int drain_timeout;
    // Name of the CSV report (set by the test)
    string csv_name;

    function new(
        virtual dut_compl_if #(width, drvs) vif,
        int num_tx
    );
        this.vif = vif;

        gen_agent_mbx = new();
        agent_drv_mbx = new();
        agent_sb_mbx = new();
        mon_chk_mbx = new();
        sb_chk_mbx = new();

        gen = new(gen_agent_mbx, num_tx);
        agent = new(gen_agent_mbx, agent_drv_mbx, agent_sb_mbx);
        drv = new(vif, agent_drv_mbx);
        mon = new(vif, mon_chk_mbx);
        sb = new(agent_sb_mbx, sb_chk_mbx);
        chk = new(sb_chk_mbx, mon_chk_mbx);

        drain_timeout = 4 * drvs * (width + 16) + 1000;
        csv_name = "reporte_retardos.csv";
    endfunction

    task run();
        int cycles;

        // FIFOs idle while the DUT is in reset
        drv.drive_idle();
        do @(vif.cb_drv); while (vif.cb_drv.reset !== 1'b0);

        fork
            gen.run();
            agent.run();
            drv.run();
            mon.run();
            sb.run();
            chk.run();
        join_none

        // 1. Every transaction generated and handed to the DUT
        wait (gen.done);
        // The total is known only now. One packet uses approximately width cycles of serialization plus a few of protocol; allow a full arbitration round per packet, plus the delays of the busiest terminal
        pop_timeout = 4 * gen.total_tx * (width + 16) + gen.total_tx * gen.max_delay + 1000;
        cycles = 0;
        while ((!drv.is_empty() || gen_agent_mbx.num() != 0) && cycles < pop_timeout) begin
            @(vif.cb_mon);
            cycles++;
        end
        if (cycles >= pop_timeout) begin
            $error("[ENV] El DUT dejo de sacar paquetes de las FIFOs (timeout despues de %0d ciclos)", cycles);
        end else begin
            $display("[ENV] El DUT saco todos los paquetes de las FIFOs en %0t", $realtime);
        end

        // 2. Every expected reception arrived, or timeout
        cycles = 0;
        while (chk.outstanding() > 0 && cycles < drain_timeout) begin
            @(vif.cb_mon);
            cycles++;
        end
        if (cycles >= drain_timeout) begin
            $display("[ENV] Timeout esperando los paquetes pendientes despues de %0d ciclos", cycles);
        end

        // 3. Let packets without receivers (invalid addresses) finish
        repeat (2 * (width + 16)) @(vif.cb_mon);

        sb.report();
        chk.report();
        chk.write_csv(csv_name);
    endtask

endclass
