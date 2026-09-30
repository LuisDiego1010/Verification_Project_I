// Class generator.sv. The generator class is responsible for creating the randomized transactions of a test and sending them to the agent. By default each terminal gets its own random number of transactions; with num_transactions > 0 it creates that total with random sources instead.
class generator #(parameter int width = 16, parameter int drvs = 4);

    mailbox #(transaction #(width, drvs)) gen_agent_mbx;
    int num_transactions;
    // Set when every transaction has been handed to the agent
    bit done;

    // Knobs set by the test
    int unsigned tx_min;
    int unsigned tx_max;
    int unsigned min_delay;
    int unsigned max_delay;
    int unsigned pct_bcast;
    int unsigned pct_inv;
    bit [7:0] bcast_id;

    // Transactions created for each terminal and in total
    int tx_per_term[drvs];
    int total_tx;

    function new(
        mailbox #(transaction #(width, drvs)) gen_agent_mbx,
        int num_transactions
    );
        this.gen_agent_mbx = gen_agent_mbx;
        this.num_transactions = num_transactions;
        this.done = 0;
        this.tx_min = 5;
        this.tx_max = 20;
        this.min_delay = 0;
        this.max_delay = 20;
        this.pct_bcast = 15;
        this.pct_inv = 15;
        this.bcast_id = 8'hFF;
        this.total_tx = 0;
    endfunction

    // Creates one transaction; src < 0 lets the solver pick the source
    task create(int src);
        transaction #(width, drvs) pkt;
        pkt = new();
        pkt.min_delay = min_delay;
        pkt.max_delay = max_delay;
        pkt.pct_bcast = pct_bcast;
        pkt.pct_inv = pct_inv;
        pkt.bcast_id = bcast_id;
        if (src >= 0) begin
            if (!pkt.randomize() with { src_terminal == src; }) begin
                $fatal(1, "[GEN] Fallo la aleatorizacion de la transaccion %0d", total_tx);
            end
        end else begin
            if (!pkt.randomize()) begin
                $fatal(1, "[GEN] Fallo la aleatorizacion de la transaccion %0d", total_tx);
            end
        end
        gen_agent_mbx.put(pkt);
        pkt.print($sformatf("GEN %0d", total_tx));
        total_tx++;
    endtask

    task run();
        if (num_transactions > 0) begin
            $display("[GEN] Creando %0d transacciones con origen aleatorio", num_transactions);
            for (int i = 0; i < num_transactions; i++) create(-1);
        end else begin
            foreach (tx_per_term[t]) tx_per_term[t] = $urandom_range(tx_min, tx_max);
            foreach (tx_per_term[t]) begin
                $display("[GEN] Terminal %0d: %0d transacciones", t, tx_per_term[t]);
                for (int i = 0; i < tx_per_term[t]; i++) create(t);
            end
        end
        done = 1;
    endtask

endclass
