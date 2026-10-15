// corrector: accumulation of fractions and carrying over saturations for AFE SC circuits
// 2026-10-15 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.
module corrector # (
    parameter int INT_W = 4,
    parameter int FRAC_W = 4
) (
    input  logic CLK,
    input  logic RST_X,
    input  logic [INT_W-1:0] IP,
    input  logic [FRAC_W-1:0] FRAC,
    output logic Y_H,
    output logic Y_L
);

    localparam int CNT_W  = INT_W + FRAC_W + 1;
    localparam int HIGH_W = INT_W + 2;
    localparam int LOW_W  = FRAC_W - 1;

    logic [CNT_W-1:0]  sum, rem, n_rem;
    logic [HIGH_W-1:0] sum_h, sub_h; // higher bits include digits up to 1/2
    logic [LOW_W-1:0]  sum_l;
    logic [1:0] y;

    assign sum = CNT_W'({IP, FRAC}) + rem;
    assign {sum_h, sum_l} = sum;

    assign sub_h = (sum_h >= HIGH_W'(3)) ? (sum_h - HIGH_W'(3)) : '0; // max(0, sum_h - 3)
    assign y     = (sum_h >= HIGH_W'(3)) ? 2'b11 : sum_h[1:0];        // min(3, sum_h)
    assign n_rem = {sub_h, sum_l};

    assign {Y_H, Y_L} = y;

    always_ff @(posedge CLK) begin
        if (! RST_X) begin
            rem <= '0;
        end else begin
            rem <= n_rem;
        end
    end
endmodule