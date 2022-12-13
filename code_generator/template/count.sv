// Template of counter for number of ones
// 2022-12-12 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module count_ones (
    input  logic        CLK, RST_X, EN,
    input  logic        SN_IN_P, SN_IN_N,
    input  logic [31:0] DATA_IN,
    input  logic        DATA_WE,
    output logic [31:0] DATA_OUT);

    // BITPACK_MODE_PARAMETER

    logic [31:0] n_count;
    always_comb begin
        // BITPACK_COUNTER_DEFINITIONS
    end

    always_ff @ (posedge CLK) begin
        if (~ RST_X) begin
            DATA_OUT <= 0;
        end else if (DATA_WE) begin
            DATA_OUT <= DATA_IN;
        end else if (EN) begin
            DATA_OUT <= n_count;
        end
    end
endmodule
