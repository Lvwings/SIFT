
`timescale 1ns/1ps

module tb_shift_top (); /* this is automatically generated */

	// clock
	logic clk;
	initial begin
		clk = '0;
		forever #(5) clk = ~clk;
	end

	// synchronous reset
	logic srstb;
	initial begin
		srstb <= '1;
		repeat(100)@(posedge clk);
		srstb <= '0;
	end

	// (*NOTE*) replace reset, clock, others

    parameter        IMAGE_COLUMN = 512;
    parameter    IMAGE_DATA_WIDTH = 8;
    parameter    CONV_KERNEL_SIZE = 11;
    parameter EXTREME_KERNEL_SIZE = 3;
    parameter       GAUSS0_1            =  8'd63;
    parameter       GAUSS0_4            =  {8'd52,8'd29,8'd10,8'd2,8'd0,8'd43,8'd13,8'd1,8'd0,8'd0};
    parameter       GAUSS0_8            =  {8'd23,8'd9, 8'd2, 8'd0,8'd5,8'd1, 8'd0, 8'd0,8'd0,8'd0}; 

    parameter       GAUSS1_1            =  8'd40;
    parameter       GAUSS1_4            =  {8'd35,8'd24,8'd13,8'd5,8'd1,8'd31,8'd15,8'd4,8'd0,8'd0};
    parameter       GAUSS1_8            =  {8'd21,8'd11,8'd5,8'd1,8'd8,8'd3,8'd1,8'd1,8'd0,8'd0};

    parameter       GAUSS2_1            =  8'd26;
    parameter       GAUSS2_4            =  {8'd24,8'd19,8'd13,8'd7,8'd3,8'd22,8'd14,8'd6,8'd2,8'd0};
    parameter       GAUSS2_8            =  {8'd18,8'd12,8'd7,8'd3,8'd9,8'd5,8'd2,8'd3,8'd1,8'd1}; 

    parameter       GAUSS3_1            =  8'd18;
    parameter       GAUSS3_4            =  {8'd18,8'd15,8'd12,8'd8,8'd5,8'd17,8'd12,8'd7,8'd3,8'd1};
    parameter       GAUSS3_8            =  {8'd14,8'd11,8'd8,8'd5,8'd10,8'd7,8'd4,8'd5,8'd3,8'd2};  
    localparam         DIFF_WIDTH = 14;

    logic                                  axi_clk;
    logic                                  axi_rst;
    logic         [IMAGE_DATA_WIDTH-1 : 0] axis_tdata;
    logic                                  axis_tvalid;
    logic                                  axis_tlast;
    logic                                  axis_tready;
    logic [3:0]                                                   conv_valid;
    logic [3:0][23:0]                                             conv_result;
    logic signed [EXTREME_KERNEL_SIZE-1:0][DIFF_WIDTH-1:0]        conv_diff;
    logic                                  key_valid;
    logic                                  key_mark;

    shift_top #(
            .IMAGE_COLUMN(IMAGE_COLUMN),
            .IMAGE_DATA_WIDTH(IMAGE_DATA_WIDTH),
            .CONV_KERNEL_SIZE(CONV_KERNEL_SIZE),
            .EXTREME_KERNEL_SIZE(EXTREME_KERNEL_SIZE),
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
        ) inst_shift_top (
            .axi_clk     (axi_clk),
            .axi_rst     (axi_rst),
            .axis_tdata  (axis_tdata),
            .axis_tvalid (axis_tvalid),
            .axis_tlast  (axis_tlast),
            .axis_tready (axis_tready),
            .conv_valid  (conv_valid),
            .conv_result (conv_result),
            .conv_diff   (conv_diff),
            .key_valid   (key_valid),
            .key_mark    (key_mark)
        );

	assign 	axi_clk    = clk;
	assign 	axi_rst   = srstb;

	task init();
		axis_tdata  <= '0;
		axis_tvalid <= '0;
		axis_tlast  <= '0;
	endtask


	initial begin
		// do something
		init();

	end

	logic	[8:0]	data 	= '0;
	logic	[0:0]	en 		= '1;

	logic	rst;
	initial begin
		rst <= '0;
		repeat(150)@(posedge clk);
		rst <= '1;
	end

    integer fr;

    initial begin : open_file
        repeat(120) @(posedge axi_clk);
        
        fr = $fopen("D:/Matlab/m_sift/data/gray.txt", "r");

        while (!$feof(fr)) begin
            @(posedge axi_clk);
            $fscanf(fr, "%d", axis_tdata); 
            axis_tvalid <= 1;           
        end

        axis_tdata  <= 0;
        axis_tvalid <= 0;
        axis_tlast  <= 1;        
        $fclose(fr);
    end

    logic   [3:0][7:0]  u8_result;
    logic   [2:0][7:0]  u8_diff;

    generate
        for (genvar i = 0; i < 4; i = i+1) begin
            assign u8_result[i] = (conv_result[i] >> 10);
        end
    endgenerate

    generate
        for (genvar i = 0; i < 3; i = i+1) begin
            assign u8_diff[i] = (conv_diff[i]);
        end
    endgenerate

    integer fw0,fw1,fw2,fw3;
    integer fd0,fd1,fd2;
    logic   [8:0]   data_cnt0   =   '0;
    logic   [8:0]   data_cnt1   =   '0;
    logic   [8:0]   data_cnt2   =   '0;
    logic   [8:0]   data_cnt3   =   '0;

    initial begin : write_conv_result0
        repeat(120) @(posedge axi_clk);

        fw0 = $fopen("D:/Matlab/m_sift/data/conv0.txt", "w");
        fd0 = $fopen("D:/Matlab/m_sift/data/conv_diff0.txt", "w");

        wait(conv_valid[0]);
        $display("conv_valid assert");
        while (conv_valid[0]) begin
            @(posedge axi_clk);
            data_cnt0   <=  data_cnt0 + 1;
            if (data_cnt0 == '1) begin
                $fwrite(fw0,"%d\n", u8_result[0]);
                $fwrite(fd0,"%d\n", conv_diff[0]);
            end
            else begin
                $fwrite(fw0,"%d\t", u8_result[0]);
                $fwrite(fd0,"%d\t", conv_diff[0]);
            end               
        end
        $fclose(fw0);
        $fclose(fd0);
    end

    initial begin : write_conv_result1
        repeat(120) @(posedge axi_clk);

        fw1 = $fopen("D:/Matlab/m_sift/data/conv1.txt", "w");
        fd1 = $fopen("D:/Matlab/m_sift/data/conv_diff1.txt", "w");

        wait(conv_valid[1]);
        while (conv_valid[1]) begin
            @(posedge axi_clk);
            data_cnt1   <=  data_cnt1 + 1;
            if (data_cnt1 == '1) begin
                $fwrite(fw1,"%d\n", u8_result[1]);
                $fwrite(fd1,"%d\n", u8_diff[1]);
            end
            else begin
                $fwrite(fw1,"%d\t", u8_result[1]);
                $fwrite(fd1,"%d\t", u8_diff[1]);
            end
        end
        $fclose(fw1);
        $fclose(fd1);        
    end

    initial begin : write_conv_result2
        repeat(120) @(posedge axi_clk);

        fw2 = $fopen("D:/Matlab/m_sift/data/conv2.txt", "w");
        fd2 = $fopen("D:/Matlab/m_sift/data/conv_diff2.txt", "w");

        wait(conv_valid[2]);
        while (conv_valid[2]) begin
            @(posedge axi_clk);
            data_cnt2   <=  data_cnt2 + 1;
            if (data_cnt2 == '1) begin
                $fwrite(fw2,"%d\n", u8_result[2]);
                $fwrite(fd2,"%d\n", u8_diff[2]);
            end
            else begin
                $fwrite(fw2,"%d\t", u8_result[2]);
                $fwrite(fd2,"%d\t", u8_diff[2]);
            end
        end
        $fclose(fw2);
        $fclose(fd2);        
    end

    initial begin : write_conv_result3
        repeat(120) @(posedge axi_clk);

        fw3 = $fopen("D:/Matlab/m_sift/data/conv3.txt", "w");

        wait(conv_valid[3]);
        while (conv_valid[3]) begin
            @(posedge axi_clk);
            data_cnt3   <=  data_cnt3 + 1;
            if (data_cnt3 == '1)
                $fwrite(fw3,"%d\n", u8_result[3]);
            else
                $fwrite(fw3,"%d\t", u8_result[3]);
        end
        $fclose(fw3);      
    end

    integer fmark;
    logic   [8:0]   mark_cnt    =   '0;

    initial begin : write_mark
        repeat(120) @(posedge axi_clk);

        fmark = $fopen("D:/Matlab/m_sift/data/mark.txt", "w");

        wait(key_valid);
        $display("key_valid assert");
        while (key_valid) begin
            @(posedge axi_clk); 
            mark_cnt   <=  mark_cnt + 1;          
            if (mark_cnt == '1)
                $fwrite(fmark,"%d\n", key_mark);        
            else                
                $fwrite(fmark,"%d\t", key_mark);         
        end
        $fclose(fmark);        
    end     
endmodule