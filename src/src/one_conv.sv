`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : one_conv.sv
 Create     : 2022-07-26 13:28:12
 Revise     : 2022-07-26 13:28:12
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module one_conv #(
        parameter       IMAGE_COLUMN        =   512,    //  image column size m
        parameter       IMAGE_DATA_WIDTH    =   8,
        parameter       CONV_KERNEL_SIZE    =   11,      //  Convolution kernel size n*n (n is odd)   
        localparam      SYMMETRY_1          =   1,
        localparam      SYMMETRY_4          =   CONV_KERNEL_SIZE-1,
        localparam      SYMMETRY_8          =   (CONV_KERNEL_SIZE-1)*(CONV_KERNEL_SIZE-3)/8,
        parameter       [SYMMETRY_1-1 : 0][IMAGE_DATA_WIDTH-1 :0] GAUSS_1  =  8'd255,
        parameter       [SYMMETRY_4-1 : 0][IMAGE_DATA_WIDTH-1 :0] GAUSS_4  =  {8'd210,8'd117,8'd44,8'd11,8'd2,8'd172,8'd53,8'd8,8'd0,8'd0},
        parameter       [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH-1 :0] GAUSS_8  =  {8'd96,8'd36,8'd9,8'd2,8'd20,8'd5,8'd1,8'd2,8'd0,8'd0}    
    )
    (
        input                                               axi_clk,    // Clock
        input                                               axi_rst,
    
        input                                               svalid,
        input  [SYMMETRY_1-1 : 0][IMAGE_DATA_WIDTH-1 :0]    sym1,  
        input  [SYMMETRY_4-1 : 0][IMAGE_DATA_WIDTH+1 :0]    sym4,  
        input  [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]    sym8_0,
        input  [SYMMETRY_8-1 : 0][IMAGE_DATA_WIDTH+1 :0]    sym8_1,        

        output                                              conv_valid,
        output  [23:0]                                      conv_result       
 );


    //  1 clk latency
    logic   [SYMMETRY_1-1 : 0][16:0]  sum1;
    generate
        for (genvar i = 0; i < SYMMETRY_1; i = i+1) begin : SUM1
            DSP_AB SUM1 (
              .CLK(axi_clk),  // input wire CLK
              .A({{(17-(IMAGE_DATA_WIDTH-1)){1'b0}},sym1[i]}),    // input wire [17 : 0] A
              .B({10'h0,GAUSS_1[i]}),      // input wire [17 : 0] B
              .P(sum1[i])  // output wire [35 : 0] P
            );
        end
    endgenerate

    //  1 clk latency
    logic   [SYMMETRY_4-1 : 0][18:0]  sum4;
    generate
        for (genvar i = 0; i < SYMMETRY_4; i = i+1) begin : SUM4
            DSP_AB SUM4 (
              .CLK(axi_clk),  // input wire CLK
              .A({{(17-(IMAGE_DATA_WIDTH+1)){1'b0}},sym4[i]}),    // input wire [17 : 0] A
              .B({10'h0,GAUSS_4[i]}),      // input wire [17 : 0] B
              .P(sum4[i])  // output wire [35 : 0] P
            );
        end
    endgenerate  

    //  2 clk latency (A+D)*B + C
    logic   [SYMMETRY_8-1 : 0][19:0]  sum8;
    generate
        for (genvar i = 0; i < SYMMETRY_8; i = i+1) begin : SUM8
            DSP_AB_C SUM8 (
              .CLK(axi_clk),  // input wire CLK
              .A({{(17-(IMAGE_DATA_WIDTH+1)){1'b0}},sym8_0[i]}),      // input wire [17 : 0] A
              .B({10'h0,GAUSS_8[i]}),       // input wire [17 : 0] B
              .C({12'h0,sum4[i]}),          // input wire [47 : 0] C
              .D({{(17-(IMAGE_DATA_WIDTH+1)){1'b0}},sym8_1[i]}),      // input wire [17 : 0] D
              .P(sum8[i])      // output wire [47 : 0] P
            );            
        end
    endgenerate      

    logic   [23:0]  sum         =   '0;
    logic   [2:0][16:0]  sum1_d =   '0;
    logic   [7:0][21:0]  sum_x  =   '0;

    always_ff @(posedge axi_clk) begin
        if(axi_rst) begin
            sum     <=  '0;
            sum1_d  <=  '0;
            sum_x   <=  '0;
        end else begin
            //  3 clk latency
            sum1_d[0]    <=  sum1[0];
            sum1_d[1]    <=  sum1_d[0];
            sum1_d[2]    <=  sum1_d[1];

            //  1st clk latency
            for (int i = 0; i < 5; i = i+1)  begin
                sum_x[i]    <=  sum8[2*i] + sum8[2*i+1];
            end
            //  2nd clk latency
            sum_x[5]    <=  sum_x[0] + sum_x[1];
            sum_x[6]    <=  sum_x[2] + sum_x[3];
            sum_x[7]    <=  sum_x[4] + sum1_d[1];
            //  3rd clk latency
            sum         <=  sum_x[5] + sum_x[6] + sum_x[7];
        end
    end

    //  total 6 clk latency :from svalid to Convolution result
    logic   [5:0]   valid_d =   '0;
    always_ff @(posedge axi_clk) begin
        valid_d <= {valid_d[4:0], svalid};
    end
    
    assign  conv_valid  =   valid_d[5];
    assign  conv_result =   sum;

 endmodule : one_conv