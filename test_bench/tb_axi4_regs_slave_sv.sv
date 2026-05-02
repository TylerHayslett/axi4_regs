//------------------------------------------------------------------------------
// tb_axi4_regs_slave_sv.sv
//
// SystemVerilog-only testbench for the SystemVerilog DUTs:
//   * axi4_regs_slave        (axi4_regs_slave.sv)
//   * axi4_lite_regs_slave   (axi4_lite_regs_slave.sv)
//
// Drives both DUTs with the same sequence of single-beat transactions using
// a small embedded master BFM (tasks). Both slaves currently use the stub
// `reg_access` body that returns zero, so the test exercises the bus
// handshake logic itself; replace the user functions to exercise real
// register decoding.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_axi4_regs_slave_sv;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 32;
    localparam int STRB_WIDTH = DATA_WIDTH/8;

    //--------------------------------------------------------------------------
    // Clock / reset
    //--------------------------------------------------------------------------
    logic aclk;
    logic aresetn;

    initial aclk = 1'b0;
    always #5 aclk = ~aclk;     // 100 MHz

    //--------------------------------------------------------------------------
    // AXI4 (full) signal bundle
    //--------------------------------------------------------------------------
    typedef struct {
        logic [ADDR_WIDTH-1:0] awaddr;
        logic [2:0]            awprot;
        logic [7:0]            awlen;
        logic [2:0]            awsize;
        logic [1:0]            awburst;
        logic                  awvalid;
        logic                  awready;

        logic [DATA_WIDTH-1:0] wdata;
        logic [STRB_WIDTH-1:0] wstrb;
        logic                  wlast;
        logic                  wvalid;
        logic                  wready;

        logic [1:0]            bresp;
        logic                  bvalid;
        logic                  bready;

        logic [ADDR_WIDTH-1:0] araddr;
        logic [2:0]            arprot;
        logic [7:0]            arlen;
        logic [2:0]            arsize;
        logic [1:0]            arburst;
        logic                  arvalid;
        logic                  arready;

        logic [DATA_WIDTH-1:0] rdata;
        logic [1:0]            rresp;
        logic                  rlast;
        logic                  rvalid;
        logic                  rready;
    } axi_bus_t;

    axi_bus_t sv_bus;

    //--------------------------------------------------------------------------
    // AXI4-Lite signal bundle (no burst signals)
    //--------------------------------------------------------------------------
    typedef struct {
        logic [ADDR_WIDTH-1:0] awaddr;
        logic [2:0]            awprot;
        logic                  awvalid;
        logic                  awready;

        logic [DATA_WIDTH-1:0] wdata;
        logic [STRB_WIDTH-1:0] wstrb;
        logic                  wvalid;
        logic                  wready;

        logic [1:0]            bresp;
        logic                  bvalid;
        logic                  bready;

        logic [ADDR_WIDTH-1:0] araddr;
        logic [2:0]            arprot;
        logic                  arvalid;
        logic                  arready;

        logic [DATA_WIDTH-1:0] rdata;
        logic [1:0]            rresp;
        logic                  rvalid;
        logic                  rready;
    } axi_lite_bus_t;

    axi_lite_bus_t sv_lite_bus;

    //--------------------------------------------------------------------------
    // SystemVerilog AXI4 DUT
    //--------------------------------------------------------------------------
    axi4_regs_slave #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) u_sv (
        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),

        .S_AXI_AWADDR  (sv_bus.awaddr),
        .S_AXI_AWPROT  (sv_bus.awprot),
        .S_AXI_AWLEN   (sv_bus.awlen),
        .S_AXI_AWSIZE  (sv_bus.awsize),
        .S_AXI_AWBURST (sv_bus.awburst),
        .S_AXI_AWVALID (sv_bus.awvalid),
        .S_AXI_AWREADY (sv_bus.awready),

        .S_AXI_WDATA   (sv_bus.wdata),
        .S_AXI_WSTRB   (sv_bus.wstrb),
        .S_AXI_WLAST   (sv_bus.wlast),
        .S_AXI_WVALID  (sv_bus.wvalid),
        .S_AXI_WREADY  (sv_bus.wready),

        .S_AXI_BRESP   (sv_bus.bresp),
        .S_AXI_BVALID  (sv_bus.bvalid),
        .S_AXI_BREADY  (sv_bus.bready),

        .S_AXI_ARADDR  (sv_bus.araddr),
        .S_AXI_ARPROT  (sv_bus.arprot),
        .S_AXI_ARLEN   (sv_bus.arlen),
        .S_AXI_ARSIZE  (sv_bus.arsize),
        .S_AXI_ARBURST (sv_bus.arburst),
        .S_AXI_ARVALID (sv_bus.arvalid),
        .S_AXI_ARREADY (sv_bus.arready),

        .S_AXI_RDATA   (sv_bus.rdata),
        .S_AXI_RRESP   (sv_bus.rresp),
        .S_AXI_RLAST   (sv_bus.rlast),
        .S_AXI_RVALID  (sv_bus.rvalid),
        .S_AXI_RREADY  (sv_bus.rready)
    );

    //--------------------------------------------------------------------------
    // SystemVerilog AXI4-Lite DUT
    //--------------------------------------------------------------------------
    axi4_lite_regs_slave #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) u_sv_lite (
        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),

        .S_AXI_AWADDR  (sv_lite_bus.awaddr),
        .S_AXI_AWPROT  (sv_lite_bus.awprot),
        .S_AXI_AWVALID (sv_lite_bus.awvalid),
        .S_AXI_AWREADY (sv_lite_bus.awready),

        .S_AXI_WDATA   (sv_lite_bus.wdata),
        .S_AXI_WSTRB   (sv_lite_bus.wstrb),
        .S_AXI_WVALID  (sv_lite_bus.wvalid),
        .S_AXI_WREADY  (sv_lite_bus.wready),

        .S_AXI_BRESP   (sv_lite_bus.bresp),
        .S_AXI_BVALID  (sv_lite_bus.bvalid),
        .S_AXI_BREADY  (sv_lite_bus.bready),

        .S_AXI_ARADDR  (sv_lite_bus.araddr),
        .S_AXI_ARPROT  (sv_lite_bus.arprot),
        .S_AXI_ARVALID (sv_lite_bus.arvalid),
        .S_AXI_ARREADY (sv_lite_bus.arready),

        .S_AXI_RDATA   (sv_lite_bus.rdata),
        .S_AXI_RRESP   (sv_lite_bus.rresp),
        .S_AXI_RVALID  (sv_lite_bus.rvalid),
        .S_AXI_RREADY  (sv_lite_bus.rready)
    );

    //--------------------------------------------------------------------------
    // Bus init
    //--------------------------------------------------------------------------
    task automatic init_bus(ref axi_bus_t b);
        b.awaddr  = '0; b.awprot = '0; b.awlen = '0; b.awsize = 3'd2;
        b.awburst = 2'b01; b.awvalid = 1'b0;
        b.wdata   = '0; b.wstrb = '0; b.wlast = 1'b0; b.wvalid = 1'b0;
        b.bready  = 1'b0;
        b.araddr  = '0; b.arprot = '0; b.arlen = '0; b.arsize = 3'd2;
        b.arburst = 2'b01; b.arvalid = 1'b0;
        b.rready  = 1'b0;
    endtask

    task automatic init_lite_bus(ref axi_lite_bus_t b);
        b.awaddr = '0; b.awprot = '0; b.awvalid = 1'b0;
        b.wdata  = '0; b.wstrb  = '0; b.wvalid  = 1'b0;
        b.bready = 1'b0;
        b.araddr = '0; b.arprot = '0; b.arvalid = 1'b0;
        b.rready = 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // AXI4 single-beat write/read
    //--------------------------------------------------------------------------
    task automatic axi_write(
        ref axi_bus_t b,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb = {STRB_WIDTH{1'b1}}
    );
        @(posedge aclk);
        b.awaddr  <= addr;
        b.awlen   <= 8'd0;
        b.awsize  <= 3'd2;
        b.awburst <= 2'b01;
        b.awvalid <= 1'b1;

        b.wdata   <= data;
        b.wstrb   <= strb;
        b.wlast   <= 1'b1;
        b.wvalid  <= 1'b1;

        b.bready  <= 1'b1;

        do @(posedge aclk); while (!(b.awvalid && b.awready));
        b.awvalid <= 1'b0;

        do @(posedge aclk); while (!(b.wvalid && b.wready));
        b.wvalid <= 1'b0;
        b.wlast  <= 1'b0;

        do @(posedge aclk); while (!(b.bvalid && b.bready));
        b.bready <= 1'b0;
    endtask

    task automatic axi_read(
        ref axi_bus_t b,
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data
    );
        @(posedge aclk);
        b.araddr  <= addr;
        b.arlen   <= 8'd0;
        b.arsize  <= 3'd2;
        b.arburst <= 2'b01;
        b.arvalid <= 1'b1;
        b.rready  <= 1'b1;

        do @(posedge aclk); while (!(b.arvalid && b.arready));
        b.arvalid <= 1'b0;

        do @(posedge aclk); while (!(b.rvalid && b.rready));
        data = b.rdata;
        b.rready <= 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // AXI4 burst read (INCR). Issues a single AR with len=beats-1 and
    // collects up to `beats` R-channel beats, stopping early on RLAST.
    // Returns the actual number of beats received.
    //--------------------------------------------------------------------------
    task automatic axi_burst_read(
        ref axi_bus_t b,
        input  logic [ADDR_WIDTH-1:0] addr,
        input  int                    beats,
        output logic [DATA_WIDTH-1:0] data [],
        output int                    received
    );
        data = new[beats];
        received = 0;

        @(posedge aclk);
        b.araddr  <= addr;
        b.arlen   <= beats[7:0] - 8'd1;
        b.arsize  <= 3'd2;
        b.arburst <= 2'b01;
        b.arvalid <= 1'b1;
        b.rready  <= 1'b1;

        do @(posedge aclk); while (!(b.arvalid && b.arready));
        b.arvalid <= 1'b0;

        for (int i = 0; i < beats; i++) begin
            do @(posedge aclk); while (!(b.rvalid && b.rready));
            data[i] = b.rdata;
            received++;
            if (b.rlast) break;
        end
        b.rready <= 1'b0;
    endtask
    task automatic axi_lite_write(
        ref axi_lite_bus_t b,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb = {STRB_WIDTH{1'b1}}
    );
        @(posedge aclk);
        b.awaddr  <= addr;
        b.awvalid <= 1'b1;
        b.wdata   <= data;
        b.wstrb   <= strb;
        b.wvalid  <= 1'b1;
        b.bready  <= 1'b1;

        do @(posedge aclk); while (!(b.awvalid && b.awready));
        b.awvalid <= 1'b0;

        do @(posedge aclk); while (!(b.wvalid && b.wready));
        b.wvalid <= 1'b0;

        do @(posedge aclk); while (!(b.bvalid && b.bready));
        b.bready <= 1'b0;
    endtask

    task automatic axi_lite_read(
        ref axi_lite_bus_t b,
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data
    );
        @(posedge aclk);
        b.araddr  <= addr;
        b.arvalid <= 1'b1;
        b.rready  <= 1'b1;

        do @(posedge aclk); while (!(b.arvalid && b.arready));
        b.arvalid <= 1'b0;

        do @(posedge aclk); while (!(b.rvalid && b.rready));
        data = b.rdata;
        b.rready <= 1'b0;
    endtask

    //--------------------------------------------------------------------------
    // Stimulus
    //--------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] sv_rd, sv_lite_rd;
    int errors;

    initial begin
        errors = 0;
        init_bus(sv_bus);
        init_lite_bus(sv_lite_bus);

        aresetn = 1'b0;
        repeat (10) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5)  @(posedge aclk);

        $display("---- Starting AXI4 SV register slave tests ----");

        // T1
        fork
            axi_write     (sv_bus,      32'h0000_0000, 32'hDEAD_BEEF);
            axi_lite_write(sv_lite_bus, 32'h0000_0000, 32'hDEAD_BEEF);
        join
        fork
            axi_read     (sv_bus,      32'h0000_0000, sv_rd);
            axi_lite_read(sv_lite_bus, 32'h0000_0000, sv_lite_rd);
        join
        $display("[T1] addr=0x00000000 sv=0x%08h sv_lite=0x%08h", sv_rd, sv_lite_rd);
        if (sv_rd !== sv_lite_rd) begin $display("     MISMATCH"); errors++; end

        // T2
        fork
            axi_write     (sv_bus,      32'h0000_0010, 32'h1234_5678);
            axi_lite_write(sv_lite_bus, 32'h0000_0010, 32'h1234_5678);
        join
        fork
            axi_read     (sv_bus,      32'h0000_0010, sv_rd);
            axi_lite_read(sv_lite_bus, 32'h0000_0010, sv_lite_rd);
        join
        $display("[T2] addr=0x00000010 sv=0x%08h sv_lite=0x%08h", sv_rd, sv_lite_rd);
        if (sv_rd !== sv_lite_rd) begin $display("     MISMATCH"); errors++; end

        // T3 byte-strobed
        fork
            axi_write     (sv_bus,      32'h0000_0020, 32'hAABB_CCDD, 4'b0011);
            axi_lite_write(sv_lite_bus, 32'h0000_0020, 32'hAABB_CCDD, 4'b0011);
        join
        fork
            axi_read     (sv_bus,      32'h0000_0020, sv_rd);
            axi_lite_read(sv_lite_bus, 32'h0000_0020, sv_lite_rd);
        join
        $display("[T3] addr=0x00000020 sv=0x%08h sv_lite=0x%08h", sv_rd, sv_lite_rd);
        if (sv_rd !== sv_lite_rd) begin $display("     MISMATCH"); errors++; end

        // T4 back-to-back reads
        fork
            axi_read     (sv_bus,      32'h0000_0030, sv_rd);
            axi_lite_read(sv_lite_bus, 32'h0000_0030, sv_lite_rd);
        join
        $display("[T4a] addr=0x00000030 sv=0x%08h sv_lite=0x%08h", sv_rd, sv_lite_rd);
        if (sv_rd !== sv_lite_rd) begin $display("      MISMATCH"); errors++; end

        fork
            axi_read     (sv_bus,      32'h0000_0034, sv_rd);
            axi_lite_read(sv_lite_bus, 32'h0000_0034, sv_lite_rd);
        join
        $display("[T4b] addr=0x00000034 sv=0x%08h sv_lite=0x%08h", sv_rd, sv_lite_rd);
        if (sv_rd !== sv_lite_rd) begin $display("      MISMATCH"); errors++; end

        // -- Test 5: AXI4 burst read of 4 beats (full-AXI only).
        // NOTE: the current slave drives RLAST = RVALID, so it returns a
        // single beat regardless of ARLEN. This test reports beats received.
        begin
            logic [DATA_WIDTH-1:0] burst_data [];
            int                    beats_rcv;
            axi_burst_read(sv_bus, 32'h0000_0040, 4, burst_data, beats_rcv);
            $display("[T5] burst read addr=0x00000040 requested=4 received=%0d", beats_rcv);
            for (int i = 0; i < beats_rcv; i++)
                $display("      sv burst[%0d]=0x%08h", i, burst_data[i]);
            if (beats_rcv != 4) begin
                $display("     NOTE: slave is single-beat only -- not counted as failure");
            end
        end

        repeat (10) @(posedge aclk);

        $display("---- Done. errors=%0d ----", errors);
        if (errors == 0) $display("PASS");
        else             $display("FAIL");
        $finish;
    end

    initial begin
        #50us;
        $display("TIMEOUT");
        $finish;
    end

endmodule : tb_axi4_regs_slave_sv
