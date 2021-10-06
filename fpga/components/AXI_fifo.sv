// FIFO Interface for AXI-full Master IPs 2020.03.12 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module AXI_FIFO (
    input  logic        ACLK,
    input  logic        ARESETN,
    // AXI 側の信号
    // (a) Read Address Channel
    output logic  [0:0] AXI_M_ARID,
    output logic [31:0] AXI_M_ARADDR,
    output logic  [7:0] AXI_M_ARLEN,
    output logic  [2:0] AXI_M_ARSIZE,
    output logic  [1:0] AXI_M_ARBURST,
    output logic  [3:0] AXI_M_ARCACHE,
    output logic  [2:0] AXI_M_ARPROT,
    output logic        AXI_M_ARVALID,
    input  logic        AXI_M_ARREADY,
    // (b) Read Data Channel
    input  logic  [0:0] AXI_M_RID,
    input  logic [31:0] AXI_M_RDATA,
    input  logic  [1:0] AXI_M_RRESP,
    input  logic        AXI_M_RLAST,
    input  logic        AXI_M_RVALID,
    output logic        AXI_M_RREADY,
    // (c) Write Address Channel
    output logic  [0:0] AXI_M_AWID,
    output logic [31:0] AXI_M_AWADDR,
    output logic  [7:0] AXI_M_AWLEN,
    output logic  [2:0] AXI_M_AWSIZE,
    output logic  [1:0] AXI_M_AWBURST,
    output logic  [3:0] AXI_M_AWCACHE,
    output logic  [2:0] AXI_M_AWPROT,
    output logic        AXI_M_AWVALID,
    input  logic        AXI_M_AWREADY,
    // (d) Write Data Channel
    output logic [31:0] AXI_M_WDATA,
    output logic  [3:0] AXI_M_WSTRB,
    output logic        AXI_M_WLAST,
    output logic        AXI_M_WVALID,
    input  logic        AXI_M_WREADY,
    // (e) Write Response Channel
    input  logic  [0:0] AXI_M_BID,
    input  logic  [1:0] AXI_M_BRESP,
    input  logic        AXI_M_BVALID,
    output logic        AXI_M_BREADY,

    // ユーザ側の信号
    output logic        FIFO_BUSY,
    // (a) Read Request
    input  logic [31:0] READ_ADDR,
    input  logic [15:0] READ_COUNT,
    input  logic        READ_REQ,
    output logic        READ_BUSY,
    // (b) Read Data
    output logic [31:0] READ_DATA,
    output logic        READ_VALID,
    input  logic        READ_READY,
    // (c) Write Request
    input  logic [31:0] WRITE_ADDR,
    input  logic [15:0] WRITE_COUNT,
    input  logic        WRITE_REQ,
    output logic        WRITE_BUSY,
    // (d) Write Data
    input  logic [31:0] WRITE_DATA,
    input  logic        WRITE_VALID,
    output logic        WRITE_READY);

    // AXI 関連の出力のいくつかは固定
    assign AXI_M_ARID    = 1'b0; // 転送ID: 0 で固定
    assign AXI_M_ARSIZE  = 3'h2; // 転送サイズ: 2^2 = 4 bytes
    assign AXI_M_ARBURST = 2'h1; // バースト方式: アドレス加算
    assign AXI_M_ARCACHE = 4'h3; // キャッシュ方式: キャッシュなし，バッファ可
    assign AXI_M_ARPROT  = 3'h0; // メモリ保護: なし
    assign AXI_M_AWID    = 1'b0;
    assign AXI_M_AWSIZE  = 3'h2;
    assign AXI_M_AWBURST = 2'h1;
    assign AXI_M_AWCACHE = 4'h3;
    assign AXI_M_AWPROT  = 3'h0;
    assign AXI_M_WSTRB   = 4'hf; // 書き込み有効バイト: すべて
    assign AXI_M_BREADY  = 1'b1; // 書き込み応答: 常時受付

    // 転送長を求めるための関数
    function logic [8:0] trans_length(
        logic [31:0] addr,
        logic [15:0] count);
        logic [15:0] len, to_pageend;
        len        = count;
        to_pageend = 16'h0400 - {6'h00, addr[11:2]};
        if (len >= 16'h100) begin // 最大 256 ワード
            len = 16'h100;
        end
        if (len >= to_pageend) begin // ページ境界を跨ぐ場合
            len = to_pageend;
        end
        return len[8:0];
    endfunction

    // (a) Read Request の処理
    logic [31:0] n_araddr;
    logic [ 7:0] n_arlen;        // 注意: 転送長は ARLEN + 1
    logic        n_arvalid;
    logic [31:0] read_next, n_read_next;
    logic [15:0] read_rest, n_read_rest;
    logic [ 8:0] read_length;
    logic [15:0] read_reqs, n_read_reqs;

    assign READ_BUSY = AXI_M_ARVALID;

    always_comb begin
        n_araddr    = AXI_M_ARADDR;
        n_arlen     = AXI_M_ARLEN;
        n_arvalid   = AXI_M_ARVALID;
        n_read_next = read_next;
        n_read_rest = read_rest;
        n_read_reqs = read_reqs;
        if (~ AXI_M_ARVALID) begin // リクエストなし -> 新しいリクエストの到着待ち
            if (READ_REQ) begin 
                read_length = trans_length(READ_ADDR, READ_COUNT);
                n_araddr    = READ_ADDR;
                n_arlen     = read_length - 1'b1;
                n_arvalid   = 1'b1;
                n_read_next = READ_ADDR + (read_length << 2);
                n_read_rest = READ_COUNT - read_length;
            end
        end else begin // リクエストあり -> 既存リクエストの受理待ち
            if (AXI_M_ARREADY) begin 
                if (read_rest == 16'd0) begin
                    n_arvalid   = 1'b0;
                end else begin
                    read_length = trans_length(read_next, read_rest);
                    n_araddr    = read_next;
                    n_arlen     = read_length - 1'b1;
                    n_read_next = read_next + (read_length << 2);
                    n_read_rest = read_rest - read_length;
                end
            end
        end
        if (AXI_M_ARVALID & AXI_M_ARREADY) begin
            n_read_reqs = n_read_reqs + 1'b1;
        end
        if (AXI_M_RVALID & AXI_M_RREADY & AXI_M_RLAST) begin
            n_read_reqs = n_read_reqs - 1'b1;
        end
    end

    always_ff @ (posedge ACLK) begin
        if (~ ARESETN) begin
            AXI_M_ARADDR  <= 0;
            AXI_M_ARLEN   <= 8'h0;
            AXI_M_ARVALID <= 1'b0;
            read_next     <= 0;
            read_rest     <= 16'h0;
            read_reqs     <= 16'h0;
        end else begin
            AXI_M_ARADDR  <= n_araddr;
            AXI_M_ARLEN   <= n_arlen;
            AXI_M_ARVALID <= n_arvalid;
            read_next     <= n_read_next;
            read_rest     <= n_read_rest;
            read_reqs     <= n_read_reqs;
        end
    end

    // (b) Read Data の処理
    logic read_empty, read_full;
    
    assign AXI_M_RREADY = ~ read_full;
    assign READ_VALID   = ~ read_empty;

    fifo #(
            .WIDTH(32),
            .SIZE (1024))
        read_fifo (
            .CLK     (ACLK),
            .RST     (~ ARESETN),
            .DATA_W  (AXI_M_RDATA),
            .DATA_R  (READ_DATA),
            .WE      (AXI_M_RVALID),
            .RE      (READ_READY),
            .EMPTY   (read_empty),
            .FULL    (read_full),
            .SOFT_RST(1'b0));

            
    // (c) Write Request の処理: WLAST 発行のため AWLEN を覚えておく
    logic [ 7:0] wl_fifo_in, wl_fifo_out;
    logic        wl_fifo_we, wl_fifo_re;
    logic        wl_fifo_empty, wl_fifo_full;
    
    fifo #(
            .WIDTH(8),
            .SIZE (1024))
        wl_fifo (
            .CLK     (ACLK),
            .RST     (~ ARESETN),
            .DATA_W  (wl_fifo_in),
            .DATA_R  (wl_fifo_out),
            .WE      (wl_fifo_we),
            .RE      (wl_fifo_re),
            .EMPTY   (wl_fifo_empty),
            .FULL    (wl_fifo_full),
            .SOFT_RST(1'b0));

    // それ以外は Read Request の場合とほぼ同じ（wl_fifoが満杯でないなら）
    logic [31:0] n_awaddr;
    logic [ 7:0] n_awlen;        // 注意: 転送長は AWLEN + 1
    logic        n_awvalid;
    logic        n_write_busy;
    logic [31:0] write_next, n_write_next;
    logic [15:0] write_rest, n_write_rest;
    logic [ 8:0] write_length;

    assign wl_fifo_in = n_awlen;

    always_comb begin
        n_awaddr     = AXI_M_AWADDR;
        n_awlen      = AXI_M_AWLEN;
        n_awvalid    = AXI_M_AWVALID;
        n_write_busy = WRITE_BUSY;
        n_write_next = write_next;
        n_write_rest = write_rest;
        wl_fifo_we   = 1'b0;
        if (~ WRITE_BUSY) begin // リクエストなし -> 新しいリクエストの到着待ち
            if (WRITE_REQ) begin 
                write_length = trans_length(WRITE_ADDR, WRITE_COUNT);
                n_awaddr     = WRITE_ADDR;
                n_awlen      = write_length - 1'b1;
                n_awvalid    = ~ wl_fifo_full;
                n_write_busy = 1'b1;
                n_write_next = WRITE_ADDR + (write_length << 2);
                n_write_rest = WRITE_COUNT - write_length;
                wl_fifo_we   = ~ wl_fifo_full;
            end
        end else if (~ AXI_M_AWVALID) begin // FIFO がフル -> FIFOの解放待ち
            if (~ wl_fifo_full) begin
                n_awvalid    = 1'b1;
                wl_fifo_we   = 1'b1;
            end
        end else begin // リクエストあり -> 既存リクエストの受理待ち
            if (AXI_M_AWREADY) begin 
                if (write_rest == 16'd0) begin
                    n_awvalid    = 1'b0;
                    n_write_busy = 1'b0;
                end else begin
                    write_length = trans_length(write_next, write_rest);
                    n_awaddr     = write_next;
                    n_awlen      = write_length - 1'b1;
                    n_awvalid    = ~ wl_fifo_full;
                    n_write_next = write_next + (write_length << 2);
                    n_write_rest = write_rest - write_length;
                    wl_fifo_we   = ~ wl_fifo_full;
                end
            end
        end
    end

    always_ff @ (posedge ACLK) begin
        if (~ ARESETN) begin
            AXI_M_AWADDR  <= 0;
            AXI_M_AWLEN   <= 8'h0;
            AXI_M_AWVALID <= 1'b0;
            WRITE_BUSY    <= 1'b0;
            write_next    <= 0;
            write_rest    <= 16'h0;
        end else begin
            AXI_M_AWADDR  <= n_awaddr;
            AXI_M_AWLEN   <= n_awlen;
            AXI_M_AWVALID <= n_awvalid;
            WRITE_BUSY    <= n_write_busy;
            write_next    <= n_write_next;
            write_rest    <= n_write_rest;
        end
    end

    // (d) Write Data の処理
    logic write_empty, write_full;
    
    assign AXI_M_WVALID = ~ write_empty & (~ wl_fifo_empty | ~ wfirst);
    assign WRITE_READY  = ~ write_full;

    fifo #(
            .WIDTH(32),
            .SIZE (1024))
        write_fifo (
            .CLK     (ACLK),
            .RST     (~ ARESETN),
            .DATA_W  (WRITE_DATA),
            .DATA_R  (AXI_M_WDATA),
            .WE      (WRITE_VALID),
            .RE      (AXI_M_WREADY),
            .EMPTY   (write_empty),
            .FULL    (write_full),
            .SOFT_RST(1'b0));
    
    // WLAST の生成
    logic       wfirst, n_wfirst;
    logic [7:0] wl_rest, n_wl_rest;

    always_comb begin
        AXI_M_WLAST = 1'b0;
        wl_fifo_re  = 1'b0;
        n_wfirst    = wfirst;
        n_wl_rest   = wl_rest;
        if (wfirst) begin // 最初のデータ: wl_fifo から取り出したデータの値で判定
            AXI_M_WLAST = (wl_fifo_out == 8'h00);
            if (AXI_M_WREADY & AXI_M_WVALID) begin
                wl_fifo_re  = 1'b1;
                n_wfirst    = (wl_fifo_out == 8'h00);
                n_wl_rest   = wl_fifo_out;
            end
        end else begin // それ以外: カウンタ wl_rest の値で判定
            AXI_M_WLAST = (wl_rest == 8'h01);
            if (AXI_M_WREADY & AXI_M_WVALID) begin
                n_wfirst    = (wl_rest == 8'h01);
                n_wl_rest   = wl_rest - 1'b1;
            end
        end
    end

    always_ff @ (posedge ACLK) begin
        if (~ ARESETN) begin
            wfirst  <= 1'b1;
            wl_rest <= 8'h00;
        end else begin
            wfirst  <= n_wfirst;
            wl_rest <= n_wl_rest;
        end
    end

    // 回路全体が動作中（未消化のリクエストがある）か
    assign FIFO_BUSY = READ_BUSY || (read_reqs != 16'd0) ||
                       WRITE_BUSY || ~ wl_fifo_empty || ~ wfirst;
endmodule