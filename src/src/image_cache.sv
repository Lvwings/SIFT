`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : image_cache.sv
 Create     : 2022-07-22 13:21:03
 Revise     : 2022-07-22 13:21:03
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 /*------------------------------------------------------------------------------
 --  Convolution mode
 ------------------------------------------------------------------------------*/

 module image_cache #(
    parameter       IMAGE_COLUMN        =   512,    //  image column size m
    parameter       IMAGE_DATA_WIDTH    =   8,
    parameter       CONV_KERNEL_SIZE    =   11      //  Convolution kernel size n*n
    )
    (
    input                                                       axi_clk,
    input                                                       axi_rst,
    //  image data in                       
    input   [IMAGE_DATA_WIDTH-1 : 0]                            axis_tdata,
    input                                                       axis_tvalid,
    input                                                       axis_tlast,
    output                                                      axis_tready,
    //  to kernel shift register
    output  [CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]    shift_data,
    output  [CONV_KERNEL_SIZE-1 : 0]                            shift_valid 
 );
 
 
    logic   [CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]    axis_data;
    logic   [CONV_KERNEL_SIZE-1 : 0]                            axis_valid;
    logic   [CONV_KERNEL_SIZE-1 : 0]                            axis_ready;
    logic   [CONV_KERNEL_SIZE-1 : 0]                            axis_last;

    assign  axis_data[0]                    =   axis_tdata;
    assign  axis_valid[0]                   =   axis_tvalid;
    assign  axis_tready                     =   axis_ready[0];
    assign  axis_last[0]                    =   axis_tlast;
    assign  axis_ready[0]                   =   1;

    // function called clogb2 that returns an integer which has the 
    // value of the ceiling of the log base 2.                      
    function integer clogb2 (input integer bit_depth);              
        begin                                                           
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
              bit_depth = bit_depth >> 1;                                 
        end                                                           
    endfunction

    localparam  FIFO_DEPTH_BIT  =   clogb2(IMAGE_COLUMN-1);
    localparam  FIFO_DEPTH      =   {FIFO_DEPTH_BIT{1'b1}}+1;

    logic   [CONV_KERNEL_SIZE-2 : 0]    full ;
    logic   [CONV_KERNEL_SIZE-2 : 0]    empty;

    generate
        for (genvar i = 0; i < CONV_KERNEL_SIZE-1; i = i+1) begin  
            // xpm_fifo_axis package mode has 2 clk latency when LAST assert 
            // In xpm_fifo_sync "fwfd" mode the effective depth = FIFO_WRITE_DEPTH+2, so the FULL also has 2 clk latency
            // Using xpm_fifo_sync "std" mode almost full is exactly aligned the data pipeline
            // The RST should be valid > 100 ns  
           xpm_fifo_sync #(
              .FIFO_MEMORY_TYPE ("block"),          // String
              .USE_ADV_FEATURES ("181A"),           // String
              .FIFO_WRITE_DEPTH (FIFO_DEPTH),       // DECIMAL  min = 16
              .PROG_FULL_THRESH (IMAGE_COLUMN-3),   // 3 ~ FIFO_DEPTH-3 in "std" mode, prog_full has 1 clk latency, read has 1 clk latency
              .READ_DATA_WIDTH  (IMAGE_DATA_WIDTH), // DECIMAL  min = 8
              .WRITE_DATA_WIDTH (IMAGE_DATA_WIDTH)  // DECIMAL
           )
           fifo_cache (
                .wr_clk         (axi_clk), 
                .rst            (axi_rst),                     
            // write
                .din            (axis_data[i] ),    
                .wr_en          (axis_valid[i]), 
                .wr_ack         (),
            // read
                .dout           (axis_data[i+1]),            
                .rd_en          (axis_valid[i+1]),
                .data_valid     (axis_ready[i+1]),       
            // flag
                .empty          (empty[i]),                                                              
                .almost_full    (), 
                .prog_full      (full[i])                                                                                                                      
           );         
        end
    endgenerate

    always_ff @(posedge axi_clk) begin 
        if(axi_rst) begin
            axis_valid[CONV_KERNEL_SIZE-1 : 1] <= '0;
        end else begin
            for (int i = 0; i < CONV_KERNEL_SIZE-1; i = i+1) begin
                if (full[i])
                    axis_valid[i+1] <=  1;
                else if (empty[i])
                    axis_valid[i+1] <=  0;
                else
                    axis_valid[i+1] <=  axis_valid[i+1];
            end
        end
    end

    logic   [CONV_KERNEL_SIZE-1 : 0][CONV_KERNEL_SIZE-1 : 0]    align_valid   =   '0;

    always_ff @(posedge axi_clk) begin
        if(axi_rst) begin
            align_valid                         <= '0;
        end else begin
            for (int i = 0; i < CONV_KERNEL_SIZE-1; i = i+1) begin
                if (full[i]) begin
                    align_valid[i+1]  <=  align_valid[i+1] << 1;
                    for (int j = 0; j < (CONV_KERNEL_SIZE-1 -i); j = j+1) begin
                        align_valid[i+1][j]    <=  '1;
                    end                   
                end
                else if (empty[i])
                    align_valid[i+1]  <= '0;
                else
                    align_valid[i+1]  <=  align_valid[i+1];    
            end
        end
    end


    generate
        for (genvar i = 1; i < CONV_KERNEL_SIZE; i = i+1) begin
            assign shift_valid[i] = align_valid[i][CONV_KERNEL_SIZE-1];
        end
            assign shift_valid[0] = axis_tvalid; 
    endgenerate

    generate
        for (genvar i = 0; i < CONV_KERNEL_SIZE; i = i+1) begin
            assign  shift_data[i] =  shift_valid[i] ? axis_data[i] : '0;          
        end
    endgenerate    

 endmodule : image_cache