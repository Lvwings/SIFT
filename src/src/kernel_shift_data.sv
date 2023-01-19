`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : kernel_shift_data.sv
 Create     : 2022-07-22 14:13:49
 Revise     : 2022-07-22 14:13:49
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module kernel_shift_data #(
    parameter       IMAGE_COLUMN        =   512,     //  image column size m
    parameter       IMAGE_DATA_WIDTH    =   8,
    parameter       CONV_KERNEL_SIZE    =   11,      //  Convolution kernel size n*n (n is odd)
    parameter       PAD                 =   5,        //  (SHIFT_DEPTH-1)/2 -> target data in the center of kernel
    parameter       CONV_MODE           =   "same"  //  "same" "valid" "full"
    )
 (
    input                                                                               axi_clk,    // Clock
    input                                                                               axi_rst,    // active high
                                                
    input   [CONV_KERNEL_SIZE-1 : 0]                                                    shift_valid,
    input   [CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]                            shift_data,
        
    output                                                                              kvalid,
    output  [CONV_KERNEL_SIZE-1 : 0][CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]    kernel                                     

 );
 
    logic   [CONV_KERNEL_SIZE-1 : 0]    valid;
    //  kernel matrix Convolution 

    generate
        for (genvar i = 0; i < CONV_KERNEL_SIZE; i = i+1) begin

            shift_register #(
                .IMAGE_COLUMN(IMAGE_COLUMN),
                .DATA_WIDTH(IMAGE_DATA_WIDTH),
                .SHIFT_DEPTH(CONV_KERNEL_SIZE),
                .PAD(PAD),
                .RESET_VALUE({IMAGE_DATA_WIDTH{1'b0}})
            ) inst_shift_register (
                .clk      (axi_clk),
                .rst      (axi_rst),
                .valid_in (shift_valid[i]),
                .data_in  (shift_data[i]),
                .valid_out(valid[i]),
                .data_out (kernel[i])   
            );
        end
    endgenerate
/*------------------------------------------------------------------------------
--  "same"  (CONV_KERNEL_SIZE = 5)
    delay for (CONV_KERNEL_SIZE-1)/2 clk to align data channel
    valid   : ________`````````
    ch4     : ...0  0  0  0  0 ...
    ch3     : ...0  0  0  0  0 ...
    ch2     : ...0  0 D0 D1 D2 ...    
    ch1     : ...0  0 D0 D1 D2 ...
    ch0     : ...0  0 D0 D1 D2 ...
------------------------------------------------------------------------------*/  
/*------------------------------------------------------------------------------
--  "valid" (CONV_KERNEL_SIZE = 5)
    delay for (CONV_KERNEL_SIZE-1) clk to align data channel
    valid   : _______________`````
    ch4     : ...D0 D1 D2 D3 D4 ...
    ch3     : ...D0 D1 D2 D3 D4 ...
    ch2     : ...D0 D1 D2 D3 D4 ...    
    ch1     : ...D0 D1 D2 D3 D4 ...
    ch0     : ...D0 D1 D2 D3 D4 ...
------------------------------------------------------------------------------*/

    generate
        if (CONV_MODE == "same")
            assign  kvalid  =   valid[(CONV_KERNEL_SIZE-1)/2];
        else if (CONV_MODE == "valid")
            assign  kvalid  =   valid[CONV_KERNEL_SIZE-1] && shift_valid[0];
    endgenerate

 endmodule : kernel_shift_data