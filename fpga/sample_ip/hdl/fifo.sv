// FIFO module 2020.03.12 Naoki F. AIT
// New BSD license is applied. See COPYING for more details.

module fifo #(
    parameter WIDTH = 8,
    parameter SIZE  = 2048)
    (
    input  logic             CLK, RST,
    input  logic [WIDTH-1:0] DATA_W,
    output logic [WIDTH-1:0] DATA_R,
    input  logic             WE, RE,
    output logic             EMPTY, FULL,
    input  logic             SOFT_RST);

    localparam LOG_SIZE = $clog2(SIZE);

    logic    [WIDTH-1:0] fifo_ram [0:SIZE-1];
    logic    [WIDTH-1:0] ram_out, d_data_w;
    logic                ram_select;
    logic                write_valid, read_valid;
    logic [LOG_SIZE-1:0] head, n_head, tail, n_tail;
    logic                n_empty, near_empty, n_near_empty;
    logic                n_full , near_full , n_near_full;

    // RAM: 同一アドレスへの読み書き（n_head == tail）では特別な処理が必要
    assign DATA_R     = (ram_select) ? ram_out : d_data_w;
    
    always_ff @ (posedge CLK) begin
        if (write_valid) begin
            ram_select <= (n_head != tail);
            d_data_w   <= DATA_W;
        end else begin
            ram_select <= 1'b1;
        end
    end

    always_ff @ (posedge CLK) begin // これが RAM 本体
        ram_out <= fifo_ram[n_head];
        if (write_valid) begin
            fifo_ram[tail] <= DATA_W;
        end
    end

    // リード・ライトの制御（組合せ回路）
    assign read_valid   = RE & ~EMPTY;
    assign write_valid  = WE & ~FULL;
    assign n_head       = (read_valid)  ? head + 1'b1 : head;
    assign n_tail       = (write_valid) ? tail + 1'b1 : tail;
    assign n_empty      = ~ write_valid & (EMPTY | (read_valid & near_empty));
    assign n_full       = ~ read_valid  & (FULL  | (write_valid & near_full));
    assign n_near_empty = (n_head + 1'b1 == n_tail);
    assign n_near_full  = (n_head == n_tail + 1'b1);

    // 値の更新（フリップフロップ）
    always_ff @ (posedge CLK) begin
        if (RST) begin
            head       <= 0;
            tail       <= 0;
            EMPTY      <= 1'b1;
            FULL       <= 1'b0;
            near_empty <= 1'b0;
            near_full  <= 1'b0;
        end else if (SOFT_RST) begin
            head       <= 0;
            tail       <= 0;
            EMPTY      <= 1'b1;
            FULL       <= 1'b0;
            near_empty <= 1'b0;
            near_full  <= 1'b0;
        end else begin
            head       <= n_head;
            tail       <= n_tail;
            EMPTY      <= n_empty;
            FULL       <= n_full;
            near_empty <= n_near_empty;
            near_full  <= n_near_full;
        end
    end
endmodule
