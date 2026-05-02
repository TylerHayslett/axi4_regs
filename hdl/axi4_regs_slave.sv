//------------------------------------------------------------------------------
// axi4_regs_slave.sv
//
// AXI4 (full) compliant memory-mapped slave with real burst support
// (INCR, FIXED, WRAP). Single-beat access still works (AWLEN/ARLEN = 0).
// Read and write data paths are routed to an external user function
// `reg_access` declared in `axi4_regs_user_pkg`. Replace its body to
// implement real register decoding.
//
// Notes:
//   * BRESP/RRESP always returned as OKAY.
//   * Default DATA_WIDTH = 32, ADDR_WIDTH = 32. For other data widths
//     update `reg_access` accordingly.
//------------------------------------------------------------------------------

package axi4_regs_user_pkg_sv;

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

endpackage : axi4_regs_user_pkg_sv


module axi4_regs_slave #(
    parameter int C_S_AXI_DATA_WIDTH = 32,
    parameter int C_S_AXI_ADDR_WIDTH = 32
) (
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

    localparam int STRB_WIDTH = C_S_AXI_DATA_WIDTH/8;

    //--------------------------------------------------------------------------
    // Burst helpers
    //--------------------------------------------------------------------------
    // Returns the byte address of the next beat given current address, the
    // burst type and the byte-size from AxSIZE, plus the base address used for
    // WRAP wrap-around calculation and the total burst length in beats.
    function automatic logic [C_S_AXI_ADDR_WIDTH-1:0] next_addr(
        input logic [C_S_AXI_ADDR_WIDTH-1:0] cur,
        input logic [C_S_AXI_ADDR_WIDTH-1:0] base,
        input logic [1:0]                    burst,
        input logic [2:0]                    size,
        input logic [7:0]                    len
    );
        logic [C_S_AXI_ADDR_WIDTH-1:0] inc;
        logic [C_S_AXI_ADDR_WIDTH-1:0] wrap_bytes;
        logic [C_S_AXI_ADDR_WIDTH-1:0] wrap_mask;
        logic [C_S_AXI_ADDR_WIDTH-1:0] wrap_base;
        logic [C_S_AXI_ADDR_WIDTH-1:0] cand;
        begin
            inc = (1 << size);
            unique case (burst)
                2'b00: next_addr = cur;                    // FIXED
                2'b01: next_addr = cur + inc;              // INCR
                2'b10: begin                               // WRAP
                    wrap_bytes = (len + 1) * inc;
                    wrap_mask  = wrap_bytes - 1;
                    wrap_base  = base & ~wrap_mask;
                    cand       = (cur + inc) & wrap_mask;
                    next_addr  = wrap_base | cand;
                end
                default: next_addr = cur + inc;
            endcase
        end
    endfunction

    //--------------------------------------------------------------------------
    // Read FSM
    //--------------------------------------------------------------------------
    typedef enum logic [0:0] {R_IDLE, R_BURST} r_state_t;
    r_state_t r_state;

    logic [C_S_AXI_ADDR_WIDTH-1:0] r_addr_q;
    logic [C_S_AXI_ADDR_WIDTH-1:0] r_base_q;
    logic [7:0]                    r_len_q;     // remaining beats - 1
    logic [7:0]                    r_total_q;   // original ARLEN
    logic [2:0]                    r_size_q;
    logic [1:0]                    r_burst_q;
    logic                          arready_i;
    logic                          rvalid_i;
    logic                          rlast_i;

    logic [C_S_AXI_DATA_WIDTH-1:0] read_rdata;

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            r_state   <= R_IDLE;
            arready_i <= 1'b0;
            rvalid_i  <= 1'b0;
            rlast_i   <= 1'b0;
            r_addr_q  <= '0;
            r_base_q  <= '0;
            r_len_q   <= '0;
            r_total_q <= '0;
            r_size_q  <= 3'd2;
            r_burst_q <= 2'b01;
        end else begin
            unique case (r_state)
                R_IDLE: begin
                    rvalid_i  <= 1'b0;
                    rlast_i   <= 1'b0;
                    arready_i <= 1'b1;
                    if (S_AXI_ARVALID && arready_i) begin
                        arready_i <= 1'b0;
                        r_addr_q  <= S_AXI_ARADDR;
                        r_base_q  <= S_AXI_ARADDR;
                        r_len_q   <= S_AXI_ARLEN;
                        r_total_q <= S_AXI_ARLEN;
                        r_size_q  <= S_AXI_ARSIZE;
                        r_burst_q <= S_AXI_ARBURST;
                        rvalid_i  <= 1'b1;
                        rlast_i   <= (S_AXI_ARLEN == 8'd0);
                        r_state   <= R_BURST;
                    end
                end

                R_BURST: begin
                    if (rvalid_i && S_AXI_RREADY) begin
                        if (r_len_q == 8'd0) begin
                            // Last beat just accepted
                            rvalid_i <= 1'b0;
                            rlast_i  <= 1'b0;
                            r_state  <= R_IDLE;
                        end else begin
                            r_addr_q <= next_addr(r_addr_q, r_base_q,
                                                  r_burst_q, r_size_q, r_total_q);
                            r_len_q  <= r_len_q - 8'd1;
                            rlast_i  <= (r_len_q == 8'd1);
                            // rvalid_i stays high
                        end
                    end
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Write FSM
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_t;
    w_state_t w_state;

    logic [C_S_AXI_ADDR_WIDTH-1:0] w_addr_q;
    logic [C_S_AXI_ADDR_WIDTH-1:0] w_base_q;
    logic [7:0]                    w_len_q;     // remaining beats - 1
    logic [7:0]                    w_total_q;
    logic [2:0]                    w_size_q;
    logic [1:0]                    w_burst_q;
    logic                          awready_i;
    logic                          wready_i;
    logic                          bvalid_i;

    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            w_state   <= W_IDLE;
            awready_i <= 1'b0;
            wready_i  <= 1'b0;
            bvalid_i  <= 1'b0;
            w_addr_q  <= '0;
            w_base_q  <= '0;
            w_len_q   <= '0;
            w_total_q <= '0;
            w_size_q  <= 3'd2;
            w_burst_q <= 2'b01;
        end else begin
            unique case (w_state)
                W_IDLE: begin
                    bvalid_i  <= 1'b0;
                    wready_i  <= 1'b0;
                    awready_i <= 1'b1;
                    if (S_AXI_AWVALID && awready_i) begin
                        awready_i <= 1'b0;
                        w_addr_q  <= S_AXI_AWADDR;
                        w_base_q  <= S_AXI_AWADDR;
                        w_len_q   <= S_AXI_AWLEN;
                        w_total_q <= S_AXI_AWLEN;
                        w_size_q  <= S_AXI_AWSIZE;
                        w_burst_q <= S_AXI_AWBURST;
                        wready_i  <= 1'b1;
                        w_state   <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (S_AXI_WVALID && wready_i) begin
                        if (w_len_q == 8'd0 || S_AXI_WLAST) begin
                            wready_i <= 1'b0;
                            bvalid_i <= 1'b1;
                            w_state  <= W_RESP;
                        end else begin
                            w_addr_q <= next_addr(w_addr_q, w_base_q,
                                                  w_burst_q, w_size_q, w_total_q);
                            w_len_q  <= w_len_q - 8'd1;
                        end
                    end
                end

                W_RESP: begin
                    if (bvalid_i && S_AXI_BREADY) begin
                        bvalid_i <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end
            endcase
        end
    end

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
    assign S_AXI_RLAST   = rlast_i;
    assign S_AXI_RDATA   = read_rdata;

    //--------------------------------------------------------------------------
    // Mux address/control to user reg_access function.
    //
    // A write beat takes priority while the W FSM is mid-burst, otherwise we
    // present the current read address so RDATA tracks r_addr_q.
    //--------------------------------------------------------------------------
    logic [C_S_AXI_ADDR_WIDTH-1:0]     acc_addr;
    logic                              acc_write_en;
    logic [STRB_WIDTH-1:0]             acc_wstrb;
    logic [C_S_AXI_DATA_WIDTH-1:0]     acc_wdata;
    logic [C_S_AXI_DATA_WIDTH-1:0]     acc_rdata;
    logic                              write_fire;

    assign write_fire = (w_state == W_DATA) && S_AXI_WVALID && wready_i;

    always_comb begin
        if (write_fire) begin
            acc_addr     = w_addr_q;
            acc_write_en = 1'b1;
            acc_wstrb    = S_AXI_WSTRB;
            acc_wdata    = S_AXI_WDATA;
        end else begin
            acc_addr     = r_addr_q;
            acc_write_en = 1'b0;
            acc_wstrb    = '0;
            acc_wdata    = '0;
        end
    end

    always_comb begin
        reg_access(acc_addr, acc_write_en, acc_wstrb, acc_wdata, acc_rdata);
    end

    assign read_rdata = acc_rdata;

endmodule : axi4_regs_slave
