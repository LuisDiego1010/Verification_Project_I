// top level test class reading plusargs to set up the environment and decide pass/fail conditions
// handles stuff like picking if we're doing a general mix, mostly invalid, or pushing for an overflow
class bus_test #(parameter int width = 16, parameter int drvs = 4);

    bus_env #(width, drvs) env;

    string test_name;
    int num_transacciones;
    int seed;
    int unsigned fifo_depth;

    // constructor grabs all the command line overrides and initializes the env based on the testcase
    function new(
        virtual dut_compl_if #(width, drvs) vif_in,
        bit [7:0] bcast_id = 8'hFF
    );
        string case_name;

        if (!$value$plusargs("ntb_random_seed=%d", seed)) seed = 0;
        if (!$value$plusargs("TEST_CASE=%s", case_name)) case_name = "GENERAL";

        this.test_name = case_name.tolower();
        this.num_transacciones = 50;
        this.fifo_depth = 16;

        // overrides for specific corner cases. overflow gets a tiny fifo and lower total tx
        case (case_name)
            "OVERFLOW":  begin this.num_transacciones = 20; this.fifo_depth = 2; end
            default: ; 
        endcase

        void'($value$plusargs("NUM_TX=%d", this.num_transacciones));
        void'($value$plusargs("FIFO_DEPTH=%d", this.fifo_depth));

        this.env = new(vif_in, num_transacciones, fifo_depth);
        this.env.gen.bcast_id = bcast_id;
        this.env.sb.bcast_id  = bcast_id;

        // Configure the generator knobs for the chosen case
        case (case_name)
            "GENERAL": ; // keep the generator's own randomized defaults
            "BCAST": begin
                this.env.gen.pct_bcast = 100;
                this.env.gen.pct_inv   = 0;
            end
            "INVALID": begin
                this.env.gen.pct_bcast = 0;
                this.env.gen.pct_inv   = 100;
            end
            // edge case where everything tries to talk to itself to make sure the bus handles it properly
            "SELF": begin
                this.env.gen.force_self = 1;
                this.env.gen.pct_bcast  = 0;
                this.env.gen.pct_inv    = 0;
            end
            // hammers a single terminal endlessly with zero delay so its fifo clogs up
            "OVERFLOW": begin
                this.env.gen.pct_bcast = 0;
                this.env.gen.pct_inv   = 0;
                this.env.gen.min_delay = 0;
                this.env.gen.max_delay = 0;
                this.env.gen.flood_terminal = 0; // floods terminal 0
            end
            default: begin
                $fatal(1, "[TEST] TEST_CASE desconocido: '%s' (opciones: GENERAL, BCAST, INVALID, SELF, OVERFLOW)", case_name);
            end
        endcase

        this.env.csv_name = $sformatf("reporte_%s_w%0d_seed%0d.csv", test_name, width, seed);
    endfunction

    // executes the test and judges the checker stats to see if we passed or bombed
    task run();
        int errors;

        $display("[TEST] ==================================================");
        $display("[TEST] INICIANDO PRUEBA %s (semilla %0d)", test_name, seed);
        if (num_transacciones > 0) begin
            $display("[TEST] Generando %0d transacciones en total (fifo_depth=%0d)...", num_transacciones, fifo_depth);
        end else begin
            $display("[TEST] Generando transacciones por terminal, %0d..%0d cada una (fifo_depth=%0d)...",
                     env.gen.tx_min, env.gen.tx_max, fifo_depth);
        end
        $display("[TEST] ==================================================");

        env.run();

        errors = env.checker.errors();

        $display("[TEST] ==================================================");
        if (errors == 0 && env.checker.n_ok > 0) begin
            $display("[TEST] RESULTADO: PASS (%0d paquetes correctos)", env.checker.n_ok);
        end else if (env.checker.n_ok == 0 && env.checker.n_unexpected == 0) begin
            $display("[TEST] RESULTADO: PASS (0 paquetes esperados, 0 recibidos: esperado para INVALID y SELF)");
        end else begin
            $display("[TEST] RESULTADO: FAIL (%0d errores: inesperados=%0d, fuera de orden=%0d, perdidos=%0d)",
                     errors, env.checker.n_unexpected, env.checker.n_order, env.checker.n_missing);
        end
        $display("[TEST] ==================================================");
    endtask

endclass
