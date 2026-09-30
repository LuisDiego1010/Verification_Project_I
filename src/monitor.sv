// Class mon_child.sv. The mon_child class is responsible for watching one terminal of the DUT: every cycle with push high it captures D_push and timestamps it as a received packet.
class mon_child #(parameter int width = 16, parameter int drvs = 4);

    virtual dut_compl_if #(width, drvs) vif;
    mailbox #(transaction #(width, drvs)) child_parent_mbx;
    int id;

    function new(
        int id,
        virtual dut_compl_if #(width, drvs) vif,
        mailbox #(transaction #(width, drvs)) child_parent_mbx
    );
        this.id = id;
        this.vif = vif;
        this.child_parent_mbx = child_parent_mbx;
    endfunction

    task run();
        transaction #(width, drvs) t;
        forever begin
            @(vif.cb_mon);
            if (vif.cb_mon.reset !== 1'b1 && vif.cb_mon.push[0][id] === 1'b1) begin
                t = new();
                t.unpack(vif.cb_mon.D_push[0][id]);
                t.rx_terminal = id;
                t.receive_time = $realtime;
                child_parent_mbx.put(t);
            end
        end
    endtask

endclass

// Class bus_monitor.sv. The bus_monitor class is responsible for starting one mon_child per terminal and forwarding everything they observe to the checker.
class bus_monitor #(parameter int width = 16, parameter int drvs = 4);

    virtual dut_compl_if #(width, drvs) vif;
    mailbox #(transaction #(width, drvs)) mon_chk_mbx;
    mailbox #(transaction #(width, drvs)) child_parent_mbx;
    mon_child #(width, drvs) children[drvs];

    function new(
        virtual dut_compl_if #(width, drvs) vif,
        mailbox #(transaction #(width, drvs)) mon_chk_mbx
    );
        this.vif = vif;
        this.mon_chk_mbx = mon_chk_mbx;
        this.child_parent_mbx = new();
        for (int i = 0; i < drvs; i++) begin
            children[i] = new(i, vif, child_parent_mbx);
        end
    endfunction

    task run();
        transaction #(width, drvs) t;
        foreach (children[i]) begin
            automatic int k = i;
            fork
                children[k].run();
            join_none
        end
        forever begin
            child_parent_mbx.get(t);
            mon_chk_mbx.put(t);
        end
    endtask

endclass
