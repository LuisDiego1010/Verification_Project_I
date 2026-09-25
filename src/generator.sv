

class generator #(parameter int width = 16);

    // The mailbox that will connect to the subsequent layers is declared
    mailbox mbx;
    // Number of transactions to generate in the test
    int num_transactions;

    // Everything has finished generating.
    event gen_completed;


    // Constructor is created
    function new(mailbox mbx_in, int num_tx);
        this.mbx = mbx_in;
        this.num_transactions = num_tx;
    endfunction

    // Main generation task
    task run();
      // Package handler
        transaction #(width) pkt;

        $display("[GENERATOR] Creacion de %0d transacciones: ", num_transactions);        
        for (int i = 0; i < num_transactions; i++) begin
          // The new package is instantiated in each iteration
            pkt = new();

            // Randomization is performed by applying the constraints.
            if (!pkt.randomize()) begin
                $fatal("Error: Fallo en la aleatorizacion en el generador");
            end

            // A random origin is assigned
            pkt.src_terminal = $urandom_range(0, 3);

            // Send to mailbox
            mbx.put(pkt)


            $display("[GENERATOR] Paquete %0d enviado al mailbox (Source: %0d)", i, pkt.src_terminal);
        end

        // Notify the environment that generation is complete
        -> gen_completed;
    endtask

endclass
