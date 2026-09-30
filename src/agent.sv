// Class bus_agent.sv. The bus_agent class is responsible for receiving the transactions from the generator and splitting them: one copy of the handle goes to the driver to be executed and one to the scoreboard as reference.
class bus_agent #(parameter int width = 16, parameter int drvs = 4);

    mailbox #(transaction #(width, drvs)) gen_agent_mbx;
    mailbox #(transaction #(width, drvs)) agent_drv_mbx;
    mailbox #(transaction #(width, drvs)) agent_sb_mbx;

    function new(
        mailbox #(transaction #(width, drvs)) gen_agent_mbx,
        mailbox #(transaction #(width, drvs)) agent_drv_mbx,
        mailbox #(transaction #(width, drvs)) agent_sb_mbx
    );
        this.gen_agent_mbx = gen_agent_mbx;
        this.agent_drv_mbx = agent_drv_mbx;
        this.agent_sb_mbx = agent_sb_mbx;
    endfunction

    task run();
        transaction #(width, drvs) pkt;
        forever begin
            gen_agent_mbx.get(pkt);
            // Both receive the same handle: the driver writes sent_time on it and the checker reads it through the scoreboard expectation
            agent_drv_mbx.put(pkt);
            agent_sb_mbx.put(pkt);
        end
    endtask

endclass
