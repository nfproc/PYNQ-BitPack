// template of wrapper for bitstream computing circuit
// 2021-09-10 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module user_wrapper (
    input  logic        CLK, RST_X,
    // <-> AXI_CTRL
    input  logic        GO,
    output logic        DONE,
    input  logic [31:0] SRC, DST, SIZE,
    // <-> AXI_FIFO
    output logic [31:0] READ_ADDR,
    output logic [15:0] READ_COUNT,
    output logic        READ_REQ,
    input  logic        READ_BUSY,
    input  logic [31:0] READ_DATA,
    input  logic        READ_VALID,
    output logic        READ_READY,
    output logic [31:0] WRITE_ADDR,
    output logic [15:0] WRITE_COUNT,
    output logic        WRITE_REQ,
    input  logic        WRITE_BUSY,
    output logic [31:0] WRITE_DATA,
    output logic        WRITE_VALID,
    input  logic        WRITE_READY);

    // bit widths of input/output of computing circuit (respectively)
    // BITPACK_IO_DEFINITIONS

    // states of the wrapper circuit
    typedef enum {
        STATE_IDLE,
        STATE_READ,
        STATE_PROC,
        STATE_WRITE,
        STATE_FINI
    } state_t;

    state_t      state, n_state;
    logic [31:0] count, n_count;
    logic        read_en, write_en, proc_en, proc_last;

    always_comb begin
        n_state   = state;
        n_count   = count;
        DONE      = 1'b0;
        read_en   = 1'b0;
        write_en  = 1'b0;
        proc_en   = 1'b0;
        proc_last = 1'b0;
        if (state == STATE_IDLE) begin
            DONE      = 1'b1;
            if (GO) begin
                n_state   = STATE_READ;
                n_count   = 0;
            end
        end else if (state == STATE_READ) begin
            if (READ_VALID) begin
                read_en   = 1'b1;
                if (count == src_size * 2 - 1) begin
                    n_state   = STATE_PROC;
                    n_count   = 0;
                end else begin
                    n_count   = count + 1'b1;
                end
            end
        end else if (state == STATE_PROC) begin
            proc_en   = 1'b1;
            if (count == SIZE - 1) begin
                proc_last = 1'b1;
                n_state   = STATE_WRITE;
                n_count   = 0;
            end else begin
                n_count   = count + 1'b1;
            end
        end else if (state == STATE_WRITE) begin
            if (WRITE_READY) begin
                write_en  = 1'b1;
                if (count == dst_size - 1) begin
                    n_state   = STATE_FINI;
                    n_count   = 0;
                end else begin
                    n_count   = count + 1'b1;
                end
            end
        end else if (state == STATE_FINI) begin
            if (~ GO) begin
                n_state   = STATE_IDLE;
            end
        end
    end

    always_ff @ (posedge CLK) begin
        if (~ RST_X) begin
            state <= STATE_IDLE;
            count <= 0;
        end else begin
            state <= n_state;
            count <= n_count;
        end
    end

    // instantiation of SNGs and counters 
    logic [src_size-1:0] src_comp_we, src_seed_we;
    logic [src_size-1:0] src_sn_p, src_sn_n;
    logic [dst_size-1:0] dst_sn_p, dst_sn_n;
    logic [dst_size-1:0][31:0] dst_data, dst_data_in;

    genvar i;
    generate
        for (i = 0; i < src_size; i++) begin : gen_src
            assign src_comp_we[i] = read_en && (count == i * 2);
            assign src_seed_we[i] = read_en && (count == i * 2 + 1);
            sn_gen # (
                .MODE    (src_mode[i * 2 +: 2]))
            sng (
                .CLK     (CLK),
                .RST_X   (RST_X),
                .EN      (proc_en),
                .DATA_IN (READ_DATA),
                .COMP_WE (src_comp_we[i]),
                .SEED_WE (src_seed_we[i]),
                .SN_OUT_P(src_sn_p[i]),
                .SN_OUT_N(src_sn_n[i]));
        end

        for (i = 0; i < dst_size; i++) begin : gen_dst
            if (i == dst_size - 1) begin : gen_dst_data
                assign dst_data_in[i] = 0;
            end else begin
                assign dst_data_in[i] = dst_data[i + 1];
            end
            count_ones # (
                .MODE    (dst_mode[i * 2 +: 2]))
            cnt (
                .CLK     (CLK),
                .RST_X   (RST_X),
                .EN      (proc_en),
                .SN_IN_P (dst_sn_p[i]),
                .SN_IN_N (dst_sn_n[i]),
                .DATA_IN (dst_data_in[i]),
                .DATA_WE (write_en),
                .DATA_OUT(dst_data[i]));
        end
    endgenerate

    // FIFO control
    assign READ_ADDR   = SRC;
    assign READ_COUNT  = src_size * 2;
    assign READ_REQ    = DONE & GO;
    assign READ_READY  = (state == STATE_READ);
    assign WRITE_ADDR  = DST;
    assign WRITE_COUNT = dst_size;
    assign WRITE_REQ   = proc_last;
    assign WRITE_DATA  = dst_data[0];
    assign WRITE_VALID = (state == STATE_WRITE);

    // instantiation of bitstream computing circuit
    // BITPACK_CIRCUIT_INSTANCE
endmodule