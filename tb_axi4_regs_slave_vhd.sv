//------------------------------------------------------------------------------
// tb_axi4_regs_slave_vhd.sv
//
// Mixed-language testbench (SystemVerilog driving VHDL DUTs) for:
//   * axi4_regs_slave        (VHDL, axi4_regs_slave.vhd)
//   * axi4_lite_regs_slave   (VHDL, axi4_lite_regs_slave.vhd)
//
// To avoid name collisions with the SystemVerilog implementations the VHDL
// entities are instantiated under aliased names `axi4_regs_slave_vhd` and
// `axi4_lite_regs_slave_vhd`. Either rename the VHDL entities to those names
// or set up a tool-specific library alias before elaboration.
//
// Requires a simulator that supports mixed-language elaboration
// (Questa/ModelSim, Xcelium, Riviera-PRO, VCS with vhdlan, ...).
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_axi4_regs_slave_vhd;

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

    axi_bus_t vhd_bus;

    //--------------------------------------------------------------------------
    // AXI4-Lite signal bundle
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

    axi_lite_bus_t vhd_lite_bus;

    //--------------------------------------------------------------------------
    // VHDL AXI4 DUT (aliased name)
    //--------------------------------------------------------------------------
    axi4_regs_slave_vhd #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) u_vhd (
        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),

        .S_AXI_AWADDR  (vhd_bus.awaddr),
        .S_AXI_AWPROT  (vhd_bus.awprot),
        .S_AXI_AWLEN   (vhd_bus.awlen),
        .S_AXI_AWSIZE  (vhd_bus.awsize),
        .S_AXI_AWBURST (vhd_bus.awburst),
        .S_AXI_AWVALID (vhd_bus.awvalid),
        .S_AXI_AWREADY (vhd_bus.awready),

        .S_AXI_WDATA   (vhd_bus.wdata),
        .S_AXI_WSTRB   (vhd_bus.wstrb),
        .S_AXI_WLAST   (vhd_bus.wlast),
        .S_AXI_WVALID  (vhd_bus.wvalid),
        .S_AXI_WREADY  (vhd_bus.wready),

        .S_AXI_BRESP   (vhd_bus.bresp),
        .S_AXI_BVALID  (vhd_bus.bvalid),
        .S_AXI_BREADY  (vhd_bus.bready),

        .S_AXI_ARADDR  (vhd_bus.araddr),
        .S_AXI_ARPROT  (vhd_bus.arprot),
        .S_AXI_ARLEN   (vhd_bus.arlen),
        .S_AXI_ARSIZE  (vhd_bus.arsize),
        .S_AXI_ARBURST (vhd_bus.arburst),
        .S_AXI_ARVALID (vhd_bus.arvalid),
        .S_AXI_ARREADY (vhd_bus.arready),

        .S_AXI_RDATA   (vhd_bus.rdata),
        .S_AXI_RRESP   (vhd_bus.rresp),
        .S_AXI_RLAST   (vhd_bus.rlast),
        .S_AXI_RVALID  (vhd_bus.rvalid),
        .S_AXI_RREADY  (vhd_bus.rready)
    );

    //--------------------------------------------------------------------------
    // VHDL AXI4-Lite DUT (aliased name)
    //--------------------------------------------------------------------------
    axi4_lite_regs_slave_vhd #(
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) u_vhd_lite (
        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),

        .S_AXI_AWADDR  (vhd_lite_bus.awaddr),
        .S_AXI_AWPROT  (vhd_lite_bus.awprot),
        .S_AXI_AWVALID (vhd_lite_bus.awvalid),
        .S_AXI_AWREADY (vhd_lite_bus.awready),

        .S_AXI_WDATA   (vhd_lite_bus.wdata),
        .S_AXI_WSTRB   (vhd_lite_bus.wstrb),
        .S_AXI_WVALID  (vhd_lite_bus.wvalid),
        .S_AXI_WREADY  (vhd_lite_bus.wready),

        .S_AXI_BRESP   (vhd_lite_bus.bresp),
        .S_AXI_BVALID  (vhd_lite_bus.bvalid),
        .S_AXI_BREADY  (vhd_lite_bus.bready),

        .S_AXI_ARADDR  (vhd_lite_bus.araddr),
        .S_AXI_ARPROT  (vhd_lite_bus.arprot),
        .S_AXI_ARVALID (vhd_lite_bus.arvalid),
        .S_AXI_ARREADY (vhd_lite_bus.arready),

        .S_AXI_RDATA   (vhd_lite_bus.rdata),
        .S_AXI_RRESP   (vhd_lite_bus.rresp),
        .S_AXI_RVALID  (vhd_lite_bus.rvalid),
        .S_AXI_RREADY  (vhd_lite_bus.rready)
    );

    //--------------------------------------------------------------------------
    // Bus init
    //--------------------------------------------------------------------------
    task automatic init_bus(ref axi_bus_t b);
        b.awaddr  = '0; 
        b.awprot  = '0; 
        b.awlen   = '0; 
        b.awsize  = 3'd2;
        b.awburst = 2'b01; 
        b.awvalid = 1'b0;
        b.wdata   = '0; 
        b.wstrb   = '0; 
        b.wlast   = 1'b0; 
        b.wvalid  = 1'b0;
        b.bready  = 1'b0;
        b.araddr  = '0; 
        b.arprot  = '0; 
        b.arlen   = '0; 
        b.arsize  = 3'd2;
        b.arburst = 2'b01; 
        b.arvalid = 1'b0;
        b.rready  = 1'b0;
    endtask

    task automatic init_lite_bus(ref axi_lite_bus_t b);
        b.awaddr = '0; 
        b.awprot = '0; 
        b.awvalid = 1'b0;
        b.wdata  = '0; 
        b.wstrb  = '0; 
        b.wvalid  = 1'b0;
        b.bready = 1'b0;
        b.araddr = '0; 
        b.arprot = '0; 
        b.arvalid = 1'b0;
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
    // AXI4-Lite single-beat write/read
    //--------------------------------------------------------------------------
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
    logic [DATA_WIDTH-1:0] vhd_rd, vhd_lite_rd;
    int errors;

    initial begin
        errors = 0;
        init_bus(vhd_bus);
        init_lite_bus(vhd_lite_bus);

        aresetn = 1'b0;
        repeat (10) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5)  @(posedge aclk);

        $display("---- Starting AXI4 VHDL register slave tests ----");

        // T1
        fork
            axi_write     (vhd_bus,      32'h0000_0000, 32'hDEAD_BEEF);
            axi_lite_write(vhd_lite_bus, 32'h0000_0000, 32'hDEAD_BEEF);
        join
        fork
            axi_read     (vhd_bus,      32'h0000_0000, vhd_rd);
            axi_lite_read(vhd_lite_bus, 32'h0000_0000, vhd_lite_rd);
        join
        $display("[T1] addr=0x00000000 vhd=0x%08h vhd_lite=0x%08h", vhd_rd, vhd_lite_rd);
        if (vhd_rd !== vhd_lite_rd) begin $display("     MISMATCH"); errors++; end

        // T2
        fork
            axi_write     (vhd_bus,      32'h0000_0010, 32'h1234_5678);
            axi_lite_write(vhd_lite_bus, 32'h0000_0010, 32'h1234_5678);
        join
        fork
            axi_read     (vhd_bus,      32'h0000_0010, vhd_rd);
            axi_lite_read(vhd_lite_bus, 32'h0000_0010, vhd_lite_rd);
        join
        $display("[T2] addr=0x00000010 vhd=0x%08h vhd_lite=0x%08h", vhd_rd, vhd_lite_rd);
        if (vhd_rd !== vhd_lite_rd) begin $display("     MISMATCH"); errors++; end

        // T3 byte-strobed
        fork
            axi_write     (vhd_bus,      32'h0000_0020, 32'hAABB_CCDD, 4'b0011);
            axi_lite_write(vhd_lite_bus, 32'h0000_0020, 32'hAABB_CCDD, 4'b0011);
        join
        fork
            axi_read     (vhd_bus,      32'h0000_0020, vhd_rd);
            axi_lite_read(vhd_lite_bus, 32'h0000_0020, vhd_lite_rd);
        join
        $display("[T3] addr=0x00000020 vhd=0x%08h vhd_lite=0x%08h", vhd_rd, vhd_lite_rd);
        if (vhd_rd !== vhd_lite_rd) begin $display("     MISMATCH"); errors++; end

        // T4 back-to-back reads
        fork
            axi_read     (vhd_bus,      32'h0000_0030, vhd_rd);
            axi_lite_read(vhd_lite_bus, 32'h0000_0030, vhd_lite_rd);
        join
        $display("[T4a] addr=0x00000030 vhd=0x%08h vhd_lite=0x%08h", vhd_rd, vhd_lite_rd);
        if (vhd_rd !== vhd_lite_rd) begin $display("      MISMATCH"); errors++; end

        fork
            axi_read     (vhd_bus,      32'h0000_0034, vhd_rd);
            axi_lite_read(vhd_lite_bus, 32'h0000_0034, vhd_lite_rd);
        join
        $display("[T4b] addr=0x00000034 vhd=0x%08h vhd_lite=0x%08h", vhd_rd, vhd_lite_rd);
        if (vhd_rd !== vhd_lite_rd) begin $display("      MISMATCH"); errors++; end

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

endmodule : tb_axi4_regs_slave_vhd
