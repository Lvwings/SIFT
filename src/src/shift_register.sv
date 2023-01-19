`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : shift_register.sv
 Create     : 2022-07-22 14:19:37
 Revise     : 2022-07-22 14:19:37
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module shift_register #(
        parameter   IMAGE_COLUMN    =   512,
        parameter   DATA_WIDTH      =   8,
        parameter   SHIFT_DEPTH     =   16,
        parameter   PAD             =   5,
        parameter   RESET_VALUE     =   {DATA_WIDTH{1'b0}}
    )
    (
        input                                           clk,
        input                                           rst,
        input                                           valid_in,
        input   [DATA_WIDTH-1 : 0]                      data_in,
        output                                          valid_out,
        output  [SHIFT_DEPTH-1 : 0][DATA_WIDTH-1 : 0]   data_out 
 );
 
    logic   [SHIFT_DEPTH-1 : 0][DATA_WIDTH-1 : 0]   dout0   = '{default:RESET_VALUE};
    logic   [SHIFT_DEPTH-1 : 0][DATA_WIDTH-1 : 0]   dout1   = '{default:RESET_VALUE};
    logic                                           o_sel   =   '0;    

/*------------------------------------------------------------------------------
--  input data counter
------------------------------------------------------------------------------*/
    // function called clogb2 that returns an integer which has the 
    // value of the ceiling of the log base 2.                      
    function integer clogb2 (input integer bit_depth);              
        begin                                                           
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
              bit_depth = bit_depth >> 1;                                 
        end                                                           
    endfunction

    localparam  CNT_WIDTH           = clogb2(IMAGE_COLUMN-1);
    logic   [CNT_WIDTH : 0]      cnt     = '0;

    always_ff @(posedge clk) begin
        if(rst) begin
            cnt     <= '0;
        end else begin
            if (valid_in)
                if (cnt == IMAGE_COLUMN-1)
                    cnt <= '0;
                else
                    cnt <= cnt + 1;
            else
                cnt <=  '0;
        end
    end
/*------------------------------------------------------------------------------
--  shift register
------------------------------------------------------------------------------*/
    logic   [PAD : 0]     valid   =   '0;
    always_ff @(posedge clk) begin
        if(rst) begin
            dout0   <=  '0;
            dout1   <=  '0;
        end else begin
            o_sel   <=  (cnt == IMAGE_COLUMN-1) ? ~o_sel : o_sel;

            if (o_sel) begin
                dout1[0]    <=  data_in;
                dout0[0]    <=  '0;
            end
            else begin
                dout1[0]    <=  '0;
                dout0[0]    <=  data_in;                
            end
            if (valid_in || valid[PAD-1]) begin
                for (int i = 0; i < SHIFT_DEPTH-1; i = i+1) begin
                    dout0[i+1]    <=  dout0[i] ; 
                    dout1[i+1]    <=  dout1[i] ;  
                end  
            end
            else begin
                dout0   <=  '0;
                dout1   <=  '0;
            end                      
        end
    end

/*------------------------------------------------------------------------------
--  output align
------------------------------------------------------------------------------*/
    
    always_ff @(posedge clk) begin
        if(rst) begin
            valid <= 0;
        end else begin
            valid <= {valid[PAD-1:0],valid_in};
        end
    end

    logic   [PAD : 0]     sel   =   '0;
    always_ff @(posedge clk) begin
        if(rst) begin
            sel <= 0;
        end else begin
            sel <= {sel[PAD-1:0],o_sel};
        end
    end

    assign  valid_out   =   valid[PAD];
    assign  data_out    =   (valid_out & !sel[PAD] ) ? dout0 : dout1;

 endmodule : shift_register