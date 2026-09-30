// Class chk_result.sv. The chk_result class is responsible for holding one row of the CSV report: a packet that was correctly received.
class chk_result;
    int src;
    int rx;
    bit [63:0] data;
    real sent_time;
    real receive_time;
    real delay;
endclass

// Class bus_checker.sv. The bus_checker class is responsible for comparing what the monitor observed against what the scoreboard expected. It flags unexpected packets, packets received before being sent, order violations and missing packets, and it collects the delays for the CSV report.
class bus_checker #(parameter int width = 16, parameter int drvs = 4);

    mailbox #(expected_item #(width, drvs)) sb_chk_mbx;
    mailbox #(transaction #(width, drvs)) mon_chk_mbx;

    expected_item #(width, drvs) pending[drvs][$];
    chk_result results[$];

    int n_ok;
    int n_unexpected;
    int n_early;
    int n_order;
    int n_missing;
    real sum_delay;
    real min_delay;
    real max_delay;

    function new(
        mailbox #(expected_item #(width, drvs)) sb_chk_mbx,
        mailbox #(transaction #(width, drvs)) mon_chk_mbx
    );
        this.sb_chk_mbx = sb_chk_mbx;
        this.mon_chk_mbx = mon_chk_mbx;
    endfunction

    function void pull_expected();
        expected_item #(width, drvs) e;
        while (sb_chk_mbx.try_get(e)) begin
            pending[e.rx_id].push_back(e);
        end
    endfunction

    // Number of receptions still expected, and used by the env to know when the bus has been drained
    function int outstanding();
        int n = 0;
        pull_expected();
        foreach (pending[rx]) n += pending[rx].size();
        return n;
    endfunction

    task run();
        transaction #(width, drvs) obs;
        forever begin
            mon_chk_mbx.get(obs);
            pull_expected();
            check(obs);
        end
    endtask

    function void check(transaction #(width, drvs) obs);
        int rx = obs.rx_terminal;
        int idx = -1;
        bit match_unsent = 0;
        expected_item #(width, drvs) e;
        chk_result r;

        // The packet carries no source ID, so several expectations may have the same content. Among them, take the one sent the earliest.
        foreach (pending[rx][i]) begin
            if (pending[rx][i].tr.pack() == obs.pack()) begin
                if (pending[rx][i].tr.sent_time < 0) begin
                    match_unsent = 1;
                end else if (idx < 0 || pending[rx][i].tr.sent_time < pending[rx][idx].tr.sent_time) begin
                    idx = i;
                end
            end
        end

        if (idx < 0) begin
            if (match_unsent) begin
                n_early++;
                $error("[CHK] %h en rx %0d llego antes de salir de su FIFO, t=%0t",
                       obs.pack(), rx, $realtime);
            end else begin
                n_unexpected++;
                $error("[CHK] Paquete inesperado %h en rx %0d, t=%0t", obs.pack(), rx, $realtime);
            end
            return;
        end

        e = pending[rx][idx];

        // Packets from the same source to the same receiver must keep order. Older ones still pending are only marked here: if they arrive later it is a reordering, if they never arrive it is reported as missing (so a single lost packet does not cascade into order errors).
        if (e.overtaken) begin
            n_order++;
            $error("[CHK] Fuera de orden en rx %0d: %h del origen %0d llego despues de un paquete mas reciente",
                   rx, obs.pack(), e.tr.src_terminal);
        end
        foreach (pending[rx][j]) begin
            if (j != idx
                && pending[rx][j].tr.src_terminal == e.tr.src_terminal
                && pending[rx][j].tr.sent_time >= 0
                && pending[rx][j].tr.sent_time < e.tr.sent_time) begin
                pending[rx][j].overtaken = 1;
            end
        end

        pending[rx].delete(idx);

        r = new();
        r.src = e.tr.src_terminal;
        r.rx = rx;
        r.data = obs.pack();
        r.sent_time = e.tr.sent_time;
        r.receive_time = obs.receive_time;
        r.delay = r.receive_time - r.sent_time;
        results.push_back(r);

        if (n_ok == 0 || r.delay < min_delay) min_delay = r.delay;
        if (n_ok == 0 || r.delay > max_delay) max_delay = r.delay;
        sum_delay += r.delay;
        n_ok++;
    endfunction

    function int n_errors();
        return n_unexpected + n_early + n_order + n_missing;
    endfunction

    function void report();
        pull_expected();
        n_missing = 0;
        foreach (pending[rx]) begin
            foreach (pending[rx][i]) begin
                n_missing++;
                $error("[CHK] Paquete perdido %h del origen %0d hacia rx %0d",
                       pending[rx][i].tr.pack(), pending[rx][i].tr.src_terminal, rx);
            end
        end
        $display("[CHK] correctos=%0d inesperados=%0d antes_de_envio=%0d fuera_de_orden=%0d perdidos=%0d",
                 n_ok, n_unexpected, n_early, n_order, n_missing);
        if (n_ok > 0) begin
            $display("[CHK] retardo min=%0.1f prom=%0.1f max=%0.1f",
                     min_delay, sum_delay / n_ok, max_delay);
        end
    endfunction

    function void write_csv(string file_name = "reporte_retardos.csv");
        int fd;
        fd = $fopen(file_name, "w");
        if (fd == 0) begin
            $error("[CHK] No se pudo crear %s", file_name);
            return;
        end
        $fwrite(fd, "Tiempo_Envio,Terminal_Origen,Terminal_Destino,Tiempo_Recibido,Retardo,Dato\n");
        foreach (results[i]) begin
            $fwrite(fd, "%0.1f,%0d,%0d,%0.1f,%0.1f,%0h\n",
                    results[i].sent_time,
                    results[i].src,
                    results[i].rx,
                    results[i].receive_time,
                    results[i].delay,
                    results[i].data);
        end
        $fclose(fd);
        $display("[CHK] %s escrito con %0d filas", file_name, results.size());
    endfunction

endclass
