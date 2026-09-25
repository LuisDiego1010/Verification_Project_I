
class transaction #(parameter int width = 16);

    // Ramdom variables are difined
    rand int delay;
    rand bit [7:0] dst_addr;
    rand bit [width-9:0] payload;

    // The control and reporting variables are defined
    int src_terminal;

    // Timelines for the CVS report
    real sent_time;
    real receive_time;


    // The randomization constraints are defined
    constraint c_size {
        width inside {16, 32, 64};
    }

    // The delay is defined as 0 to 20 clock cycles
    constraint c_delay {
        delay inside {[0:20]};
    }

    // A weight is assigned to each of the options.
    constraint c_dst_addr {
        dst_addr dist {
            [0:3]   :/ 70,
            255     := 15,
            [4:254] :/ 15
        };
    }

    // The constructor is created
    function new();
        this.sent_time = 0;
        this.receive_time = 0;
    endfunction

    // Hardware package assembly
    function bit [width-1:0] pack();
        return {dst_addr, payload};
    endfunction

    // Function to print the resulting content
    function void print(string tag = "");
        $display("[%s] Origen: %0d | Destino: %0d | Retardo: %0d | Datos: %h",
                  tag, src_terminal, dst_addr, delay, payload);
    endfunction

endclass
