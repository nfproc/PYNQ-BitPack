// BitPack Top Module
// 2021-09-07 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module bitpack_top (
    input          ACLK,
    input          ARESETN,
    // AXI Lite for controller
    input  [ 3: 0] AXI_CTRL_AWADDR,
    input  [ 2: 0] AXI_CTRL_AWPROT,
    input          AXI_CTRL_AWVALID,
    output         AXI_CTRL_AWREADY,
    input  [31: 0] AXI_CTRL_WDATA,
    input  [ 3: 0] AXI_CTRL_WSTRB,
    input          AXI_CTRL_WVALID,
    output         AXI_CTRL_WREADY,
    output [ 1: 0] AXI_CTRL_BRESP,
    output         AXI_CTRL_BVALID,
    input          AXI_CTRL_BREADY,
    input  [ 3: 0] AXI_CTRL_ARADDR,
    input  [ 2: 0] AXI_CTRL_ARPROT,
    input          AXI_CTRL_ARVALID,
    output         AXI_CTRL_ARREADY,
    output [31: 0] AXI_CTRL_RDATA,
    output [ 1: 0] AXI_CTRL_RRESP,
    output         AXI_CTRL_RVALID,
    input          AXI_CTRL_RREADY,
    // AXI Full for data mover
    output [ 0: 0] AXI_FIFO_ARID,
    output [31: 0] AXI_FIFO_ARADDR,
    output [ 7: 0] AXI_FIFO_ARLEN,
    output [ 2: 0] AXI_FIFO_ARSIZE,
    output [ 1: 0] AXI_FIFO_ARBURST,
    output [ 3: 0] AXI_FIFO_ARCACHE,
    output [ 2: 0] AXI_FIFO_ARPROT,
    output         AXI_FIFO_ARVALID,
    input          AXI_FIFO_ARREADY,
    input  [ 0: 0] AXI_FIFO_RID,
    input  [31: 0] AXI_FIFO_RDATA,
    input  [ 1: 0] AXI_FIFO_RRESP,
    input          AXI_FIFO_RLAST,
    input          AXI_FIFO_RVALID,
    output         AXI_FIFO_RREADY,
    output [ 0: 0] AXI_FIFO_AWID,
    output [31: 0] AXI_FIFO_AWADDR,
    output [ 7: 0] AXI_FIFO_AWLEN,
    output [ 2: 0] AXI_FIFO_AWSIZE,
    output [ 1: 0] AXI_FIFO_AWBURST,
    output [ 3: 0] AXI_FIFO_AWCACHE,
    output [ 2: 0] AXI_FIFO_AWPROT,
    output         AXI_FIFO_AWVALID,
    input          AXI_FIFO_AWREADY,
    output [31: 0] AXI_FIFO_WDATA,
    output [ 7: 0] AXI_FIFO_WSTRB,
    output         AXI_FIFO_WLAST,
    output         AXI_FIFO_WVALID,
    input          AXI_FIFO_WREADY,
    input  [ 0: 0] AXI_FIFO_BID,
    input  [ 1: 0] AXI_FIFO_BRESP,
    input          AXI_FIFO_BVALID,
    output         AXI_FIFO_BREADY);
    
    // AXI Lite <-> User Circuit Wrapper
    wire   [31: 0] user_src, user_dst, user_size;
    wire           user_go, user_done;

    // AXI Full <-> User Circuit Wrapper
    wire           fifo_busy;
    wire   [31: 0] read_addr;
    wire   [15: 0] read_count;
    wire           read_req, read_busy;
    wire   [31: 0] read_data;
    wire           read_valid, read_ready;
    wire   [31: 0] write_addr;
    wire   [15: 0] write_count;
    wire           write_req, write_busy;
    wire   [31: 0] write_data;
    wire           write_valid, write_ready;

    AXI_ctrl ctrl (
        .AXI_CTRL_ACLK   (ACLK),
        .AXI_CTRL_ARESETN(ARESETN),
        .AXI_CTRL_AWADDR (AXI_CTRL_AWADDR),
        .AXI_CTRL_AWPROT (AXI_CTRL_AWPROT),
        .AXI_CTRL_AWVALID(AXI_CTRL_AWVALID),
        .AXI_CTRL_AWREADY(AXI_CTRL_AWREADY),
        .AXI_CTRL_WDATA  (AXI_CTRL_WDATA),
        .AXI_CTRL_WSTRB  (AXI_CTRL_WSTRB),
        .AXI_CTRL_WVALID (AXI_CTRL_WVALID),
        .AXI_CTRL_WREADY (AXI_CTRL_WREADY),
        .AXI_CTRL_BRESP  (AXI_CTRL_BRESP),
        .AXI_CTRL_BVALID (AXI_CTRL_BVALID),
        .AXI_CTRL_BREADY (AXI_CTRL_BREADY),
        .AXI_CTRL_ARADDR (AXI_CTRL_ARADDR),
        .AXI_CTRL_ARPROT (AXI_CTRL_ARPROT),
        .AXI_CTRL_ARVALID(AXI_CTRL_ARVALID),
        .AXI_CTRL_ARREADY(AXI_CTRL_ARREADY),
        .AXI_CTRL_RDATA  (AXI_CTRL_RDATA),
        .AXI_CTRL_RRESP  (AXI_CTRL_RRESP),
        .AXI_CTRL_RVALID (AXI_CTRL_RVALID),
        .AXI_CTRL_RREADY (AXI_CTRL_RREADY),
        .USER_SRC        (user_src),
        .USER_DST        (user_dst),
        .USER_SIZE       (user_size),
        .USER_GO         (user_go),
        .USER_DONE       (user_done & ~ fifo_busy));

    AXI_FIFO fifo (
        .ACLK         (ACLK),
        .ARESETN      (ARESETN),
        .AXI_M_ARID   (AXI_FIFO_ARID),
        .AXI_M_ARADDR (AXI_FIFO_ARADDR),
        .AXI_M_ARLEN  (AXI_FIFO_ARLEN),
        .AXI_M_ARSIZE (AXI_FIFO_ARSIZE),
        .AXI_M_ARBURST(AXI_FIFO_ARBURST),
        .AXI_M_ARCACHE(AXI_FIFO_ARCACHE),
        .AXI_M_ARPROT (AXI_FIFO_ARPROT),
        .AXI_M_ARVALID(AXI_FIFO_ARVALID),
        .AXI_M_ARREADY(AXI_FIFO_ARREADY),
        .AXI_M_RID    (AXI_FIFO_RID),
        .AXI_M_RDATA  (AXI_FIFO_RDATA),
        .AXI_M_RRESP  (AXI_FIFO_RRESP),
        .AXI_M_RLAST  (AXI_FIFO_RLAST),
        .AXI_M_RVALID (AXI_FIFO_RVALID),
        .AXI_M_RREADY (AXI_FIFO_RREADY),
        .AXI_M_AWID   (AXI_FIFO_AWID),
        .AXI_M_AWADDR (AXI_FIFO_AWADDR),
        .AXI_M_AWLEN  (AXI_FIFO_AWLEN),
        .AXI_M_AWSIZE (AXI_FIFO_AWSIZE),
        .AXI_M_AWBURST(AXI_FIFO_AWBURST),
        .AXI_M_AWCACHE(AXI_FIFO_AWCACHE),
        .AXI_M_AWPROT (AXI_FIFO_AWPROT),
        .AXI_M_AWVALID(AXI_FIFO_AWVALID),
        .AXI_M_AWREADY(AXI_FIFO_AWREADY),
        .AXI_M_WDATA  (AXI_FIFO_WDATA),
        .AXI_M_WSTRB  (AXI_FIFO_WSTRB),
        .AXI_M_WLAST  (AXI_FIFO_WLAST),
        .AXI_M_WVALID (AXI_FIFO_WVALID),
        .AXI_M_WREADY (AXI_FIFO_WREADY),
        .AXI_M_BID    (AXI_FIFO_BID),
        .AXI_M_BRESP  (AXI_FIFO_BRESP),
        .AXI_M_BVALID (AXI_FIFO_BVALID),
        .AXI_M_BREADY (AXI_FIFO_BREADY),
        .FIFO_BUSY    (fifo_busy),
        .READ_ADDR    (read_addr),
        .READ_COUNT   (read_count),
        .READ_REQ     (read_req),
        .READ_BUSY    (read_busy),
        .READ_DATA    (read_data),
        .READ_VALID   (read_valid),
        .READ_READY   (read_ready),
        .WRITE_ADDR   (write_addr),
        .WRITE_COUNT  (write_count),
        .WRITE_REQ    (write_req),
        .WRITE_BUSY   (write_busy),
        .WRITE_DATA   (write_data),
        .WRITE_VALID  (write_valid),
        .WRITE_READY  (write_ready));
        
    user_wrapper wrap (
        .CLK        (ACLK),
        .RST_X      (ARESETN),
        .GO         (user_go),
        .DONE       (user_done),
        .SRC        (user_src),
        .DST        (user_dst),
        .SIZE       (user_size),
        .READ_ADDR  (read_addr),
        .READ_COUNT (read_count),
        .READ_REQ   (read_req),
        .READ_BUSY  (read_busy),
        .READ_DATA  (read_data),
        .READ_VALID (read_valid),
        .READ_READY (read_ready),
        .WRITE_ADDR (write_addr),
        .WRITE_COUNT(write_count),
        .WRITE_REQ  (write_req),
        .WRITE_BUSY (write_busy),
        .WRITE_DATA (write_data),
        .WRITE_VALID(write_valid),
        .WRITE_READY(write_ready));
endmodule