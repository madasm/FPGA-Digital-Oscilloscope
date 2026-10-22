module clk_gen (
    input  wire clk_100m_in,
    input  wire rst_n,
    output wire clk_100m,
    output wire clk_25m,
    output wire locked
);

    clk_wiz_0 clk_wiz_inst (
        .clk_in1(clk_100m_in),
        .resetn(rst_n),
        .clk_out1(clk_100m),
        .clk_out2(clk_25m),
        .locked(locked)
    );

endmodule