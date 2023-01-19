`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : conv_top.sv
 Create     : 2022-07-26 14:01:35
 Revise     : 2022-07-26 14:01:35
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module conv_top #(
        parameter   IMAGE_COLUMN        =   512,    //  image column size m
        parameter   IMAGE_DATA_WIDTH    =   8,
        parameter   CONV_KERNEL_SIZE    =   11,      //  Convolution kernel size n*n (n is odd)
        parameter   DIFF_WIDTH          =   14,  

        parameter   GAUSS0_1            =  8'd63,
        parameter   GAUSS0_4            =  {8'd52,8'd29,8'd10,8'd2,8'd0,8'd43,8'd13,8'd1,8'd0,8'd0},
        parameter   GAUSS0_8            =  {8'd23,8'd9, 8'd2, 8'd0,8'd5,8'd1, 8'd0, 8'd0,8'd0,8'd0}, 

        parameter   GAUSS1_1            =  8'd40,
        parameter   GAUSS1_4            =  {8'd35,8'd24,8'd44,8'd11,8'd2,8'd172,8'd53,8'd8,8'd0,8'd0},
        parameter   GAUSS1_8            =  {8'd96,8'd36,8'd9,8'd2,8'd20,8'd5,8'd1,8'd2,8'd0,8'd0}, 

        parameter   GAUSS2_1            =  8'd26,
        parameter   GAUSS2_4            =  {8'd24,8'd19,8'd13,8'd7,8'd3,8'd22,8'd14,8'd6,8'd2,8'd0},
        parameter   GAUSS2_8            =  {8'd18,8'd12,8'd7,8'd3,8'd9,8'd5,8'd2,8'd3,8'd1,8'd1}, 

        parameter   GAUSS3_1            =  8'd18,
        parameter   GAUSS3_4            =  {8'd18,8'd15,8'd12,8'd8,8'd5,8'd17,8'd12,8'd7,8'd3,8'd1},
        parameter   GAUSS3_8            =  {8'd14,8'd11,8'd8,8'd5,8'd10,8'd7,8'd4,8'd5,8'd3,8'd2}                
    )
    (
        input                                                                               axi_clk,    // Clock
        input                                                                               axi_rst,
                            
        input                                                                               kvalid,
        input   [CONV_KERNEL_SIZE-1 : 0][CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]    kernel     ,  

        output  [3:0]                                                                       conv_valid,
        output  [3:0][23:0]                                                                 conv_result,
        output  signed [2:0][DIFF_WIDTH-1:0]                                                conv_diff           
 );
 

    localparam      SYMMETRY_1          =   1;
    localparam      SYMMETRY_4          =   CONV_KERNEL_SIZE-1;
    localparam      SYMMETRY_8          =   (CONV_KERNEL_SIZE-1)*(CONV_KERNEL_SIZE-3)/8;

    logic  [SYMMETRY_1-1 : 0][IMAGE_DATA_WIDTH-1 :0]       sym1;  
    logic  [SYMMETRY_4-1 : 0][IMAGE_DATA_WIDTH+1 :0]       sym4;  
    logic  [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]       sym8_0;
    logic  [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]       sym8_1;   


    pre_add #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE)
        ) inst_pre_add (
            .axi_clk (axi_clk),
            .axi_rst (axi_rst),
            .kvalid  (kvalid),
            .kernel  (kernel),
            .svalid  (svalid),
            .sym1    (sym1),
            .sym4    (sym4),
            .sym8_0  (sym8_0),
            .sym8_1  (sym8_1)
        );

    one_conv #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .GAUSS_1(GAUSS0_1),
            .GAUSS_4(GAUSS0_4),
            .GAUSS_8(GAUSS0_8)
        ) GAUSS0 (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .svalid      (svalid),
            .sym1        (sym1),
            .sym4        (sym4),
            .sym8_0      (sym8_0),
            .sym8_1      (sym8_1),
            .conv_valid  (conv_valid[0]),
            .conv_result (conv_result[0])
        );

     one_conv #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .GAUSS_1(GAUSS1_1),
            .GAUSS_4(GAUSS1_4),
            .GAUSS_8(GAUSS1_8)
        ) GAUSS1 (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .svalid      (svalid),
            .sym1        (sym1),
            .sym4        (sym4),
            .sym8_0      (sym8_0),
            .sym8_1      (sym8_1),
            .conv_valid  (conv_valid[1]),
            .conv_result (conv_result[1])
        );

    one_conv #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .GAUSS_1(GAUSS2_1),
            .GAUSS_4(GAUSS2_4),
            .GAUSS_8(GAUSS2_8)
        ) GAUSS2 (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .svalid      (svalid),
            .sym1        (sym1),
            .sym4        (sym4),
            .sym8_0      (sym8_0),
            .sym8_1      (sym8_1),
            .conv_valid  (conv_valid[2]),
            .conv_result (conv_result[2])
        ); 

    one_conv #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .GAUSS_1(GAUSS3_1),
            .GAUSS_4(GAUSS3_4),
            .GAUSS_8(GAUSS3_8)
        ) GAUSS3 (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .svalid      (svalid),
            .sym1        (sym1),
            .sym4        (sym4),
            .sym8_0      (sym8_0),
            .sym8_1      (sym8_1),
            .conv_valid  (conv_valid[3]),
            .conv_result (conv_result[3])
        );  

    assign  conv_diff[0]    =   (conv_result[1]  -   conv_result[0]) >> 10;
    assign  conv_diff[1]    =   (conv_result[2]  -   conv_result[1]) >> 10;
    assign  conv_diff[2]    =   (conv_result[3]  -   conv_result[2]) >> 10; 

 endmodule : conv_top