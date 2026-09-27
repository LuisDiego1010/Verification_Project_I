// Class chk_result.sv. The chk_result class stores the result of each delivered packet for the csv report.
class chk_result;

  int src;
  int rx;
  bit [63:0] data;
  real sent_time;
  real receive_time;
  real delay;

endclass

// Class bus_checker.sv. The bus_checker class is responsible for comparing the packets observed by the monitor against the packets expected by the scoreboard. It reports unexpected, out of order and missing packets, and calculates the delay of each delivered packet.
class bus_checker #(parameter drvs = 4, parameter width = 16);

  mailbox #(expected_item #(width)) sb_chkr_mbx;
  mailbox #(transaction #(width)) mon_chkr_mbx;

  expected_item #(width) pending[drvs][$];
  chk_result results[$];

  int n_ok, n_unexpected, n_order, n_missing;
  real sum_delay, min_delay, max_delay;

  function new(
    mailbox #(expected_item #(width)) sb_chkr_mbx,
    mailbox #(transaction #(width)) mon_chkr_mbx
  );
    this.sb_chkr_mbx = sb_chkr_mbx;
    this.mon_chkr_mbx = mon_chkr_mbx;
  endfunction

  function void pull_expected();
    expected_item #(width) e;

    while (sb_chkr_mbx.try_get(e)) begin
      pending[e.rx_id].push_back(e);
    end
  endfunction

  task run();
    transaction #(width) obs;

    forever begin
      mon_chkr_mbx.get(obs);

      pull_expected();
      check(obs);
    end
  endtask

  function void check(transaction #(width) obs);
    int rx = obs.rx_terminal;
    int idx = -1;
    expected_item #(width) e;
    chk_result r;

    for (int i = 0; i < pending[rx].size(); i++) begin
      if (pending[rx][i].tr.pack() == obs.pack()) begin
        idx = i;
        break;
      end
    end

    if (idx < 0) begin
      n_unexpected++;
      $error("[CHK] unexpected %h at rx %0d, t=%0t", obs.pack(), rx, obs.receive_time);
      return;
    end

    e = pending[rx][idx];

    if (e.tr.sent_time == 0) begin
      $warning("[CHK] %h arrived with no sent_time, check the driver", obs.pack());
    end

    for (int j = 0; j < pending[rx].size(); j++) begin
      transaction #(width) o = pending[rx][j].tr;

      if (j != idx && o.src_terminal == e.tr.src_terminal && o.sent_time > 0 && o.sent_time < e.tr.sent_time) begin
        n_order++;
        $error("[CHK] out of order: %h from %0d to rx %0d, t=%0t", obs.pack(), e.tr.src_terminal, rx, obs.receive_time);
        break;
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

    sum_delay += r.delay;
    n_ok++;
  endfunction

  function void flush();
    pull_expected();

    for (int rx = 0; rx < drvs; rx++) begin
      pending[rx].delete();
    end
  endfunction

  function void report();
    pull_expected();

    for (int rx = 0; rx < drvs; rx++) begin
      for (int i = 0; i < pending[rx].size(); i++) begin
        n_missing++;
        $error("[CHK] missing %h from %0d to rx %0d", pending[rx][i].tr.pack(), pending[rx][i].tr.src_terminal, rx);
      end
    end

    $display("[CHK] ok=%0d unexpected=%0d out_of_order=%0d missing=%0d", n_ok, n_unexpected, n_order, n_missing);

    if (n_ok > 0) begin
      $display("[CHK] delay min=%0t avg=%0t max=%0t", min_delay, sum_delay / n_ok, max_delay);
    end
  endfunction

endclass