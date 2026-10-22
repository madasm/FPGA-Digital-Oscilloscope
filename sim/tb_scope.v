`timescale 1ns / 1ps

module tb_scope;
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk; // 100 MHz clock

    reg  [11:0] adc_sample = 0;
    reg         sample_valid = 0;

    // 64-point sine lookup table (0 to 4095)
    reg [11:0] sine_lut [0:63];
    initial begin
        sine_lut[0]=2048; sine_lut[1]=2248; sine_lut[2]=2447; sine_lut[3]=2642; 
        sine_lut[4]=2831; sine_lut[5]=3013; sine_lut[6]=3185; sine_lut[7]=3346; 
        sine_lut[8]=3495; sine_lut[9]=3630; sine_lut[10]=3750; sine_lut[11]=3853; 
        sine_lut[12]=3939; sine_lut[13]=4007; sine_lut[14]=4056; sine_lut[15]=4085; 
        sine_lut[16]=4095; sine_lut[17]=4085; sine_lut[18]=4056; sine_lut[19]=4007; 
        sine_lut[20]=3939; sine_lut[21]=3853; sine_lut[22]=3750; sine_lut[23]=3630; 
        sine_lut[24]=3495; sine_lut[25]=3346; sine_lut[26]=3185; sine_lut[27]=3013; 
        sine_lut[28]=2831; sine_lut[29]=2642; sine_lut[30]=2447; sine_lut[31]=2248; 
        sine_lut[32]=2048; sine_lut[33]=1848; sine_lut[34]=1649; sine_lut[35]=1454; 
        sine_lut[36]=1265; sine_lut[37]=1083; sine_lut[38]=911;  sine_lut[39]=750; 
        sine_lut[40]=601;  sine_lut[41]=466;  sine_lut[42]=346;  sine_lut[43]=243; 
        sine_lut[44]=157;  sine_lut[45]=89;   sine_lut[46]=40;   sine_lut[47]=11; 
        sine_lut[48]=0;    sine_lut[49]=11;   sine_lut[50]=40;   sine_lut[51]=89; 
        sine_lut[52]=157;  sine_lut[53]=243;  sine_lut[54]=346;  sine_lut[55]=466; 
        sine_lut[56]=601;  sine_lut[57]=750;  sine_lut[58]=911;  sine_lut[59]=1083; 
        sine_lut[60]=1265; sine_lut[61]=1454; sine_lut[62]=1649; sine_lut[63]=1848;
    end

    reg [5:0] sine_idx = 0;
    reg [3:0] sample_div = 0;
    
    // Generate fake ADC samples every 10 clock cycles
    always @(posedge clk) begin
        sample_valid <= 0;
        sample_div   <= sample_div + 1;
        if (sample_div == 4'd9) begin
            sample_valid <= 1;
            adc_sample   <= sine_lut[sine_idx];
            sine_idx     <= sine_idx + 1;
        end
    end

    reg  [11:0] trigger_level = 12'd2048;
    reg         rearm = 0;
    wire [11:0] bram_data;
    wire [9:0]  bram_addr;
    wire        bram_we;
    wire        capture_done;

    trigger_capture dut (
        .clk(clk), .rst_n(rst_n), .adc_sample(adc_sample), .sample_valid(sample_valid),
        .trigger_level(trigger_level), .rearm(rearm), .bram_data(bram_data),
        .bram_addr(bram_addr), .bram_we(bram_we), .capture_done(capture_done)
    );

    // Memory array to capture and hold the data for printing
    reg [11:0] captured [0:639];
    always @(posedge clk) if (bram_we) captured[bram_addr] <= bram_data;

    integer k;
    initial begin
        rst_n = 0; #200; rst_n = 1;
        
        // Wait until the FSM finishes capturing 640 samples
        wait(capture_done);
        
        $display("=== Capture complete at t=%0t ===", $time);
        
        // Print a few samples to prove it worked
        for (k = 0; k < 640; k = k + 1)
            if (k < 20 || (k > 300 && k < 320)) 
                $display("  [%0d] = %0d", k, captured[k]);
                
        #1000; 
        $finish;
    end
endmodule