// Class mon_hijo.sv. The mon_hijo class is responsible for monitoring a specific driver and sending transactions to the monitor.
class mon_hijo #(parameter drvs = 4, parameter pckg_sz = 16);

  virtual bus_if #(.drvs(drvs), .pckg_sz(pckg_sz)) vif;
  mailbox #(trans_bus) hijo_padre_mbx;
  int id;

  function new(
    int id,
    virtual bus_if #(.drvs(drvs), .pckg_sz(pckg_sz)) vif,
    mailbox #(trans_bus) hijo_padre_mbx
  );
    this.id = id;
    this.vif = vif;
    this.hijo_padre_mbx = hijo_padre_mbx;
  endfunction

  task run();
    trans_bus t;

    forever begin
      @(posedge vif.clk);

      if (vif.push[id]) begin
        t = new();

        t.data = vif.D_push[id];
        t.receiver = id;
        t.time = $time;

        hijo_padre_mbx.put(t);
      end
    end
  endtask

endclass

// Class monitor.sv. The monitor class is responsible for monitoring the bus interface and collecting transactions from the drivers. The mon_hijo class is responsible for monitoring a specific driver and sending transactions to the monitor.
class monitor #(parameter drvs = 4, parameter pckg_sz = 16);

  virtual bus_if #(.drvs(drvs), .pckg_sz(pckg_sz)) vif;
  mailbox #(trans_bus) mon_chkr_mbx;
  mailbox #(trans_bus) hijo_padre_mbx;

  mon_hijo #(drvs, pckg_sz) hijos[drvs];

  function new(
    virtual bus_if #(.drvs(drvs), .pckg_sz(pckg_sz)) vif,
    mailbox #(trans_bus) mon_chkr_mbx
  );
    this.vif = vif;
    this.mon_chkr_mbx = mon_chkr_mbx;

    hijo_padre_mbx = new();

    for (int i = 0; i < drvs; i++) begin
      hijos[i] = new(i, vif, hijo_padre_mbx);
    end
  endfunction

  task run();

    for (int i = 0; i < drvs; i++) begin
      automatic int k = i;

      fork
        hijos[k].run();
      join_none
    end

    forever begin
      trans_bus t;

      hijo_padre_mbx.get(t);
      mon_chkr_mbx.put(t);
    end

  endtask

endclass