// Testbench of a prototype of BitPack
// 2021-09-07 Naoki F., AIT
// New BSD license is applied. See COPYING for more details.

module bitpack_test ();
    reg          ACLK, ARESETN;
    wire [ 3: 0] AXI_CTRL_AWADDR;
    wire [ 2: 0] AXI_CTRL_AWPROT;
    reg          AXI_CTRL_AWVALID;
    wire         AXI_CTRL_AWREADY;
    wire [31: 0] AXI_CTRL_WDATA;
    wire [ 3: 0] AXI_CTRL_WSTRB;
    reg          AXI_CTRL_WVALID;
    wire         AXI_CTRL_WREADY;
    wire [ 1: 0] AXI_CTRL_BRESP;
    wire         AXI_CTRL_BVALID;
    wire         AXI_CTRL_BREADY;
    wire [ 3: 0] AXI_CTRL_ARADDR;
    wire [ 2: 0] AXI_CTRL_ARPROT;
    reg          AXI_CTRL_ARVALID;
    wire         AXI_CTRL_ARREADY;
    wire [31: 0] AXI_CTRL_RDATA;
    wire [ 1: 0] AXI_CTRL_RRESP;
    wire         AXI_CTRL_RVALID;
    wire         AXI_CTRL_RREADY;
    wire [ 0: 0] AXI_FIFO_ARID;
    wire [31: 0] AXI_FIFO_ARADDR;
    wire [ 7: 0] AXI_FIFO_ARLEN;
    wire [ 2: 0] AXI_FIFO_ARSIZE;
    wire [ 1: 0] AXI_FIFO_ARBURST;
    wire [ 3: 0] AXI_FIFO_ARCACHE;
    wire [ 2: 0] AXI_FIFO_ARPROT;
    wire         AXI_FIFO_ARVALID;
    wire         AXI_FIFO_ARREADY;
    wire [ 0: 0] AXI_FIFO_RID;
    wire [31: 0] AXI_FIFO_RDATA;
    wire [ 1: 0] AXI_FIFO_RRESP;
    wire         AXI_FIFO_RLAST;
    wire         AXI_FIFO_RVALID;
    wire         AXI_FIFO_RREADY;
    wire [ 0: 0] AXI_FIFO_AWID;
    wire [31: 0] AXI_FIFO_AWADDR;
    wire [ 7: 0] AXI_FIFO_AWLEN;
    wire [ 2: 0] AXI_FIFO_AWSIZE;
    wire [ 1: 0] AXI_FIFO_AWBURST;
    wire [ 3: 0] AXI_FIFO_AWCACHE;
    wire [ 2: 0] AXI_FIFO_AWPROT;
    wire         AXI_FIFO_AWVALID;
    wire         AXI_FIFO_AWREADY;
    wire [31: 0] AXI_FIFO_WDATA;
    wire [ 3: 0] AXI_FIFO_WSTRB;
    wire         AXI_FIFO_WLAST;
    wire         AXI_FIFO_WVALID;
    wire         AXI_FIFO_WREADY;
    wire [ 0: 0] AXI_FIFO_BID;
    wire [ 1: 0] AXI_FIFO_BRESP;
    wire         AXI_FIFO_BVALID;
    wire         AXI_FIFO_BREADY;

    bitpack_top top (
         ACLK,
         ARESETN,
         AXI_CTRL_AWADDR,
         AXI_CTRL_AWPROT,
         AXI_CTRL_AWVALID,
         AXI_CTRL_AWREADY,
         AXI_CTRL_WDATA,
         AXI_CTRL_WSTRB,
         AXI_CTRL_WVALID,
         AXI_CTRL_WREADY,
         AXI_CTRL_BRESP,
         AXI_CTRL_BVALID,
         AXI_CTRL_BREADY,
         AXI_CTRL_ARADDR,
         AXI_CTRL_ARPROT,
         AXI_CTRL_ARVALID,
         AXI_CTRL_ARREADY,
         AXI_CTRL_RDATA,
         AXI_CTRL_RRESP,
         AXI_CTRL_RVALID,
         AXI_CTRL_RREADY,
         AXI_FIFO_ARID,
         AXI_FIFO_ARADDR,
         AXI_FIFO_ARLEN,
         AXI_FIFO_ARSIZE,
         AXI_FIFO_ARBURST,
         AXI_FIFO_ARCACHE,
         AXI_FIFO_ARPROT,
         AXI_FIFO_ARVALID,
         AXI_FIFO_ARREADY,
         AXI_FIFO_RID,
         AXI_FIFO_RDATA,
         AXI_FIFO_RRESP,
         AXI_FIFO_RLAST,
         AXI_FIFO_RVALID,
         AXI_FIFO_RREADY,
         AXI_FIFO_AWID,
         AXI_FIFO_AWADDR,
         AXI_FIFO_AWLEN,
         AXI_FIFO_AWSIZE,
         AXI_FIFO_AWBURST,
         AXI_FIFO_AWCACHE,
         AXI_FIFO_AWPROT,
         AXI_FIFO_AWVALID,
         AXI_FIFO_AWREADY,
         AXI_FIFO_WDATA,
         AXI_FIFO_WSTRB,
         AXI_FIFO_WLAST,
         AXI_FIFO_WVALID,
         AXI_FIFO_WREADY,
         AXI_FIFO_BID,
         AXI_FIFO_BRESP,
         AXI_FIFO_BVALID,
         AXI_FIFO_BREADY);

    axi_slave_bfm #(
        .C_OFFSET_WIDTH(11))
        bfm (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .S_AXI_AWID   (AXI_FIFO_AWID   ),
        .S_AXI_AWADDR (AXI_FIFO_AWADDR ),
        .S_AXI_AWLEN  (AXI_FIFO_AWLEN  ),
        .S_AXI_AWSIZE (AXI_FIFO_AWSIZE ),
        .S_AXI_AWBURST(AXI_FIFO_AWBURST),
        .S_AXI_AWLOCK (2'b00),
        .S_AXI_AWCACHE(AXI_FIFO_AWCACHE),
        .S_AXI_AWPROT (AXI_FIFO_AWPROT ),
        .S_AXI_AWQOS  (4'b0000),
        .S_AXI_AWUSER (1'b0),
        .S_AXI_AWVALID(AXI_FIFO_AWVALID),
        .S_AXI_AWREADY(AXI_FIFO_AWREADY),
        .S_AXI_WDATA  (AXI_FIFO_WDATA  ),
        .S_AXI_WSTRB  (AXI_FIFO_WSTRB  ),
        .S_AXI_WLAST  (AXI_FIFO_WLAST  ),
        .S_AXI_WUSER  (1'b0),
        .S_AXI_WVALID (AXI_FIFO_WVALID ),
        .S_AXI_WREADY (AXI_FIFO_WREADY ),
        .S_AXI_BID    (AXI_FIFO_BID    ),
        .S_AXI_BRESP  (AXI_FIFO_BRESP  ),
        .S_AXI_BUSER  (),
        .S_AXI_BVALID (AXI_FIFO_BVALID ),
        .S_AXI_BREADY (AXI_FIFO_BREADY ),
        .S_AXI_ARID   (AXI_FIFO_ARID   ),
        .S_AXI_ARADDR (AXI_FIFO_ARADDR ),
        .S_AXI_ARLEN  (AXI_FIFO_ARLEN  ),
        .S_AXI_ARSIZE (AXI_FIFO_ARSIZE ),
        .S_AXI_ARBURST(AXI_FIFO_ARBURST),
        .S_AXI_ARLOCK (2'b00),
        .S_AXI_ARCACHE(AXI_FIFO_ARCACHE),
        .S_AXI_ARPROT (AXI_FIFO_ARPROT ),
        .S_AXI_ARQOS  (4'b0000),
        .S_AXI_ARUSER (1'b0),
        .S_AXI_ARVALID(AXI_FIFO_ARVALID),
        .S_AXI_ARREADY(AXI_FIFO_ARREADY),
        .S_AXI_RID    (AXI_FIFO_RID    ),
        .S_AXI_RDATA  (AXI_FIFO_RDATA  ),
        .S_AXI_RRESP  (AXI_FIFO_RRESP  ),
        .S_AXI_RLAST  (AXI_FIFO_RLAST  ),
        .S_AXI_RUSER  (),
        .S_AXI_RVALID (AXI_FIFO_RVALID ),
        .S_AXI_RREADY (AXI_FIFO_RREADY ));

    assign AXI_CTRL_AWPROT = 3'b000;
    assign AXI_CTRL_WSTRB  = 4'b1111;
    assign AXI_CTRL_BREADY = 1'b1;
    assign AXI_CTRL_ARPROT = 3'b000;
    assign AXI_CTRL_RREADY = 1'b1;

    reg [2:0]  write_step;
    reg [2:0]  read_step;
    reg [31:0] total_read, total_write;
    reg        finalize;

    assign AXI_CTRL_AWADDR = {~ write_step[1:0], 2'b00};
    assign AXI_CTRL_WDATA  = (write_step == 3'd0) ? 32'h00001000 :
                             (write_step == 3'd1) ? 32'h00000400 :
                             (write_step == 3'd2) ? 32'h00000000 :
                             (write_step == 3'd3) ? 32'h00000001 : 32'h00000000;
    assign AXI_CTRL_ARADDR = 4'h0;

    always begin
        ACLK = 1'b1; #5;
        ACLK = 1'b0; #5;
    end

    initial begin
        ARESETN = 1'b0; #25;
        ARESETN = 1'b1;
    end

    // initialization / finalization
    integer count, fd, ret;
    reg [31:0] ram_data;

    initial begin
        fd = $fopen("input.txt", "r");
        if (fd == 0) begin
            $display("!! failed to open file\n");
            $finish;
        end
        count = 0;
        while ($feof(fd) == 0) begin
            ret = $fscanf(fd, "%h\n", ram_data);
            bfm.ram_array[count] = ram_data;
            count = count + 1'b1;
        end
        $fclose(fd);

        wait (ARESETN);
        wait (finalize);
        fd = $fopen("output.txt", "w");
        count = 'h100;
        while (^bfm.ram_array[count] !== 1'bx) begin
            ram_data = bfm.ram_array[count];
            $fdisplay(fd, "%h", ram_data);
            count = count + 1'b1;
        end
        $fclose(fd);
        $finish;
    end

    // state machine
    always @ (posedge ACLK) begin
        if (~ ARESETN) begin
            read_step        <= 3'd0;
            write_step       <= 3'd0;
            total_read       <= 0;
            total_write      <= 0;
            finalize         <= 1'b0;
            AXI_CTRL_AWVALID <= 1'b1;
            AXI_CTRL_WVALID  <= 1'b1;
            AXI_CTRL_ARVALID <= 1'b0;
        end else begin
            if (read_step[1:0] == 2'd0) begin
                if (~ AXI_CTRL_AWVALID & ~ AXI_CTRL_WVALID) begin
                    if (write_step != 3'd7) begin
                        AXI_CTRL_AWVALID <= 1'b1;
                        AXI_CTRL_WVALID  <= 1'b1;
                        write_step       <= (write_step == 3'd3) ? 3'd7 : write_step + 1'b1;
                    end else begin
                        AXI_CTRL_ARVALID <= 1'b1;
                        read_step        <= read_step + 1'b1;
                    end
                end else begin
                    if (AXI_CTRL_AWREADY) begin
                        AXI_CTRL_AWVALID <= 1'b0;
                    end
                    if (AXI_CTRL_WREADY) begin
                        AXI_CTRL_WVALID  <= 1'b0;
                    end
                end
            end else if (read_step[1:0] != 2'd3) begin
                if (AXI_CTRL_ARVALID) begin
                    AXI_CTRL_ARVALID <= ~ AXI_CTRL_ARREADY;
                end else if (AXI_CTRL_RVALID) begin
                    AXI_CTRL_ARVALID <= 1'b1;
                    read_step        <= (AXI_CTRL_RDATA[0] == read_step[1]) ? read_step + 1'b1 : read_step;
                end
            end else if (read_step == 3'd3) begin
                // circuit is evaluated twice to find errors due to uninitialized states
                AXI_CTRL_AWVALID <= 1'b1;
                AXI_CTRL_WVALID  <= 1'b1;
                read_step        <= read_step + 1'b1;
                write_step       <= 3'd3;
            end else begin
                finalize         <= 1'b1;
            end
            if (AXI_FIFO_RVALID & AXI_FIFO_RREADY) begin
                total_read  <= total_read + 1'b1;
            end
            if (AXI_FIFO_WVALID & AXI_FIFO_WREADY) begin
                total_write <= total_write + 1'b1;
            end
        end
    end

endmodule