// Class fifo_emulator.sv. The fifo_emulator class is responsible for emulating the output FIFO of one terminal.
class fifo_emulator #(parameter int width = 16, parameter int drvs = 4);

    virtual dut_compl_if #(width, drvs) vif;
    mailbox #(transaction #(width, drvs)) parent_child_mbx;
    transaction #(width, drvs) pkt_queue[$];
    int id;
    int n_sent;
    // 1 while feed() holds a packet during its delay (it is in neither the mailbox nor the queue, but it has not been sent yet)
    bit in_delay;

    function new(
        int id,
        virtual dut_compl_if #(width, drvs) vif,
        mailbox #(transaction #(width, drvs)) parent_child_mbx
    );
        this.id = id;
        this.vif = vif;
        this.parent_child_mbx = parent_child_mbx;
        this.n_sent = 0;
        this.in_delay = 0;
    endfunction

    // Puts the FIFO outputs in a known idle state (used during reset)
    function void drive_idle();
        vif.pndng[0][id] = 1'b0;
        vif.D_pop[0][id] = '0;
    endfunction

    // True when there is nothing left to hand to the DUT
    function bit is_empty();
        return (pkt_queue.size() == 0) && (parent_child_mbx.num() == 0) && !in_delay;
    endfunction

    task run();
        fork
            feed();
            drive();
        join_none
    endtask

    // Moves packets from the parent into the FIFO, waiting each packet's delay first, so the delay is the gap between messages of this terminal
    task feed();
        transaction #(width, drvs) pkt;
        forever begin
            parent_child_mbx.get(pkt);
            in_delay = 1;
            repeat (pkt.delay) @(vif.cb_drv);
            pkt_queue.push_back(pkt);
            in_delay = 0;
        end
    endtask

    // Serves the DUT: first consumes a pop, then presents the new head
    task drive();
        transaction #(width, drvs) current_pkt;
        forever begin
            @(vif.cb_drv);
            if (vif.cb_drv.pop[0][id] === 1'b1) begin
                if (pkt_queue.size() > 0) begin
                    current_pkt = pkt_queue.pop_front();
                    current_pkt.sent_time = $realtime;
                    n_sent++;
                end else begin
                    $error("[DRV-%0d] pop recibido con la FIFO vacia en %0t", id, $realtime);
                end
            end
            if (pkt_queue.size() > 0) begin
                vif.cb_drv.pndng[0][id] <= 1'b1;
                vif.cb_drv.D_pop[0][id] <= pkt_queue[0].pack();
            end else begin
                vif.cb_drv.pndng[0][id] <= 1'b0;
                vif.cb_drv.D_pop[0][id] <= '0;
            end
        end
    endtask

endclass

// Class bus_driver.sv. The bus_driver class is responsible for receiving the transactions from the agent and routing each one to the fifo_emulator of its source terminal. Every child runs in its own process.
class bus_driver #(parameter int width = 16, parameter int drvs = 4);

    virtual dut_compl_if #(width, drvs) vif;
    mailbox #(transaction #(width, drvs)) agent_drv_mbx;
    mailbox #(transaction #(width, drvs)) parent_child_mbx[drvs];
    fifo_emulator #(width, drvs) children[drvs];

    function new(
        virtual dut_compl_if #(width, drvs) vif,
        mailbox #(transaction #(width, drvs)) agent_drv_mbx
    );
        this.vif = vif;
        this.agent_drv_mbx = agent_drv_mbx;
        for (int i = 0; i < drvs; i++) begin
            parent_child_mbx[i] = new();
            children[i] = new(i, vif, parent_child_mbx[i]);
        end
    endfunction

    function void drive_idle();
        foreach (children[i]) children[i].drive_idle();
    endfunction

    // True when every child FIFO has handed all its packets to the DUT
    function bit is_empty();
        foreach (children[i]) begin
            if (!children[i].is_empty()) return 0;
        end
        return (agent_drv_mbx.num() == 0);
    endfunction

    task run();
        transaction #(width, drvs) pkt;
        foreach (children[i]) children[i].run();
        forever begin
            agent_drv_mbx.get(pkt);
            if (pkt.src_terminal >= drvs) begin
                $error("[DRV] Terminal de origen invalida %0d, paquete descartado", pkt.src_terminal);
            end else begin
                parent_child_mbx[pkt.src_terminal].put(pkt);
            end
        end
    endtask

endclass
