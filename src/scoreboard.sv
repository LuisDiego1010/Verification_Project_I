
class expected_item;
  int       rx_id;
  trans_bus tr;   // same handle the driver uses, so send time shows up later

  function new(int rx_id, trans_bus tr);
    this.rx_id = rx_id;
    this.tr    = tr;
  endfunction
endclass

// Class scoreboard. Receives transactions from the agent and forwards expected items to the checker
class scoreboard #(parameter drvs = 4);

  localparam bit [7:0] BCAST_ID = 8'hFF;

  typedef enum {DST_UNICAST, DST_BCAST, DST_INVALID} dst_kind_e;

  mailbox #(trans_bus)     agnt_sb_mbx;
  mailbox #(expected_item) sb_chkr_mbx;

  int n_unicast, n_bcast, n_invalid, n_expected;

  function new(mailbox #(trans_bus) agnt_sb_mbx,
               mailbox #(expected_item) sb_chkr_mbx);
    this.agnt_sb_mbx = agnt_sb_mbx;
    this.sb_chkr_mbx = sb_chkr_mbx;
  endfunction

  function dst_kind_e classify(bit [7:0] dst);
    if (dst == BCAST_ID) return DST_BCAST;
    if (dst < drvs)      return DST_UNICAST;
    return DST_INVALID;
  endfunction

  task add_expected(int rx_id, trans_bus tr);
    expected_item e = new(rx_id, tr);
    sb_chkr_mbx.put(e);
    n_expected++;
  endtask

  task run();
    trans_bus tr;
    forever begin
      agnt_sb_mbx.get(tr);
      case (classify(tr.destino))
        DST_UNICAST: begin
          add_expected(tr.destino, tr);
          n_unicast++;
        end
        DST_BCAST: begin
          // sender never reads its own packet (it holds the turn)
          for (int d = 0; d < drvs; d++)
            if (d != tr.origen) add_expected(d, tr);
          n_bcast++;
        end
        DST_INVALID: begin
          // nothing expected; any arrival is flagged by the checker
          n_invalid++;
        end
      endcase
    end
  endtask

  function void report();
    $display("[SB] unicast=%0d bcast=%0d invalid=%0d expected=%0d",
             n_unicast, n_bcast, n_invalid, n_expected);
  endfunction

endclass