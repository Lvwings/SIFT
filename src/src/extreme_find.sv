`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : extreme_shift_data.sv
 Create     : 2022-08-09 11:29:00
 Revise     : 2022-08-09 11:29:00
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module extreme_find #(
    parameter       IMAGE_COLUMN        =   512,    //  image column size m
    parameter       EXTREME_KERNEL_SIZE =   3,      //  extreme kernel size 3*3*3  
    parameter       DIFF_WIDTH          =   14   
    )(
    input                                                                               axi_clk,    // Clock
    input                                                                               axi_rst,    // active high
    input          [EXTREME_KERNEL_SIZE-1:0]                                            extreme_valid,
    input   signed [EXTREME_KERNEL_SIZE-1:0][EXTREME_KERNEL_SIZE-1:0][DIFF_WIDTH-1:0]   extreme_kernel  [EXTREME_KERNEL_SIZE-1:0],
    output                                                                              key_valid,
    output                                                                              key_mark
 );
 
/*------------------------------------------------------------------------------
--  start flag
------------------------------------------------------------------------------*/
    logic   flag_start  =   '0;
    always_ff @(posedge axi_clk) begin 
        flag_start <= &extreme_valid;
    end
    
/*------------------------------------------------------------------------------
--  find the max & min data of extreme_kernel (except the center data)
------------------------------------------------------------------------------*/
    localparam      PIPELINE1   =   ((EXTREME_KERNEL_SIZE*EXTREME_KERNEL_SIZE*EXTREME_KERNEL_SIZE - 1) >> 1) -1;
    localparam      PIPELINE2   =   PIPELINE1 >> 1;
    localparam      PIPELINE3   =   PIPELINE2 >> 1;
    localparam      PIPELINE4   =   PIPELINE3 >> 1;
    localparam      PIPELINE5   =   PIPELINE4 >> 1;

    typedef struct  {
            logic   signed  [PIPELINE1:0][DIFF_WIDTH-1:0]  pipe1 = '0;
            logic   signed  [PIPELINE2:0][DIFF_WIDTH-1:0]  pipe2 = '0;
            logic   signed  [PIPELINE3:0][DIFF_WIDTH-1:0]  pipe3 = '0;
            logic   signed  [PIPELINE4:0][DIFF_WIDTH-1:0]  pipe4 = '0;
            logic   signed  [PIPELINE5:0][DIFF_WIDTH-1:0]  pipe5 = '0;
    }  pipeline;
  
    pipeline    max,min;

    // pipeline1
    always_ff @(posedge axi_clk) begin 
        for (int i = 0; i < EXTREME_KERNEL_SIZE; i = i+1) begin
            for (int j = 0; j < EXTREME_KERNEL_SIZE; j = j+1) begin
                max.pipe1[i*EXTREME_KERNEL_SIZE + j]   <=  (extreme_kernel[0][i][j] > extreme_kernel[2][i][j]) ? extreme_kernel[0][i][j] : extreme_kernel[2][i][j];
                min.pipe1[i*EXTREME_KERNEL_SIZE + j]   <=  (extreme_kernel[0][i][j] < extreme_kernel[2][i][j]) ? extreme_kernel[0][i][j] : extreme_kernel[2][i][j];
            end
        end

        for (int i = 0; i < EXTREME_KERNEL_SIZE; i = i+1) begin
            max.pipe1[EXTREME_KERNEL_SIZE*EXTREME_KERNEL_SIZE + i]  <=  (extreme_kernel[1][0][i] > extreme_kernel[1][2][i]) ? extreme_kernel[1][0][i] : extreme_kernel[1][2][i];
            min.pipe1[EXTREME_KERNEL_SIZE*EXTREME_KERNEL_SIZE + i]  <=  (extreme_kernel[1][0][i] < extreme_kernel[1][2][i]) ? extreme_kernel[1][0][i] : extreme_kernel[1][2][i];
        end

            max.pipe1[PIPELINE1]  <=  (extreme_kernel[1][1][0] > extreme_kernel[1][1][2]) ? extreme_kernel[1][1][0] : extreme_kernel[1][1][2];
            min.pipe1[PIPELINE1]  <=  (extreme_kernel[1][1][0] < extreme_kernel[1][1][2]) ? extreme_kernel[1][1][0] : extreme_kernel[1][1][2];        
    end

    // pipeline2    
    always_ff @(posedge axi_clk) begin
        for (int i = 0; i <= PIPELINE2; i = i+1) begin
            max.pipe2[i]    <=  (max.pipe1[i] > max.pipe1[PIPELINE1-i]) ? max.pipe1[i] : max.pipe1[PIPELINE1-i];
            min.pipe2[i]    <=  (min.pipe1[i] < min.pipe1[PIPELINE1-i]) ? min.pipe1[i] : min.pipe1[PIPELINE1-i];
        end
    end

    // pipeline3
    always_ff @(posedge axi_clk) begin 
        for (int i = 0; i <= PIPELINE3; i = i+1) begin
            max.pipe3[i]    <=  (max.pipe2[i] > max.pipe2[PIPELINE2-i]) ? max.pipe2[i] : max.pipe2[PIPELINE2-i];
            min.pipe3[i]    <=  (min.pipe2[i] < min.pipe2[PIPELINE2-i]) ? min.pipe2[i] : min.pipe2[PIPELINE2-i];
        end
    end
    
    // pipeline4
    always_ff @(posedge axi_clk) begin 
        for (int i = 0; i <= PIPELINE4; i = i+1) begin
            max.pipe4[i]    <=  (max.pipe3[i] > max.pipe3[PIPELINE3-i]) ? max.pipe3[i] : max.pipe3[PIPELINE3-i];
            min.pipe4[i]    <=  (min.pipe3[i] < min.pipe3[PIPELINE3-i]) ? min.pipe3[i] : min.pipe3[PIPELINE3-i];
        end
    end  

    // pipeline5
    always_ff @(posedge axi_clk) begin 
        for (int i = 0; i <= PIPELINE5; i = i+1) begin
            max.pipe5[i]    <=  (max.pipe4[i] > max.pipe3[PIPELINE4-i]) ? max.pipe4[i] : max.pipe4[PIPELINE4-i];
            min.pipe5[i]    <=  (min.pipe4[i] < min.pipe3[PIPELINE4-i]) ? min.pipe4[i] : min.pipe4[PIPELINE4-i];
        end
    end

    // center data
    logic   signed  [4:0][DIFF_WIDTH-1:0]   center_data =   '0;
    always_ff @(posedge axi_clk) begin
        center_data <= {center_data[4:0],extreme_kernel[1][1][1]};
    end
                    

/*------------------------------------------------------------------------------
--  output extreme
    在计算极值时，每行最后两个数据由于是在移位，属于错误数据
------------------------------------------------------------------------------*/
    logic   [4:0]   o_valid =   '0;
    logic           o_mark  =   '0;
    always_ff @(posedge axi_clk) begin 
        if(axi_rst) begin
            o_valid <=  '0;
            o_mark  <=  '0;
        end else begin
            o_valid <=  {o_valid[4:0], flag_start};
            if (o_valid[4])
                o_mark  <=  (center_data[4] > max.pipe5[PIPELINE5]) || (center_data[4] < min.pipe5[PIPELINE5]);
            else
                o_mark  <=  '0;
        end
    end

    assign  key_valid   =   o_valid[4];
    assign  key_mark    =   o_mark;

 endmodule : extreme_find