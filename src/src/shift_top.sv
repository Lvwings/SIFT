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
 --  Convolution valid mode
 ------------------------------------------------------------------------------*/

module shift_top #(
    parameter       IMAGE_COLUMN        =   512,    //  image column size m
    parameter       IMAGE_DATA_WIDTH    =   8,
    parameter       CONV_KERNEL_SIZE    =   11,      //  Convolution kernel size n*n
    parameter       EXTREME_KERNEL_SIZE =   3,
    parameter       DIFF_WIDTH          =   14,

    parameter       GAUSS0_1            =  8'd63,
    parameter       GAUSS0_4            =  {8'd52,8'd29,8'd10,8'd2,8'd0,8'd43,8'd13,8'd1,8'd0,8'd0},
    parameter       GAUSS0_8            =  {8'd23,8'd9, 8'd2, 8'd0,8'd5,8'd1, 8'd0, 8'd0,8'd0,8'd0}, 

    parameter       GAUSS1_1            =  8'd40,
    parameter       GAUSS1_4            =  {8'd35,8'd24,8'd13,8'd5,8'd1,8'd31,8'd15,8'd4,8'd0,8'd0},
    parameter       GAUSS1_8            =  {8'd21,8'd11,8'd5,8'd1,8'd8,8'd3,8'd1,8'd1,8'd0,8'd0}, 

    parameter       GAUSS2_1            =  8'd26,
    parameter       GAUSS2_4            =  {8'd24,8'd19,8'd13,8'd7,8'd3,8'd22,8'd14,8'd6,8'd2,8'd0},
    parameter       GAUSS2_8            =  {8'd18,8'd12,8'd7,8'd3,8'd9,8'd5,8'd2,8'd3,8'd1,8'd1}, 

    parameter       GAUSS3_1            =  8'd18,
    parameter       GAUSS3_4            =  {8'd18,8'd15,8'd12,8'd8,8'd5,8'd17,8'd12,8'd7,8'd3,8'd1},
    parameter       GAUSS3_8            =  {8'd14,8'd11,8'd8,8'd5,8'd10,8'd7,8'd4,8'd5,8'd3,8'd2}  
       
    )(
    input                                                           axi_clk,
    input                                                           axi_rst,
    //  image data in                                           
    input   [IMAGE_DATA_WIDTH-1 : 0]                                axis_tdata,
    input                                                           axis_tvalid,
    input                                                           axis_tlast,
    output                                                          axis_tready,
    //  conv result
    output  [3:0]                                                   conv_valid,
    output  [3:0][23:0]                                             conv_result,
    output  signed [EXTREME_KERNEL_SIZE-1:0][DIFF_WIDTH-1:0]        conv_diff,
    output                                                          key_valid,
    output                                                          key_mark
);
    
    wire [CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]                           shift_data;
    wire [CONV_KERNEL_SIZE-1 : 0]                                                   shift_valid; 
    wire [CONV_KERNEL_SIZE-1 : 0][CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]   kernel      ;

    image_cache #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE)
        ) inst_image_cache (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .axis_tdata  (axis_tdata),
            .axis_tvalid (axis_tvalid),
            .axis_tlast  (axis_tlast),
            .axis_tready (axis_tready),
            .shift_data  (shift_data),
            .shift_valid (shift_valid)
        );

    kernel_shift_data #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .CONV_MODE("same")
        ) inst_kernel_shift_data (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .shift_valid (shift_valid),
            .shift_data  (shift_data),
            .kvalid      (kvalid),
            .kernel      (kernel)
        );


    conv_top #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .GAUSS0_1(GAUSS0_1),
            .GAUSS0_4(GAUSS0_4),
            .GAUSS0_8(GAUSS0_8),
            .GAUSS1_1(GAUSS1_1),
            .GAUSS1_4(GAUSS1_4),
            .GAUSS1_8(GAUSS1_8),
            .GAUSS2_1(GAUSS2_1),
            .GAUSS2_4(GAUSS2_4),
            .GAUSS2_8(GAUSS2_8),
            .GAUSS3_1(GAUSS3_1),
            .GAUSS3_4(GAUSS3_4),
            .GAUSS3_8(GAUSS3_8)
        ) inst_conv_top (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .kvalid      (kvalid),
            .kernel      (kernel),
            .conv_valid  (conv_valid),
            .conv_result (conv_result),
            .conv_diff   (conv_diff)
        );


    extreme_top #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .EXTREME_KERNEL_SIZE(EXTREME_KERNEL_SIZE),
            .DIFF_WIDTH(DIFF_WIDTH)
        ) inst_extreme_top (
            .axi_clk    (axi_clk),
            .axi_rst    (axi_rst),
            .conv_valid (conv_valid[EXTREME_KERNEL_SIZE-1:0]),
            .conv_diff  (conv_diff),
            .key_valid  (key_valid),
            .key_mark   (key_mark)
        );

endmodule : shift_top