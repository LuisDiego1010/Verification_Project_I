// Class expected_item.sv. The expected_item class is responsible for pairing a reference transaction with the terminal that must receive it.
class expected_item #(parameter int width = 16, parameter int drvs = 4);

    int rx_id;
    transaction #(width, drvs) tr;
    // Set by the checker when a newer packet of the same source reached
    // this receiver first
    bit overtaken;

    function new(
        int rx_id,
        transaction #(width, drvs) tr
    );
        this.rx_id = rx_id;
        this.tr = tr;
        this.overtaken = 0;
    endfunction

endclass

// Class bus_scoreboard.sv. The bus_scoreboard class is responsible for the reference model of the bus: for every transaction it computes which terminals must receive it and sends one expectation per receiver to the checker.
class bus_scoreboard #(parameter int width = 16, parameter int drvs = 4);

    typedef enum {DST_UNICAST, DST_BCAST, DST_INVALID, DST_SELF} dst_kind_e;

    mailbox #(transaction #(width, drvs)) agent_sb_mbx;
    mailbox #(expected_item #(width, drvs)) sb_chk_mbx;
    // Address treated as broadcast by the reference model (set by the test)
    bit [7:0] bcast_id;

    int n_unicast;
    int n_bcast;
    int n_invalid;
    int n_self;
    int n_expected;

    function new(
        mailbox #(transaction #(width, drvs)) agent_sb_mbx,
        mailbox #(expected_item #(width, drvs)) sb_chk_mbx
    );
        this.agent_sb_mbx = agent_sb_mbx;
        this.sb_chk_mbx = sb_chk_mbx;
        this.bcast_id = 8'hFF;
    endfunction

    function dst_kind_e classify(transaction #(width, drvs) tr);
        if (tr.dst_addr == bcast_id) return DST_BCAST;
        if (tr.dst_addr >= drvs) return DST_INVALID;
        // The sender holds the bus, so it never reads its own packet.
        if (tr.dst_addr == tr.src_terminal) return DST_SELF;
        return DST_UNICAST;
    endfunction

    function void add_expected(int rx_id, transaction #(width, drvs) tr);
        expected_item #(width, drvs) e = new(rx_id, tr);
        void'(sb_chk_mbx.try_put(e));
        n_expected++;
    endfunction

    task run();
        transaction #(width, drvs) tr;
        forever begin
            agent_sb_mbx.get(tr);
            case (classify(tr))
                DST_UNICAST: begin
                    add_expected(tr.dst_addr, tr);
                    n_unicast++;
                end
                DST_BCAST: begin
                    for (int d = 0; d < drvs; d++) begin
                        if (d != tr.src_terminal) add_expected(d, tr);
                    end
                    n_bcast++;
                end
                DST_INVALID: n_invalid++;
                DST_SELF: n_self++;
            endcase
        end
    endtask

    function void report();
        $display("[SB] unicast=%0d broadcast=%0d invalidos=%0d a_si_mismo=%0d recepciones_esperadas=%0d",
                 n_unicast, n_bcast, n_invalid, n_self, n_expected);
    endfunction

endclass
