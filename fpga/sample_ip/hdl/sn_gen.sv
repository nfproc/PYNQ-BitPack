// Stochastic Number Generator
// 2021-09-07 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module sn_gen (
    input  logic        CLK, RST_X, EN,
    input  logic [31:0] DATA_IN,
    input  logic        COMP_WE, SEED_WE,
    output logic        SN_OUT_P, SN_OUT_N);

    parameter [1:0] MODE = 2'd0; // 0 = unipolar, 1 = bipolar, 2 = two-line

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
        if (MODE == 2'd0) begin
            // unipolar mode, negative value will be truncated to zero
            n_comp_reg = (~DATA_IN[31]) ? DATA_IN: 0;
            n_sn_out_p = (n_shift_data[31:1] < comp_reg[30:0]);
            n_sn_out_n = 1'bx;
        end else if (MODE == 2'd1) begin
            // bipolar mode, the sign bit (MSB) will be inverted
            n_comp_reg = {~DATA_IN[31], DATA_IN[30:0]};
            n_sn_out_p = (n_shift_data < comp_reg);
            n_sn_out_n = 1'bx;
        end else begin
            // two-line mode, value will be converted to sign and magnitude
            n_comp_reg = DATA_IN ^ {1'b0, {31{DATA_IN[31]}}};
            n_sn_out_p = (n_shift_data[31:1] < comp_reg[30:0]) && ~comp_reg[31];
            n_sn_out_n = (n_shift_data[31:1] < comp_reg[30:0]) &&  comp_reg[31];
        end
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