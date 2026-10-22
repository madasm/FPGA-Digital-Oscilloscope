module trigger_capture (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] adc_sample,
    input  wire        sample_valid,
    input  wire [11:0] trigger_level,
    input  wire        rearm,
    output reg  [11:0] bram_data,
    output reg  [9:0]  bram_addr,
    output reg         bram_we,
    output reg         capture_done
);

    reg  [11:0] prev_sample;
    wire        rising_edge = (prev_sample < trigger_level) && 
                              (adc_sample  >= trigger_level);

    reg [27:0] auto_counter;
    wire       auto_trigger = (auto_counter == 28'd50_000_000);

    localparam IDLE      = 2'd0;
    localparam CAPTURING = 2'd1;
    localparam DONE      = 2'd2;

    reg [1:0]  state;
    reg [9:0]  sample_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            sample_count <= 10'd0;
            bram_we      <= 1'b0;
            capture_done <= 1'b0;
            prev_sample  <= 12'd0;
            auto_counter <= 28'd0;
        end else begin
            prev_sample <= adc_sample;

            case (state)
                IDLE: begin
                    capture_done <= 1'b0;
                    bram_we      <= 1'b0;
                    sample_count <= 10'd0;

                    if (sample_valid && rising_edge) begin
                        state        <= CAPTURING;
                        auto_counter <= 28'd0;
                    end else begin
                        auto_counter <= auto_counter + 1'b1;
                        if (auto_trigger) begin
                            state        <= CAPTURING;
                            auto_counter <= 28'd0;
                        end
                    end
                end

                CAPTURING: begin
                    if (sample_valid) begin
                        bram_data    <= adc_sample;
                        bram_addr    <= sample_count;
                        bram_we      <= 1'b1;
                        sample_count <= sample_count + 1'b1;

                        if (sample_count == 10'd639) begin
                            state        <= DONE;
                            capture_done <= 1'b1;
                        end
                    end else
                        bram_we <= 1'b0;
                end

                DONE: begin
                    bram_we <= 1'b0;
                    if (rearm)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule