class bus_test #(parameter int width = 16, parameter int drvs = 4);
    
    bus_env #(width, drvs) env;
    int num_transacciones;

  function new(virtual dut_compl_if #(width, drvs, 16) vif_in);
        this.num_transacciones = 15;
        this.env = new(vif_in, num_transacciones);
    endfunction

    task run();
        $display("[TEST] ==================================================");
        $display("[TEST] INICIANDO PRUEBA BASE (BASE_TEST)");
        $display("[TEST] Generando %0d transacciones...", num_transacciones);
        $display("[TEST] ==================================================");

        env.run();

        $display("[TEST] ==================================================");
        $display("[TEST] PRUEBA FINALIZADA CORRECTAMENTE");
        $display("[TEST] ==================================================");
    endtask
endclass
