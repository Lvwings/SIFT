
`timescale 1ns/1ps

module tb_shift_register (); /* this is automatically generated */

    // clock
    logic clk;
    initial begin
        clk = '0;
        forever #(0.5) clk = ~clk;
    end

    // synchronous reset
    logic srstb;
    initial begin
        srstb <= '1;
        repeat(10)@(posedge clk);
        srstb <= '0;
    end

    // (*NOTE*) replace reset, clock, others

    parameter  DATA_WIDTH = 8;
    parameter SHIFT_DEPTH = 16;
    parameter RESET_VALUE = {DATA_WIDTH{1'b0}};

    logic                    rst;
    logic [DATA_WIDTH-1 : 0] data_in;
    logic [DATA_WIDTH-1 : 0] data_out [SHIFT_DEPTH-1 : 0];

    shift_register #(
            .DATA_WIDTH(DATA_WIDTH),
            .SHIFT_DEPTH(SHIFT_DEPTH),
            .RESET_VALUE(RESET_VALUE)
        ) inst_shift_register (
            .clk      (clk),
            .rst      (rst),
            .data_in  (data_in),
            .data_out (data_out)
        );

    task init();
        rst     <= '0;
        data_in <= '0;
    endtask


    initial begin
        // do something

        init();

    end

    reg [7:0]   a ='0;

    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++) begin
                a[i*(i+1)/2] <= 1;
        end

    end
    
endmodule
