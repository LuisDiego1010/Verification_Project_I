// Class chk_result.sv. The chk_result class is responsible for storing the result of each delivered packet for the csv report.
class chk_result;
  int src;
  int rx;
  bit [63:0] data;
  real sent_time;
  real receive_time;
  real delay;
endclass

// Class bus_checker.sv. The bus_checker class is responsible for comparing the packets observed by the monitor against the packets expected by the scoreboard, reporting unexpected, out of order and missing packets, and writing the delay of each delivered packet to a csv file.
class bus_checker #(parameter int width = 16, parameter int drvs = 4);
  mailbox #(expected_item #(width, drvs)) sb_chkr_mbx;
  mailbox #(transaction #(width, drvs)) mon_chkr_mbx;

  expected_item #(width, drvs) pending[drvs][$];
  chk_result results[$];

  int n_ok, n_unexpected, n_order, n_missing;
  real sum_delay, min_delay, max_delay;
  
  // just wiring up the mailboxes
  function new(
    mailbox #(expected_item #(width, drvs)) sb_chkr_mbx,
    mailbox #(transaction #(width, drvs)) mon_chkr_mbx
  );
    this.sb_chkr_mbx = sb_chkr_mbx;
    this.mon_chkr_mbx = mon_chkr_mbx;
  endfunction
  // grabs whatever new expected packets the sb threw at us and queues them up by rx id
  function void pull_expected();
    expected_item #(width, drvs) e;
    while (sb_chkr_mbx.try_get(e)) begin
      pending[e.rx_id].push_back(e);
    end
  endfunction

  // main loop fetching actual observations from the monitor and firing the check
  task run();
    transaction #(width, drvs) obs;
    forever begin
      mon_chkr_mbx.get(obs);
      pull_expected();
      check(obs);
    end
  endtask

  function void check(transaction #(width, drvs) obs);
    int rx = obs.rx_terminal;
    int idx = -1;
    expected_item #(width, drvs) e;
    chk_result r;

    for (int i = 0; i < pending[rx].size(); i++) begin
      if (pending[rx][i].tr.pack() != obs.pack()) continue;
      if (pending[rx][i].tr.sent_time < 0) continue;
      if (idx < 0 || pending[rx][i].tr.sent_time < pending[rx][idx].tr.sent_time) begin
        idx = i;
      end
    end

    if (idx < 0) begin
      n_unexpected++;
      $error("[CHK] unexpected %h at rx %0d, t=%0t", obs.pack(), rx, obs.receive_time);
      return;
    end

    e = pending[rx][idx];
    if (e.tr.sent_time < 0) $warning("[CHK] %h arrived with no sent_time", obs.pack());

    // marking the overtaken flag so we only yell about an out of order packet once. cascade errors suck to debug
    begin
      bit found_order_error = 0;
      for (int j = 0; j < pending[rx].size(); j++) begin
        expected_item #(width, drvs) p = pending[rx][j];
        if (j != idx && !p.overtaken && p.tr.src_terminal == e.tr.src_terminal
            && p.tr.sent_time > 0 && p.tr.sent_time < e.tr.sent_time) begin
          p.overtaken = 1;
          found_order_error = 1;
        end
      end
      if (found_order_error) begin
        n_order++;
        $error("[CHK] out of order: %h en rx %0d (adelanto a un paquete anterior de la terminal %0d)",
               obs.pack(), rx, e.tr.src_terminal);
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
    if (r.delay > max_delay) max_delay = r.delay;
    sum_delay += r.delay; n_ok++;
  endfunction

  // sanity check to see if we are completely done processing everything
  function bit idle();
    pull_expected();
    for (int rx = 0; rx < drvs; rx++) begin
      if (pending[rx].size() > 0) return 0;
    end
    return 1;
  endfunction

  // returns total error count for the test
  function int errors();
    return n_unexpected + n_order + n_missing;
  endfunction

  // prints out the final stats and screams about any missing packets left over
  function void report();
    pull_expected();
    for (int rx = 0; rx < drvs; rx++) begin
      for (int i = 0; i < pending[rx].size(); i++) begin
        n_missing++;
        $error("[CHK] missing %h", pending[rx][i].tr.pack());
      end
    end
    $display("[CHK] ok=%0d unexpected=%0d out_of_order=%0d missing=%0d", n_ok, n_unexpected, n_order, n_missing);

    if (n_ok > 0) begin
      $display("[CHK] retardo min=%0.2f prom=%0.2f max=%0.2f (ns)",
               min_delay, sum_delay / n_ok, max_delay);
    end
  endfunction

  // dumps all the delay stats into a csv file so the bash script can plot it later
  function void write_csv(string filename);
    int csv_file;

    csv_file = $fopen(filename, "w");

    if (csv_file) begin
      $fwrite(csv_file, "Tiempo_Envio,Terminal_Origen,Terminal_Destino,Tiempo_Recibido,Retardo\n");

      foreach (results[i]) begin
        $fwrite(csv_file, "%0.2f,%0d,%0d,%0.2f,%0.2f\n",
                results[i].sent_time,
                results[i].src,
                results[i].rx,
                results[i].receive_time,
                results[i].delay);
      end

      $fclose(csv_file);
      $display("[CHK] Archivo %s generado con %0d registros", filename, results.size());
    end else begin
      $error("[CHK] No se pudo crear el archivo %s", filename);
    end
  endfunction

endclass
