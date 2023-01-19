`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : pre_add.sv
 Create     : 2022-07-26 14:06:47
 Revise     : 2022-07-26 14:06:47
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module pre_add #(
        parameter       IMAGE_COLUMN        =   512,    //  image column size m
        parameter       IMAGE_DATA_WIDTH    =   8,
        parameter       CONV_KERNEL_SIZE    =   11,      //  Convolution kernel size n*n (n is odd)  
        localparam      SYMMETRY_1          =   1,
        localparam      SYMMETRY_4          =   CONV_KERNEL_SIZE-1,
        localparam      SYMMETRY_8          =   (CONV_KERNEL_SIZE-1)*(CONV_KERNEL_SIZE-3)/8            
    )(
        input                                                                           axi_clk,    // Clock
        input                                                                           axi_rst,
                            
        input                                                                           kvalid,
        input [CONV_KERNEL_SIZE-1 : 0][CONV_KERNEL_SIZE-1 : 0][IMAGE_DATA_WIDTH-1 : 0]  kernel     , 

        output                                                                          svalid,
        output  [SYMMETRY_1-1 : 0][IMAGE_DATA_WIDTH-1 :0]                               sym1,  
        output  [SYMMETRY_4-1 : 0][IMAGE_DATA_WIDTH+1 :0]                               sym4,  
        output  [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]                               sym8_0,
        output  [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]                               sym8_1     
 );

 
    /*------------------------------------------------------------------------------
    --  kernel matrix simplify
        kernel matrix is rotate symmetry, so we can pre-add the Symmetrical data to
        reduce the dsp cost.

        For 5x5 kernel matrix can be simplified :
        (4)
        (8) (4)
        (4) (4) (1)
        - () indecate the number of the Symmetrical data
        - (1) locates in the center of matrix

        For nxn kernel matrix, the number of () 
        (1) = 1
        (4) = n-1
        (8) = (n-1)(n-3)/8

        Symmetrical data and kernel matrix mapping, take 7x7 kernel matrix for example: 
        (sym4_data(0))   
        (sym8_data(0)) (sym4_data(1))  
        (sym8_data(1)) (sym8_data(2)) (sym4_data(2))
        (sym4_data(3)) (sym4_data(4)) (sym4_data(5)) (sym1_data(0)) 
    ------------------------------------------------------------------------------*/

    //  to Simplify expression
    localparam  KSIZE       =   CONV_KERNEL_SIZE-1;     //  kernel matrix [KSIZE:0][KSIZE:0]
    localparam  AXIS        =   SYMMETRY_4/2;           //  axis location
    localparam  RSYM8       =   (CONV_KERNEL_SIZE-3)/2; //  row number of sym8_data

    logic   [SYMMETRY_1-1 : 0][IMAGE_DATA_WIDTH-1 :0]  sym1_data    = '0;
    logic   [SYMMETRY_4-1 : 0][IMAGE_DATA_WIDTH+1 :0]  sym4_data    = '0;
    logic   [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]  sym8_data_0  = '0;   //  seperate to reduce add
    logic   [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]  sym8_data_1  = '0; 


    always_ff @(posedge axi_clk) begin 
        if(axi_rst) begin
          sym1_data[0]    <= '0;
        end else begin
          sym1_data[0]    <=  kernel[KSIZE/2][KSIZE/2];
        end
    end  

    always_ff @(posedge axi_clk) begin 
        if(axi_rst) begin
             sym4_data    <=  '0;
        end else begin
            //  diagonal data
            for (int i = 0; i < AXIS; i = i+1) begin
                sym4_data[i]    <=  kernel[i][i]                + kernel[i][KSIZE-i]
                                +   kernel[KSIZE-i][KSIZE-i]    + kernel[KSIZE-i][i];  
            end  
            //  axis data
            for (int i = AXIS; i < SYMMETRY_4; i = i+1) begin
                sym4_data[i]    <=  kernel[AXIS][i-AXIS]    + kernel[AXIS][KSIZE-(i-AXIS)] 
                                +   kernel[i-AXIS][AXIS]    + kernel[KSIZE-(i-AXIS)][AXIS];   
            end                                                              
        end
    end

    always_ff @(posedge axi_clk) begin
        if(axi_rst) begin
            sym8_data_0    <=  '0;
            sym8_data_1    <=  '0;
        end else begin
            for (int i = 1; i <= RSYM8; i = i+1) begin 
                for (int j = 0; j <= i-1; j = j+1) begin
                        sym8_data_0[i*(i-1)/2+j]  <=  kernel[i][j] + kernel[KSIZE-i][j] + kernel[i][KSIZE-j] + kernel[KSIZE-i][KSIZE-j];
                        sym8_data_1[i*(i-1)/2+j]  <=  kernel[j][i] + kernel[j][KSIZE-i] + kernel[KSIZE-j][i] + kernel[KSIZE-j][KSIZE-i];                            
                end                                 
            end            
        end
    end    
 
    assign  sym1    =   sym1_data;
    assign  sym4    =   sym4_data;
    assign  sym8_0  =   sym8_data_0;
    assign  sym8_1  =   sym8_data_1;
    assign  svalid  =   kvalid;

 endmodule : pre_add