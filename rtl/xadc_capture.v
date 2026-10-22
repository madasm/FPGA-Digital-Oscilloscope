module xadc_capture (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        adc_p,
    input  wire        adc_n,
    output reg  [11:0] adc_sample,
    output reg         sample_valid
);

    wire [15:0] adc_data_raw;
    wire        eoc_out;
    wire        drdy_out;
    wire        busy_out;
    wire [4:0]  channel_out;
    wire        alarm_out;

    localparam DRP_IDLE = 1'b0;
    localparam DRP_WAIT = 1'b1;

    reg        drp_state;
    reg        den_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            drp_state <= DRP_IDLE;
            den_reg   <= 1'b0;
        end else begin
            case (drp_state)
                DRP_IDLE: if (eoc_out) begin
                    den_reg   <= 1'b1;
                    drp_state <= DRP_WAIT;
                end
                DRP_WAIT: if (drdy_out) begin
                    den_reg   <= 1'b0;
                    drp_state <= DRP_IDLE;
                end
            endcase
        end
    end

    xadc_wiz_0 xadc_inst (
        .daddr_in(7'h16),
        .dclk_in(clk),
        .den_in(den_reg),
        .di_in(16'h0),
        .dwe_in(1'b0),
        .reset_in(~rst_n),
        .vauxp6(adc_p),
        .vauxn6(adc_n),
        .busy_out(busy_out),
        .channel_out(channel_out),
        .do_out(adc_data_raw),
        .drdy_out(drdy_out),
        .eoc_out(eoc_out),
        .eos_out(),
        .alarm_out(alarm_out),
        .vp_in(1'b0),
        .vn_in(1'b0)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_sample   <= 12'd0;
            sample_valid <= 1'b0;
        end else begin
            if (drdy_out) begin
                adc_sample   <= adc_data_raw[15:4];
                sample_valid <= 1'b1;
            end else
                sample_valid <= 1'b0;
        end
    end

endmodule