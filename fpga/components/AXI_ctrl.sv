// AXI-lite Slave Controller 2020.03.11 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module AXI_ctrl (
    // AXI Lite �֘A�M��
    input  logic         AXI_CTRL_ACLK,
    input  logic         AXI_CTRL_ARESETN,
    input  logic [ 3: 0] AXI_CTRL_AWADDR,
    input  logic [ 2: 0] AXI_CTRL_AWPROT,
    input  logic         AXI_CTRL_AWVALID,
    output logic         AXI_CTRL_AWREADY,
    input  logic [31: 0] AXI_CTRL_WDATA,
    input  logic [ 3: 0] AXI_CTRL_WSTRB,
    input  logic         AXI_CTRL_WVALID,
    output logic         AXI_CTRL_WREADY,
    output logic [ 1: 0] AXI_CTRL_BRESP,
    output logic         AXI_CTRL_BVALID,
    input  logic         AXI_CTRL_BREADY,
    input  logic [ 3: 0] AXI_CTRL_ARADDR,
    input  logic [ 2: 0] AXI_CTRL_ARPROT,
    input  logic         AXI_CTRL_ARVALID,
    output logic         AXI_CTRL_ARREADY,
    output logic [31: 0] AXI_CTRL_RDATA,
    output logic [ 1: 0] AXI_CTRL_RRESP,
    output logic         AXI_CTRL_RVALID,
    input  logic         AXI_CTRL_RREADY,

    // ���[�U�M��
    output logic [31: 0] USER_SRC, USER_DST, USER_SIZE,
    output logic         USER_GO,
    input  logic         USER_DONE);

    // AXI���X�|���X�i��ɁuOK�v�j
    assign AXI_CTRL_BRESP = 2'b00;
    assign AXI_CTRL_RRESP = 2'b00;

    // AXI�������݃|�[�g�iAW, W�j
    // -- 1. AWVALID, WVALID ���A�T�[�g�����܂ő҂�
    // -- 2. AWADDR ���L�����CAWREADY, WREADY, BVALID ���A�T�[�g
    // -- 3. �������݂��s���CAWREADY, WREADY ���l�Q�[�g
    // -- 4. BREADY ���A�T�[�g���ꂽ�� BVALID ���l�Q�[�g
    logic [ 1: 0] d_awaddr;
    logic         n_wready, n_bvalid;
    logic         reg_we;

    assign AXI_CTRL_AWREADY = AXI_CTRL_WREADY;

    // -- �������ݐ���
    always_comb begin
        n_wready = AXI_CTRL_WREADY;
        n_bvalid = AXI_CTRL_BVALID;
        reg_we   = 1'b0;
        if (AXI_CTRL_AWVALID & AXI_CTRL_WVALID) begin
            if (~ AXI_CTRL_WREADY) begin
                n_wready = 1'b1; // 1 -> 2
                n_bvalid = 1'b1;
            end else begin
                n_wready = 1'b0; // 2 -> 3
                reg_we   = 1'b1; 
            end
        end
        if (AXI_CTRL_BVALID & AXI_CTRL_BREADY) begin
            n_bvalid = 1'b0; // 3 -> 4
        end
    end

    always_ff @ (posedge AXI_CTRL_ACLK) begin
        if (~ AXI_CTRL_ARESETN) begin
            AXI_CTRL_WREADY <= 1'b0;
            AXI_CTRL_BVALID <= 1'b0;
            d_awaddr        <= 2'b00;
        end else begin
            AXI_CTRL_WREADY <= n_wready;
            AXI_CTRL_BVALID <= n_bvalid;
            if (n_wready) begin
                d_awaddr        <= AXI_CTRL_AWADDR[3:2];
            end
        end
    end

    // -- �������݃f�[�^
    always_ff @ (posedge AXI_CTRL_ACLK) begin
        if (~ AXI_CTRL_ARESETN) begin
            USER_GO   <= 1'b0;
            USER_SIZE <= 16'd512;
            USER_SRC  <= 0;
            USER_DST  <= 0;
        end else if (reg_we) begin
            if (d_awaddr == 2'd0)  begin
                if (AXI_CTRL_WSTRB[0]) USER_GO          <= AXI_CTRL_WDATA[ 0];
            end else if (d_awaddr == 2'd1)  begin
                if (AXI_CTRL_WSTRB[0]) USER_SRC [ 7: 0] <= AXI_CTRL_WDATA[ 7: 0];
                if (AXI_CTRL_WSTRB[1]) USER_SRC [15: 8] <= AXI_CTRL_WDATA[15: 8];
                if (AXI_CTRL_WSTRB[2]) USER_SRC [23:16] <= AXI_CTRL_WDATA[23:16];
                if (AXI_CTRL_WSTRB[3]) USER_SRC [31:24] <= AXI_CTRL_WDATA[31:24];
            end else if (d_awaddr == 2'd2)  begin
                if (AXI_CTRL_WSTRB[0]) USER_DST [ 7: 0] <= AXI_CTRL_WDATA[ 7: 0];
                if (AXI_CTRL_WSTRB[1]) USER_DST [15: 8] <= AXI_CTRL_WDATA[15: 8];
                if (AXI_CTRL_WSTRB[2]) USER_DST [23:16] <= AXI_CTRL_WDATA[23:16];
                if (AXI_CTRL_WSTRB[3]) USER_DST [31:24] <= AXI_CTRL_WDATA[31:24];
            end else if (d_awaddr == 2'd3)  begin
                if (AXI_CTRL_WSTRB[0]) USER_SIZE[ 7: 0] <= AXI_CTRL_WDATA[ 7: 0];
                if (AXI_CTRL_WSTRB[1]) USER_SIZE[15: 8] <= AXI_CTRL_WDATA[15: 8];
                if (AXI_CTRL_WSTRB[2]) USER_SIZE[23:16] <= AXI_CTRL_WDATA[23:16];
                if (AXI_CTRL_WSTRB[3]) USER_SIZE[31:24] <= AXI_CTRL_WDATA[31:24];
            end
        end
    end
    
    // AXI�ǂݏo���|�[�g�iAR, R�j
    // -- 1. ARVALID ���A�T�[�g�����܂ő҂�
    // -- 2. ARADDR ���L�����CARREADY ���A�T�[�g
    // -- 3. �ǂݏo�����s���CRVALID ���A�T�[�g���CARREADY ���l�Q�[�g
    // -- 4. RREADY ���A�T�[�g���ꂽ�� RVALID ���l�Q�[�g
    logic [31: 0] d_araddr;
    logic         n_arready, n_rvalid;
    logic [31: 0] n_rdata;
    logic         reg_re;

    // -- �ǂݏo������    
    always_comb begin
        n_arready = AXI_CTRL_ARREADY;
        n_rvalid  = AXI_CTRL_RVALID;
        reg_re    = 1'b0;
        if (~ AXI_CTRL_ARREADY & AXI_CTRL_ARVALID & ~ AXI_CTRL_RVALID) begin
            n_arready = 1'b1; // 1 -> 2
        end else if (AXI_CTRL_ARREADY & AXI_CTRL_ARVALID) begin
            n_arready = 1'b0; // 2 -> 3
            n_rvalid  = 1'b1;
            reg_re    = 1'b1; 
        end else if (AXI_CTRL_RVALID & AXI_CTRL_RREADY) begin
            n_rvalid  = 1'b0; // 3 -> 4
        end
    end

    always_ff @ (posedge AXI_CTRL_ACLK) begin
        if (~ AXI_CTRL_ARESETN) begin
            AXI_CTRL_ARREADY <= 1'b0;
            AXI_CTRL_RVALID  <= 1'b0;
            AXI_CTRL_RDATA   <= 0;
            d_araddr         <= 2'b00;
        end else begin
            AXI_CTRL_ARREADY <= n_arready;
            AXI_CTRL_RVALID  <= n_rvalid;
            if (reg_re) begin
                AXI_CTRL_RDATA   <= n_rdata;
            end
            if (n_arready) begin
                d_araddr         <= AXI_CTRL_ARADDR[3:2];
            end
        end
    end

    // -- �ǂݏo���f�[�^
    always_comb begin
        if (d_araddr == 2'd0) begin
            n_rdata = {31'b0, USER_DONE};
        end else begin
            n_rdata = 0;
        end
    end
endmodule