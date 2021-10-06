// Counter for number of ones
// 2021-09-07 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module count_ones (
    input  logic        CLK, RST_X, EN,
    input  logic        SN_IN_P, SN_IN_N,
    input  logic [31:0] DATA_IN,
    input  logic        DATA_WE,
    output logic [31:0] DATA_OUT);

    parameter [1:0] MODE = 2'd0; // 0 = unipolar, 1 = bipolar, 2 = two-line

    logic [31:0] n_count;
    always_comb begin
        if (MODE == 2'd0) begin
            // unipolar mode, count the number of ones simply
            n_count = (SN_IN_P) ? DATA_OUT + 1'b1 : DATA_OUT;
        end else if (MODE == 2'd1) begin
            // bipolar mode, decrement counter when input is '0'
            n_count = (SN_IN_P) ? DATA_OUT + 1'b1 : DATA_OUT - 1'b1;
        end else begin
            // two-line mode, increment when P is '1' and decrement when N is '1'
            n_count = (SN_IN_P & ~ SN_IN_N) ? DATA_OUT + 1'b1 :
                      (SN_IN_N & ~ SN_IN_P) ? DATA_OUT - 1'b1 : DATA_OUT;
        end
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
