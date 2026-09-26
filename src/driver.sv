// 1. First section of the emulated FIFOs

class fifo_emulator #(parameter int width = 16, parameter int id = 0);

    virtual dut_compl_if.DRV vif;

    // Se usan queues para los hijos
    transaction #(width) pkt_queue[$]; 

    function new(virtual dut_compl_if.DRV vif_in);
        this.vif = vif_in;
    endfunction

    // State machine
    task run();
        transaction #(width) current_pkt;

        forever begin
            @(vif.cb_drv); // The clock is synchronized here.

            if (pkt_queue.size() > 0) begin

                // 1. If there is data in the queue, `pndng` is raised and the data is exposed at `D_pop`.
                vif.cb_drv.pndng[0][id] <= 1'b1;
                vif.cb_drv.D_pop[0][id] <= pkt_queue[0].pack();

                // 2. In response to the 'pop', the referee awards the bus and reads out the data.
                if (vif.cb_drv.pop[0][id] === 1'b1) begin
                    current_pkt = pkt_queue.pop_front();  // The package is removed from the queue.
                    current_pkt.send_time = $realtime;    // Send time is recorded
                    $display("[FIFO-%0d] Pkt inyectado (Dest: %0d) al tiempo %0t", 
                              id, current_pkt.dst_addr, current_pkt.send_time);
                end
            end else begin
                // 3. If the queue is empty, the bus remains inactive.
                vif.cb_drv.pndng[0][id] <= 1'b0;
                vif.cb_drv.D_pop[0][id] <= '0;
            end
        end
    endtask

endclass


// 2. Second section Handler controller

class bus_driver #(parameter int width = 16, parameter int drvs = 4);

    mailbox mbx_agent_driver;
    virtual dut_compl_if.DRV vif;

    // The child processes are instantiated.
    fifo_emulator #(width, 0) hijo_0;
    fifo_emulator #(width, 1) hijo_1;
    fifo_emulator #(width, 2) hijo_2;
    fifo_emulator #(width, 3) hijo_3;

    function new(mailbox mbx, virtual dut_compl_if.DRV vif_in);
        this.mbx_agent_driver = mbx;
        this.vif = vif_in;

        // Building the emulators by assigning the terminal ID.
        hijo_0 = new(vif);
        hijo_1 = new(vif);
        hijo_2 = new(vif);
        hijo_3 = new(vif);
    endfunction

    task run();
        // 1. The virtual hardware of the child instances is initialized in parallel
        fork
            hijo_0.run();
            hijo_1.run();
            hijo_2.run();
            hijo_3.run();
        join_none

        // 2. Parent process that distributes by device
        forever begin
            transaction #(width) pkt;

            // The package is removed from the generator's mailbox
            mbx_agent_driver.get(pkt);


            // An automatic thread is opened to handle the individual packet delay.
            fork
                automatic transaction #(width) p = pkt;
                begin
                    // Aplicamos la variable aleatoria 'delay' simulando el tiempo de procesamiento
                    repeat(p.delay) @(vif.cb_drv);

                    // The delay variable is applied to simulate processing time.
                    case (p.src_terminal)
                        0: hijo_0.pkt_queue.push_back(p);
                        1: hijo_1.pkt_queue.push_back(p);
                        2: hijo_2.pkt_queue.push_back(p);
                        3: hijo_3.pkt_queue.push_back(p);
                        default: $error("[DRIVER PADRE] Terminal origen inválida: %0d", p.src_terminal);
                    endcase
                end
            join_none
        end
    endtask

endclass
