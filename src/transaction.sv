// Class transaction.sv. The transaction class is responsible for describing one packet of the bus: the randomized fields that the generator produces, the bit-level format the DUT expects (destination in the 8 MSBs, payload in the remaining bits) and the timestamps used by the checker and the CSV.
class transaction #(parameter int width = 16, parameter int drvs = 4);

    typedef enum {K_UNICAST, K_BCAST, K_INVALID} dst_kind_e;

    // Randomized fields
    rand int unsigned delay;
    rand int unsigned src_terminal;
    rand bit [7:0] dst_addr;
    rand bit [width-9:0] payload;
    // Kind of destination, chosen first with the percentages below
    rand dst_kind_e kind;
    // Picks the first invalid address, the last one or any other
    rand int unsigned inv_sel;

    // Knobs copied from the generator before randomize so the test can control the traffic
    int unsigned min_delay;
    int unsigned max_delay;
    int unsigned pct_bcast;
    int unsigned pct_inv;
    bit [7:0] bcast_id;
    // When set, forces every unicast packet to be addressed to its own source terminal
    bit force_self;

    // Control and reporting fields not randomized
    // metadata to hold simulation info
    int rx_terminal;
    real sent_time;
    real receive_time;

    // Idle cycles before the packet enters the source FIFO
    constraint c_delay {
        delay inside {[min_delay:max_delay]};
    }

    // The source must be one of the connected terminals
    constraint c_src {
        src_terminal inside {[0:drvs-1]};
    }

    // sorting out the traffic composition
    constraint c_kind {
        kind dist {
            K_UNICAST := 100 - pct_bcast - pct_inv,
            K_BCAST := pct_bcast,
            K_INVALID := pct_inv
        };
    }

    // linking the address logic to whatever kind of packet the solver picked first
    // adding weight to first/last invalid addresses to hit bounds easier
    constraint c_dst_addr {
        (kind == K_UNICAST) -> dst_addr inside {[0:drvs-1]};
        (kind == K_BCAST) -> dst_addr == bcast_id;
        (kind == K_INVALID) -> !(dst_addr inside {[0:drvs-1]}) && dst_addr != bcast_id;
        inv_sel dist {0 := 10, 1 := 10, 2 := 80};
        (kind == K_INVALID && inv_sel == 0) -> dst_addr == drvs;
        (kind == K_INVALID && inv_sel == 1) -> dst_addr == 254;
    }

    // stopping standard packets from hitting their own source since the dut logic breaks there
    constraint c_no_self {
        (!force_self) -> dst_addr != src_terminal;
    }

    // Directed corner case: force self-addressing on every unicast packet
    constraint c_force_self {
        (force_self && kind == K_UNICAST) -> dst_addr == src_terminal;
    }

    function new();
        // Defaults same traffic mix as the base test
        this.min_delay = 0;
        this.max_delay = 20;
        this.pct_bcast = 15;
        this.pct_inv = 15;
        this.bcast_id = 8'hFF;
        this.force_self = 0;
        this.rx_terminal = -1;
        this.sent_time = -1;
        this.receive_time = -1;
    endfunction

    // Builds the word that the DUT reads from D_pop
    function bit [width-1:0] pack();
        return {dst_addr, payload};
    endfunction

    // Rebuilds the fields from the word that the DUT writes on D_push
    function void unpack(bit [width-1:0] data);
        this.dst_addr = data[width-1:width-8];
        this.payload = data[width-9:0];
    endfunction

    function void print(string tag = "");
        $display("[%s] origen=%0d destino=%0d retardo=%0d dato=%h",
                 tag, src_terminal, dst_addr, delay, payload);
    endfunction

endclass
