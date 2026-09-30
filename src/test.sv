// Class bus_test.sv. The bus_test class is responsible for configuring the scenario from plusargs, running the environment and printing the final verdict.
//   +TX_MIN=<n> +TX_MAX=<n>        transactions per terminal (default 5..20)
//   +NUM_TX=<n>                    total transactions with random sources instead
//   +DLY_MIN=<n> +DLY_MAX=<n>      cycles between messages of a terminal (default 0..20)
//   +PCT_BCAST=<n> +PCT_INV=<n>    percentage of broadcast and invalid destinations (default 15 and 15)
class bus_test #(parameter int width = 16, parameter int drvs = 4);

    bus_env #(width, drvs) env;
    bit [7:0] bcast_id;
    int num_tx;
    int tx_min;
    int tx_max;
    int dly_min;
    int dly_max;
    int pct_bcast;
    int pct_inv;
    int seed;
    bit seed_given;

    function new(
        virtual dut_compl_if #(width, drvs) vif,
        bit [7:0] bcast_id
    );
        this.bcast_id = bcast_id;
        if (!$value$plusargs("NUM_TX=%d", num_tx)) num_tx = 0;
        if (!$value$plusargs("TX_MIN=%d", tx_min)) tx_min = 5;
        if (!$value$plusargs("TX_MAX=%d", tx_max)) tx_max = 20;
        if (!$value$plusargs("DLY_MIN=%d", dly_min)) dly_min = 0;
        if (!$value$plusargs("DLY_MAX=%d", dly_max)) dly_max = 20;
        if (!$value$plusargs("PCT_BCAST=%d", pct_bcast)) pct_bcast = 15;
        if (!$value$plusargs("PCT_INV=%d", pct_inv)) pct_inv = 15;
        // VCS seed, only to print it and to name the CSV
        seed_given = $value$plusargs("ntb_random_seed=%d", seed);

        if (tx_min < 0 || tx_max < tx_min) $fatal(1, "[TEST] Rango de transacciones invalido: %0d..%0d", tx_min, tx_max);
        if (dly_min < 0 || dly_max < dly_min) $fatal(1, "[TEST] Rango de retardo invalido: %0d..%0d", dly_min, dly_max);
        if (pct_bcast < 0 || pct_inv < 0 || pct_bcast + pct_inv > 100) $fatal(1, "[TEST] Porcentajes invalidos: broadcast=%0d invalidos=%0d", pct_bcast, pct_inv);

        env = new(vif, num_tx);
        env.gen.tx_min = tx_min;
        env.gen.tx_max = tx_max;
        env.gen.min_delay = dly_min;
        env.gen.max_delay = dly_max;
        env.gen.pct_bcast = pct_bcast;
        env.gen.pct_inv = pct_inv;
        env.gen.bcast_id = bcast_id;
        env.sb.bcast_id = bcast_id;
        if (seed_given) env.csv_name = $sformatf("reporte_w%0d_seed%0d.csv", width, seed);
        else env.csv_name = $sformatf("reporte_w%0d.csv", width);
    endfunction

    task run();
        if (seed_given) $display("[TEST] semilla=%0d", seed);
        else $display("[TEST] semilla=por defecto");
        $display("[TEST] ancho=%0d terminales=%0d broadcast=%0d", width, drvs, bcast_id);
        if (num_tx > 0) $display("[TEST] transacciones=%0d en total", num_tx);
        else $display("[TEST] transacciones por terminal=%0d..%0d", tx_min, tx_max);
        $display("[TEST] retardo=%0d..%0d ciclos broadcast=%0d%% invalidos=%0d%%", dly_min, dly_max, pct_bcast, pct_inv);
        env.run();
        // Passes when nothing went wrong and every expected reception arrived (with only invalid traffic nothing is expected)
        if (env.chk.n_errors() == 0 && env.chk.n_ok == env.sb.n_expected && env.gen.total_tx > 0) begin
            $display("[TEST] APROBADO");
        end else begin
            $display("[TEST] FALLIDO (%0d errores)", env.chk.n_errors());
        end
    endtask

endclass
