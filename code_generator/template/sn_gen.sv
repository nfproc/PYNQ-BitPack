// Template of Stochastic Number Generator
// 2022-12-12 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module sn_gen (
    input  logic        CLK, RST_X, EN,
    input  logic [31:0] DATA_IN,
    input  logic        COMP_WE, SEED_WE,
    output logic        SN_OUT_P, SN_OUT_N);

    // BITPACK_MODE_PARAMETER

    logic [31:0] shift_data, n_shift_data;
    logic        shift_in;
    logic [31:0] comp_reg, n_comp_reg;
    logic        n_sn_out_p, n_sn_out_n;

    // LFSR
    assign shift_in = shift_data[31] ^ shift_data[21] ^ shift_data[1] ^ shift_data[0];
    assign n_shift_data = {shift_data[30:0], shift_in};

    always_ff @ (posedge CLK) begin
        if (~ RST_X) begin
            shift_data <= 0;
        end else if (SEED_WE) begin
            shift_data <= DATA_IN;
        end else if (EN) begin
            shift_data <= n_shift_data;
        end
    end

    // Comparison with threshold
    always_comb begin
        // BITPACK_GENERATOR_DEFINITIONS
    end

    always_ff @ (posedge CLK) begin
        if (~ RST_X) begin
            comp_reg <= 31'd0;
            SN_OUT_P <= 1'b0;
            SN_OUT_N <= 1'b0;
        end else begin
            if (COMP_WE) begin
                comp_reg <= n_comp_reg;
            end
            SN_OUT_P <= n_sn_out_p;
            SN_OUT_N <= n_sn_out_n;
        end
    end
endmodule