// sample bitstream computing circuit (multiplication and average, 4 inputs)
// 2021-09-10 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module bit_addmul (
    input  logic       CLK,
    input  logic [3:0] A,
    input  logic [1:0] SEL,
    output logic       PROD,
    output logic       AVG);

    assign PROD = &A;
    assign AVG  = (SEL == 2'b00) ? A[0] :
                  (SEL == 2'b01) ? A[1] :
                  (SEL == 2'b10) ? A[2] : A[3];
endmodule