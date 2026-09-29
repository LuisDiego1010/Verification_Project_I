// Class bus_agent.sv. The bus_agent class is responsible for receiving the transactions from the generator and sending the same transaction to the driver and to the scoreboard. It also creates the driver and starts it.
class bus_agent #(parameter int width = 16, parameter int drvs = 4);

    mailbox #(transaction #(width)) mbx_gen_agent;
    mailbox #(transaction #(width)) mbx_agent_driver;
    mailbox #(transaction #(width)) mbx_agent_sb;

    bus_driver #(width, drvs) driver;
    virtual dut_compl_if #(width, drvs, 16).DRV vif;

    function new(
        mailbox #(transaction #(width)) mbx_gen,
        mailbox #(transaction #(width)) mbx_sb,
        virtual dut_compl_if #(width, drvs, 16).DRV vif_in
    );
        this.mbx_gen_agent = mbx_gen;
        this.mbx_agent_sb = mbx_sb;
        this.vif = vif_in;
        this.mbx_agent_driver = new();
        this.driver = new(mbx_agent_driver, vif);
    endfunction

    task run();
        transaction #(width) pkt;

        fork
            driver.run();
        join_none

        $display("[AGENT] Starting packet routing...");

        forever begin
            mbx_gen_agent.get(pkt);

            mbx_agent_driver.put(pkt);
            mbx_agent_sb.put(pkt);

            $display("[AGENT] Packet sent to driver and scoreboard (dst: %0d)", pkt.dst_addr);
        end
    endtask

endclass