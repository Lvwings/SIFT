`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : extreme_top.sv
 Create     : 2022-08-09 15:11:07
 Revise     : 2022-08-09 15:11:07
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module extreme_top #(
    parameter       IMAGE_COLUMN        =   512,    //  image column size m
    parameter       EXTREME_KERNEL_SIZE =   3,      //  extreme kernel size 3*3*3  
    parameter       DIFF_WIDTH          =   14   
    )(
    input                                                                               axi_clk,    // Clock
    input                                                                               axi_rst,    // active high
    input          [EXTREME_KERNEL_SIZE-1:0]                                            conv_valid,
    input   signed [EXTREME_KERNEL_SIZE-1:0][DIFF_WIDTH-1:0]                            conv_diff,
    output                                                                              key_valid,
    output                                                                              key_mark
     
 );
 
    logic   signed  [EXTREME_KERNEL_SIZE-1:0][EXTREME_KERNEL_SIZE-1:0][DIFF_WIDTH-1:0]  shift_data;
    logic           [EXTREME_KERNEL_SIZE-1:0][EXTREME_KERNEL_SIZE-1:0]                  shift_valid;

    logic   signed  [EXTREME_KERNEL_SIZE-1:0][EXTREME_KERNEL_SIZE-1:0][DIFF_WIDTH-1:0]  extreme_kernel  [EXTREME_KERNEL_SIZE-1:0];
    logic           [EXTREME_KERNEL_SIZE-1:0]                                           extreme_valid;

    generate
        for (genvar i = 0; i < EXTREME_KERNEL_SIZE; i = i+1) begin : conv_diff_cache
                image_cache #(
                    .IMAGE_COLUMN(IMAGE_COLUMN),
                    .IMAGE_DATA_WIDTH(DIFF_WIDTH),
                    .CONV_KERNEL_SIZE(EXTREME_KERNEL_SIZE)
                ) conv_diff_cache (
                    .axi_clk     (axi_clk),
                    .axi_rst     (axi_rst),
                    .axis_tdata  (conv_diff[i]),
                    .axis_tvalid (conv_valid[i]),
                    .axis_tlast  (),
                    .axis_tready (),
                    .shift_data  (shift_data[i]),
                    .shift_valid (shift_valid[i])
                );
        end
    endgenerate

    generate
        for (genvar i = 0; i < EXTREME_KERNEL_SIZE; i = i+1) begin : conv_diff_shift
                kernel_shift_data #(
                    .IMAGE_COLUMN(IMAGE_COLUMN),
                    .IMAGE_DATA_WIDTH(DIFF_WIDTH),
                    .CONV_KERNEL_SIZE(EXTREME_KERNEL_SIZE),
                    .PAD(EXTREME_KERNEL_SIZE-1),
                    .CONV_MODE("valid")
                ) conv_diff_shift (
                    .axi_clk     (axi_clk),
                    .axi_rst     (axi_rst),
                    .shift_valid (shift_valid[i]),
                    .shift_data  (shift_data[i]),
                    .kvalid      (extreme_valid[i]),
                    .kernel      (extreme_kernel[i])
                );
        end
    endgenerate

    extreme_find #(
        .IMAGE_COLUMN(IMAGE_COLUMN),
        .EXTREME_KERNEL_SIZE(EXTREME_KERNEL_SIZE),
        .DIFF_WIDTH(DIFF_WIDTH)
    ) inst_extreme_find (
        .axi_clk        (axi_clk),
        .axi_rst        (axi_rst),
        .extreme_valid  (extreme_valid),
        .extreme_kernel (extreme_kernel),
        .key_valid      (key_valid),
        .key_mark       (key_mark)
    );


 endmodule : extreme_top