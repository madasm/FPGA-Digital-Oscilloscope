module top_oscilloscope (
    input  wire        sys_clk,
    input  wire        rst_btn,
    input  wire        adc_p, adc_n,
    input  wire [15:4] sw,
    output wire        uart_tx
);

    wire clk_100m, clk_25m, locked;
    wire rst_n = ~rst_btn;

    clk_gen u_clk_gen (
        .clk_100m_in(sys_clk),
        .rst_n(rst_n),
        .clk_100m(clk_100m),
        .clk_25m(clk_25m),
        .locked(locked)
    );

    reg [1:0] rst_sync;
    always @(posedge clk_100m) rst_sync <= {rst_sync[0], rst_n};
    wire rst_n_100m = rst_sync[1];

    wire [11:0] adc_sample;
    wire        sample_valid;

    xadc_capture u_xadc (
        .clk(clk_100m),
        .rst_n(rst_n_100m),
        .adc_p(adc_p),
        .adc_n(adc_n),
        .adc_sample(adc_sample),
        .sample_valid(sample_valid)
    );

    wire [11:0] bram_data;
    wire [9:0]  bram_addr;
    wire        bram_we;
    wire        capture_done;
    reg         rearm;

    trigger_capture u_trigger (
        .clk(clk_100m),
        .rst_n(rst_n_100m),
        .adc_sample(adc_sample),
        .sample_valid(sample_valid),
        .trigger_level({sw[15:8], 4'b0000}),
        .rearm(rearm),
        .bram_data(bram_data),
        .bram_addr(bram_addr),
        .bram_we(bram_we),
        .capture_done(capture_done)
    );

    wire [11:0] bram_rd_data;
    reg  [9:0]  bram_rd_addr;

    blk_mem_gen_0 u_bram (
        .clka(clk_100m),
        .ena(1'b1),
        .wea(bram_we),
        .addra(bram_addr),
        .dina(bram_data),
        .clkb(clk_100m),
        .addrb(bram_rd_addr),
        .doutb(bram_rd_data)
    );

    reg        uart_start;
    reg [7:0]  uart_data;
    wire       uart_busy;

    uart_tx u_uart (
        .clk(clk_100m),
        .rst_n(rst_n_100m),
        .tx_start(uart_start),
        .tx_data(uart_data),
        .tx(uart_tx),
        .tx_busy(uart_busy)
    );

    localparam F_IDLE   = 4'd0;
    localparam F_WAIT1  = 4'd1;
    localparam F_WAIT2  = 4'd2;
    localparam F_LATCH  = 4'd3;
    localparam F_THOU   = 4'd4;
    localparam F_THOU_W = 4'd5;
    localparam F_HUND   = 4'd6;
    localparam F_HUND_W = 4'd7;
    localparam F_TENS   = 4'd8;
    localparam F_TENS_W = 4'd9;
    localparam F_ONES   = 4'd10;
    localparam F_ONES_W = 4'd11;
    localparam F_NL     = 4'd12;
    localparam F_NL_W   = 4'd13;
    localparam F_NEXT   = 4'd14;

    reg [3:0]  fstate;
    reg [9:0]  rd_idx;
    reg [11:0] samp_lat;
    reg [7:0]  thou, hund, tens, ones;

    wire [11:0] d1000 = samp_lat / 12'd1000;
    wire [11:0] m1000 = samp_lat % 12'd1000;
    wire [11:0] d100  = m1000    / 12'd100;
    wire [11:0] m100  = m1000    % 12'd100;
    wire [11:0] d10   = m100     / 12'd10;
    wire [11:0] m10   = m100     % 12'd10;

    always @(posedge clk_100m or negedge rst_n_100m) begin
        if (!rst_n_100m) begin
            fstate       <= F_IDLE;
            rd_idx       <= 10'd0;
            uart_start   <= 1'b0;
            uart_data    <= 8'd0;
            rearm        <= 1'b0;
            samp_lat     <= 12'd0;
            bram_rd_addr <= 10'd0;
            thou <= 8'd0;
            hund <= 8'd0;
            tens <= 8'd0;
            ones <= 8'd0;
        end else begin
            uart_start <= 1'b0;
            rearm      <= 1'b0;

            case (fstate)
                F_IDLE: if (capture_done) begin
                    rd_idx       <= 10'd0;
                    bram_rd_addr <= 10'd0;
                    fstate       <= F_WAIT1;
                end

                F_WAIT1: fstate <= F_WAIT2;

                F_WAIT2: begin
                    samp_lat <= bram_rd_data;
                    fstate   <= F_LATCH;
                end

                F_LATCH: begin
                    thou   <= 8'd48 + d1000[7:0];
                    hund   <= 8'd48 + d100[7:0];
                    tens   <= 8'd48 + d10[7:0];
                    ones   <= 8'd48 + m10[7:0];
                    fstate <= F_THOU;
                end

                F_THOU: if (!uart_busy) begin uart_data <= thou; uart_start <= 1'b1; fstate <= F_THOU_W; end
                F_THOU_W: if (!uart_busy) fstate <= F_HUND;
                F_HUND: if (!uart_busy) begin uart_data <= hund; uart_start <= 1'b1; fstate <= F_HUND_W; end
                F_HUND_W: if (!uart_busy) fstate <= F_TENS;
                F_TENS: if (!uart_busy) begin uart_data <= tens; uart_start <= 1'b1; fstate <= F_TENS_W; end
                F_TENS_W: if (!uart_busy) fstate <= F_ONES;
                F_ONES: if (!uart_busy) begin uart_data <= ones; uart_start <= 1'b1; fstate <= F_ONES_W; end
                F_ONES_W: if (!uart_busy) fstate <= F_NL;
                F_NL: if (!uart_busy) begin uart_data <= 8'h0A; uart_start <= 1'b1; fstate <= F_NL_W; end
                F_NL_W: if (!uart_busy) fstate <= F_NEXT;

                F_NEXT: begin
                    if (rd_idx == 10'd639) begin
                        rearm  <= 1'b1;
                        fstate <= F_IDLE;
                    end else begin
                        rd_idx       <= rd_idx + 1'b1;
                        bram_rd_addr <= bram_rd_addr + 1'b1;
                        fstate       <= F_WAIT1;
                    end
                end

                default: fstate <= F_IDLE;
            endcase
        end
    end

endmodule