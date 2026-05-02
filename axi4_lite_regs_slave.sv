//------------------------------------------------------------------------------
// axi4_lite_regs_slave.sv
//
// Basic AXI4-Lite compliant memory-mapped slave. Supports single-beat read and
// write transactions (AXI4-Lite has no bursts, no IDs, no LOCK/CACHE/QOS, etc.)
// and routes the address/data through an external user function `reg_access`
// declared in `axi4_lite_regs_user_pkg`. Replace its body in your project to
// implement real register decoding.
//
// AXI4-Lite specifics enforced:
//   * Data width must be 32 or 64 (default 32).
//   * No burst signals.
//   * BRESP/RRESP always OKAY (2'b00).
//------------------------------------------------------------------------------

package axi4_lite_regs_user_pkg;

    function automatic void reg_access(
        input  logic [31:0] addr,
        input  logic        write_en,
        input  logic [3:0]  wstrb,
        input  logic [31:0] wdata,
        output logic [31:0] rdata
    );
        // Default stub: writes are dropped, reads return zero.
        rdata = 32'h0000_0000;
    endfunction

endpackage : axi4_lite_regs_user_pkg


module axi4_lite_regs_slave #(
    parameter int C_S_AXI_DATA_WIDTH = 32,  // 32 or 64
    parameter int C_S_AXI_ADDR_WIDTH = 32
) (
    input  logic                              S_AXI_ACLK,
    input  logic                              S_AXI_ARESETN,

    // Write address channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  logic [2:0]                        S_AXI_AWPROT,
    input  logic                              S_AXI_AWVALID,
    output logic                              S_AXI_AWREADY,

    // Write data channel
    input  logic [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  logic                              S_AXI_WVALID,
    output logic                              S_AXI_WREADY,

    // Write response channel
    output logic [1:0]                        S_AXI_BRESP,
    output logic                              S_AXI_BVALID,
    input  logic                              S_AXI_BREADY,

    // Read address channel
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  logic [2:0]                        S_AXI_ARPROT,
    input  logic                              S_AXI_ARVALID,
    output logic                              S_AXI_ARREADY,

    // Read data channel
    output logic [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output logic [1:0]                        S_AXI_RRESP,
    output logic                              S_AXI_RVALID,
    input  logic                              S_AXI_RREADY
);

    import axi4_lite_regs_user_pkg::*;

    logic [C_S_AXI_ADDR_WIDTH-1:0]     awaddr_q;
    logic [C_S_AXI_ADDR_WIDTH-1:0]     araddr_q;

    logic awready_i;
    logic wready_i;
    logic bvalid_i;
    logic arready_i;
    logic rvalid_i;

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
    assign S_AXI_BRESP   = 2'b00;

    assign S_AXI_ARREADY = arready_i;
    assign S_AXI_RVALID  = rvalid_i;
    assign S_AXI_RRESP   = 2'b00;
    assign S_AXI_RDATA   = acc_rdata;

    //--------------------------------------------------------------------------
    // Write address handshake
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
    // Write data handshake
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
    // Write response
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
    // Mux address/control to user function
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

    always_comb begin
        reg_access(acc_addr, acc_write_en, acc_wstrb, acc_wdata, acc_rdata);
    end

endmodule : axi4_lite_regs_slave
