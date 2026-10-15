// sample bitstream computing circuit using 2-bit AFE (multiplication and average, 4 inputs)
// 2026-10-15 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module bit_addmul_AFE (
    input  logic       CLK, RST_X,
    input  logic [3:0] A_H, A_L,
    input  logic       INVN_H, INVN_L,
    output logic       PROD_H, PROD_L,
    output logic       AVG_H, AVG_L);

    logic [1:0] prod, avg;
    logic [1:0] a3, a2, a1, a0, invn; // (1.1) bits
    logic [7:0] prod_inner;           // (4.4) bits
    logic [5:0] avg_inner;            // (4.2) bits

    assign a3 = {A_H[3], A_L[3]};
    assign a2 = {A_H[2], A_L[2]};
    assign a1 = {A_H[1], A_L[1]};
    assign a0 = {A_H[0], A_L[0]};
    assign invn = {INVN_H, INVN_L};

    assign prod_inner = 8'(a3) * 8'(a2) * 8'(a1) * 8'(a0);
    assign avg_inner = (6'(a3) + 6'(a2) + 6'(a1) + 6'(a0)) * 6'(invn); // invn = inverse of number of inputs = 1/4

    // We assume that output must also be 2 bits, so correction is required
    // (See AFE_corrector.sv)
    corrector # (4, 4) prod_correct (CLK, RST_X, prod_inner[7:4], prod_inner[3:0], PROD_H, PROD_L);
    corrector # (4, 2) avg_correct  (CLK, RST_X, avg_inner [5:2], avg_inner [1:0], AVG_H, AVG_L);
endmodule
