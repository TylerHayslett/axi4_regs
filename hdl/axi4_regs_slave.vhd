--------------------------------------------------------------------------------
-- axi4_regs_slave.vhd
--
-- AXI4 (full) compliant memory-mapped slave with real burst support
-- (INCR, FIXED, WRAP). Single-beat access still works (AWLEN/ARLEN = 0).
-- Read and write data paths are routed to an external user procedure
-- `reg_access` declared in `axi4_regs_user_pkg`. Replace its body to
-- implement real register decoding.
--
-- Notes:
--   * BRESP/RRESP always returned as OKAY ("00").
--   * Default data width 32, address width 32.
--------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package axi4_regs_user_pkg is

    procedure reg_access (
        signal addr     : in  std_logic_vector;
        signal write_en : in  std_logic;
        signal wstrb    : in  std_logic_vector;
        signal wdata    : in  std_logic_vector;
        signal rdata    : out std_logic_vector
    );

end package axi4_regs_user_pkg;

package body axi4_regs_user_pkg is

    procedure reg_access (
        signal addr     : in  std_logic_vector;
        signal write_en : in  std_logic;
        signal wstrb    : in  std_logic_vector;
        signal wdata    : in  std_logic_vector;
        signal rdata    : out std_logic_vector
    ) is
    begin
        rdata <= (rdata'range => '0');
    end procedure reg_access;

end package body axi4_regs_user_pkg;


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.axi4_regs_user_pkg.all;

entity axi4_regs_slave_vhd is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 32
    );
    port (
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;

        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_AWLEN   : in  std_logic_vector(7 downto 0);
        S_AXI_AWSIZE  : in  std_logic_vector(2 downto 0);
        S_AXI_AWBURST : in  std_logic_vector(1 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;

        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WLAST   : in  std_logic;
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;

        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;

        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_ARLEN   : in  std_logic_vector(7 downto 0);
        S_AXI_ARSIZE  : in  std_logic_vector(2 downto 0);
        S_AXI_ARBURST : in  std_logic_vector(1 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;

        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RLAST   : out std_logic;
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic
    );
end entity axi4_regs_slave_vhd;

architecture rtl of axi4_regs_slave_vhd is

    -- Returns next beat address for INCR/FIXED/WRAP bursts.
    function next_addr (
        cur   : std_logic_vector;
        base  : std_logic_vector;
        burst : std_logic_vector(1 downto 0);
        size  : std_logic_vector(2 downto 0);
        len   : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
        constant W          : integer := cur'length;
        variable inc        : unsigned(W-1 downto 0);
        variable wrap_bytes : unsigned(W-1 downto 0);
        variable wrap_mask  : unsigned(W-1 downto 0);
        variable wrap_base  : unsigned(W-1 downto 0);
        variable cand       : unsigned(W-1 downto 0);
        variable cur_u      : unsigned(W-1 downto 0);
        variable base_u     : unsigned(W-1 downto 0);
        variable result     : unsigned(W-1 downto 0);
    begin
        cur_u  := unsigned(cur);
        base_u := unsigned(base);
        inc    := to_unsigned(2**to_integer(unsigned(size)), W);

        case burst is
            when "00" =>
                result := cur_u;                                  -- FIXED
            when "01" =>
                result := cur_u + inc;                            -- INCR
            when "10" =>                                          -- WRAP
                wrap_bytes := resize((to_unsigned(to_integer(unsigned(len)) + 1, W)) * inc, W);
                wrap_mask  := wrap_bytes - 1;
                wrap_base  := base_u and (not wrap_mask);
                cand       := (cur_u + inc) and wrap_mask;
                result     := wrap_base or cand;
            when others =>
                result := cur_u + inc;
        end case;
        return std_logic_vector(result);
    end function;

    -- Read FSM
    type r_state_t is (R_IDLE, R_BURST);
    signal r_state   : r_state_t;
    signal r_addr_q  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal r_base_q  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal r_len_q   : unsigned(7 downto 0);
    signal r_total_q : std_logic_vector(7 downto 0);
    signal r_size_q  : std_logic_vector(2 downto 0);
    signal r_burst_q : std_logic_vector(1 downto 0);
    signal arready_i : std_logic;
    signal rvalid_i  : std_logic;
    signal rlast_i   : std_logic;

    -- Write FSM
    type w_state_t is (W_IDLE, W_DATA, W_RESP);
    signal w_state   : w_state_t;
    signal w_addr_q  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal w_base_q  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal w_len_q   : unsigned(7 downto 0);
    signal w_total_q : std_logic_vector(7 downto 0);
    signal w_size_q  : std_logic_vector(2 downto 0);
    signal w_burst_q : std_logic_vector(1 downto 0);
    signal awready_i : std_logic;
    signal wready_i  : std_logic;
    signal bvalid_i  : std_logic;

    -- Procedure interface
    signal acc_addr     : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal acc_write_en : std_logic;
    signal acc_wstrb    : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal acc_wdata    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal acc_rdata    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal write_fire   : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Output assignments
    ----------------------------------------------------------------------------
    S_AXI_AWREADY <= awready_i;
    S_AXI_WREADY  <= wready_i;
    S_AXI_BVALID  <= bvalid_i;
    S_AXI_BRESP   <= "00";

    S_AXI_ARREADY <= arready_i;
    S_AXI_RVALID  <= rvalid_i;
    S_AXI_RRESP   <= "00";
    S_AXI_RLAST   <= rlast_i;
    S_AXI_RDATA   <= acc_rdata;

    ----------------------------------------------------------------------------
    -- Read FSM
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                r_state   <= R_IDLE;
                arready_i <= '0';
                rvalid_i  <= '0';
                rlast_i   <= '0';
                r_addr_q  <= (others => '0');
                r_base_q  <= (others => '0');
                r_len_q   <= (others => '0');
                r_total_q <= (others => '0');
                r_size_q  <= "010";
                r_burst_q <= "01";
            else
                case r_state is
                    when R_IDLE =>
                        rvalid_i  <= '0';
                        rlast_i   <= '0';
                        arready_i <= '1';
                        if S_AXI_ARVALID = '1' and arready_i = '1' then
                            arready_i <= '0';
                            r_addr_q  <= S_AXI_ARADDR;
                            r_base_q  <= S_AXI_ARADDR;
                            r_len_q   <= unsigned(S_AXI_ARLEN);
                            r_total_q <= S_AXI_ARLEN;
                            r_size_q  <= S_AXI_ARSIZE;
                            r_burst_q <= S_AXI_ARBURST;
                            rvalid_i  <= '1';
                            if unsigned(S_AXI_ARLEN) = 0 then
                                rlast_i <= '1';
                            else
                                rlast_i <= '0';
                            end if;
                            r_state   <= R_BURST;
                        end if;

                    when R_BURST =>
                        if rvalid_i = '1' and S_AXI_RREADY = '1' then
                            if r_len_q = 0 then
                                rvalid_i <= '0';
                                rlast_i  <= '0';
                                r_state  <= R_IDLE;
                            else
                                r_addr_q <= next_addr(r_addr_q, r_base_q,
                                                      r_burst_q, r_size_q, r_total_q);
                                r_len_q  <= r_len_q - 1;
                                if r_len_q = 1 then
                                    rlast_i <= '1';
                                else
                                    rlast_i <= '0';
                                end if;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Write FSM
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                w_state   <= W_IDLE;
                awready_i <= '0';
                wready_i  <= '0';
                bvalid_i  <= '0';
                w_addr_q  <= (others => '0');
                w_base_q  <= (others => '0');
                w_len_q   <= (others => '0');
                w_total_q <= (others => '0');
                w_size_q  <= "010";
                w_burst_q <= "01";
            else
                case w_state is
                    when W_IDLE =>
                        bvalid_i  <= '0';
                        wready_i  <= '0';
                        awready_i <= '1';
                        if S_AXI_AWVALID = '1' and awready_i = '1' then
                            awready_i <= '0';
                            w_addr_q  <= S_AXI_AWADDR;
                            w_base_q  <= S_AXI_AWADDR;
                            w_len_q   <= unsigned(S_AXI_AWLEN);
                            w_total_q <= S_AXI_AWLEN;
                            w_size_q  <= S_AXI_AWSIZE;
                            w_burst_q <= S_AXI_AWBURST;
                            wready_i  <= '1';
                            w_state   <= W_DATA;
                        end if;

                    when W_DATA =>
                        if S_AXI_WVALID = '1' and wready_i = '1' then
                            if w_len_q = 0 or S_AXI_WLAST = '1' then
                                wready_i <= '0';
                                bvalid_i <= '1';
                                w_state  <= W_RESP;
                            else
                                w_addr_q <= next_addr(w_addr_q, w_base_q,
                                                      w_burst_q, w_size_q, w_total_q);
                                w_len_q  <= w_len_q - 1;
                            end if;
                        end if;

                    when W_RESP =>
                        if bvalid_i = '1' and S_AXI_BREADY = '1' then
                            bvalid_i <= '0';
                            w_state  <= W_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Mux address/control to user reg_access procedure
    ----------------------------------------------------------------------------
    write_fire <= '1' when (w_state = W_DATA) and S_AXI_WVALID = '1' and wready_i = '1' else '0';

    process (write_fire, w_addr_q, r_addr_q, S_AXI_WDATA, S_AXI_WSTRB)
    begin
        if write_fire = '1' then
            acc_addr     <= w_addr_q;
            acc_write_en <= '1';
            acc_wstrb    <= S_AXI_WSTRB;
            acc_wdata    <= S_AXI_WDATA;
        else
            acc_addr     <= r_addr_q;
            acc_write_en <= '0';
            acc_wstrb    <= (others => '0');
            acc_wdata    <= (others => '0');
        end if;
    end process;

    reg_access_proc : process (acc_addr, acc_write_en, acc_wstrb, acc_wdata)
    begin
        reg_access(acc_addr, acc_write_en, acc_wstrb, acc_wdata, acc_rdata);
    end process;

end architecture rtl;
