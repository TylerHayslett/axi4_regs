//------------------------------------------------------------------------------
// axi4_regs_slave.sv
//
// Basic AXI4 (full) compliant memory-mapped slave that supports single-beat
// read and write transactions. Read and write data paths are routed to an
// external user task (`reg_access`) declared in `axi4_regs_user_pkg`. The
// user is responsible for decoding the word address and producing or
// consuming the actual register data.
//
// Notes:
//   * Supports AWLEN/ARLEN = 0 (single-beat) cleanly. Bursts are accepted but
//     treated as repeated single-beat accesses to the same address. Extend
//     the address counters for true burst support.
//   * Always returns BRESP/RRESP = 2'b00 (OKAY).
//   * Default DATA_WIDTH = 32, ADDR_WIDTH = 32.
//   * Replace the body of `axi4_regs_user_pkg::reg_access` in your project to
//     implement real register behavior.
//------------------------------------------------------------------------------

package axi4_regs_user_pkg;

    //--------------------------------------------------------------------------
    // reg_access
    //
    //   addr      : word-aligned byte address
    //   write_en  : 1 on a write cycle, 0 on a read cycle
    //   wstrb     : per-byte write enables (valid when write_en = 1)
    //   wdata     : write data (valid when write_en = 1)
    //   rdata     : read data driven back on a read cycle (output)
    //
    // Must be combinational from the bus FSM's perspective: do not use any
    // blocking delays or event controls in synthesizable implementations.
    //--------------------------------------------------------------------------
    function automatic void reg_access(
        input  logic [31:0] addr,
        input  logic        write_en,
        input  logic [3:0]  wstrb,
        input  logic [31:0] wdata,
        output logic [31:0] rdata
    );
        // Default stub: writes are dropped, reads return zero.
        // Replace this body in your project with real register decoding.
        rdata = 32'h0000_0000;
    endfunction

endpackage : axi4_regs_user_pkg


//------------------------------------------------------------------------------
// AXI4 slave
//------------------------------------------------------------------------------
module axi4_regs_slave #(
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 32
) (
    // Global
    input  logic                              S_AXI_ACLK,
    input  logic                              S_AXI_ARESETN,

    // Write address channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  logic [2:0]                        S_AXI_AWPROT,
    input  logic [7:0]                        S_AXI_AWLEN,
    input  logic [2:0]                        S_AXI_AWSIZE,
    input  logic [1:0]                        S_AXI_AWBURST,
    input  logic                              S_AXI_AWVALID,
    output logic                              S_AXI_AWREADY,

    // Write data channel
    input  logic [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  logic                              S_AXI_WLAST,
    input  logic                              S_AXI_WVALID,
    output logic                              S_AXI_WREADY,

    // Write response channel
    output logic [1:0]                        S_AXI_BRESP,
    output logic                              S_AXI_BVALID,
    input  logic                              S_AXI_BREADY,

    // Read address channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  logic [2:0]                        S_AXI_ARPROT,
    input  logic [7:0]                        S_AXI_ARLEN,
    input  logic [2:0]                        S_AXI_ARSIZE,
    input  logic [1:0]                        S_AXI_ARBURST,
    input  logic                              S_AXI_ARVALID,
    output logic                              S_AXI_ARREADY,

    // Read data channel
    output logic [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output logic [1:0]                        S_AXI_RRESP,
    output logic                              S_AXI_RLAST,
    output logic                              S_AXI_RVALID,
    input  logic                              S_AXI_RREADY
);

    import axi4_regs_user_pkg::*;

    // Latched addresses
    logic [C_S_AXI_ADDR_WIDTH-1:0]     awaddr_q;
    logic [C_S_AXI_ADDR_WIDTH-1:0]     araddr_q;

    // Internal handshake signals
    logic awready_i;
    logic wready_i;
    logic bvalid_i;
    logic arready_i;
    logic rvalid_i;

    // Procedure interface
    logic [C_S_AXI_ADDR_WIDTH-1:0]     acc_addr;
    logic                              acc_write_en;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] acc_wstrb;
    logic [C_S_AXI_DATA_WIDTH-1:0]     acc_wdata;
    logic [C_S_AXI_DATA_WIDTH-1:0]     acc_rdata;

    logic write_fire;

    //--------------------------------------------------------------------------
    // Output assignments
    //--------------------------------------------------------------------------
    assign S_AXI_AWREADY = awready_i;
    assign S_AXI_WREADY  = wready_i;
    assign S_AXI_BVALID  = bvalid_i;
    assign S_AXI_BRESP   = 2'b00; // OKAY

    assign S_AXI_ARREADY = arready_i;
    assign S_AXI_RVALID  = rvalid_i;
    assign S_AXI_RRESP   = 2'b00; // OKAY
    assign S_AXI_RLAST   = rvalid_i; // single-beat

    assign S_AXI_RDATA   = acc_rdata;

    //--------------------------------------------------------------------------
    // Write address handshake: accept AW when no outstanding write
    //--------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            awready_i <= 1'b0;
            awaddr_q  <= '0;
        end else begin
            if (!awready_i && S_AXI_AWVALID && !wready_i && !bvalid_i) begin
                awready_i <= 1'b1;
                awaddr_q  <= S_AXI_AWADDR;
            end else begin
                awready_i <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Write data handshake: assert WREADY one cycle after AW captured
    //--------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            wready_i <= 1'b0;
        end else begin
            if (!wready_i && awready_i && S_AXI_AWVALID) begin
                wready_i <= 1'b1;
            end else if (S_AXI_WVALID && wready_i) begin
                wready_i <= 1'b0;
            end
        end
    end

    assign write_fire = S_AXI_WVALID & wready_i;

    //--------------------------------------------------------------------------
    // Write response: assert BVALID after W beat is captured
    //--------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            bvalid_i <= 1'b0;
        end else begin
            if (!bvalid_i && write_fire) begin
                bvalid_i <= 1'b1;
            end else if (bvalid_i && S_AXI_BREADY) begin
                bvalid_i <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Read address handshake
    //--------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            arready_i <= 1'b0;
            araddr_q  <= '0;
        end else begin
            if (!arready_i && S_AXI_ARVALID && !rvalid_i) begin
                arready_i <= 1'b1;
                araddr_q  <= S_AXI_ARADDR;
            end else begin
                arready_i <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Read data valid
    //--------------------------------------------------------------------------
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            rvalid_i <= 1'b0;
        end else begin
            if (arready_i && S_AXI_ARVALID && !rvalid_i) begin
                rvalid_i <= 1'b1;
            end else if (rvalid_i && S_AXI_RREADY) begin
                rvalid_i <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Mux address/control to the external register-access function.
    //--------------------------------------------------------------------------
    always_comb begin
        if (write_fire) begin
            acc_addr     = awaddr_q;
            acc_write_en = 1'b1;
            acc_wstrb    = S_AXI_WSTRB;
            acc_wdata    = S_AXI_WDATA;
        end else begin
            acc_addr     = araddr_q;
            acc_write_en = 1'b0;
            acc_wstrb    = '0;
            acc_wdata    = '0;
        end
    end

    //--------------------------------------------------------------------------
    // Invoke the user-supplied register-access function combinationally.
    //--------------------------------------------------------------------------
    always_comb begin
        reg_access(acc_addr, acc_write_en, acc_wstrb, acc_wdata, acc_rdata);
    end

endmodule : axi4_regs_slave
