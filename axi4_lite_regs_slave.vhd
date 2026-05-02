--------------------------------------------------------------------------------
-- axi4_lite_regs_slave.vhd
--
-- Basic AXI4-Lite compliant memory-mapped slave. Supports single-beat read and
-- write transactions (AXI4-Lite has no bursts, no IDs, no LOCK/CACHE/QOS, etc.)
-- and routes the address / data through an external user procedure
-- (`reg_access`) declared in `axi4_lite_regs_user_pkg`. Replace the body of
-- that procedure in your project to implement real register decoding.
--
-- AXI4-Lite specifics enforced:
--   * Data width must be 32 or 64 bits (this file defaults to 32).
--   * No burst signals (no AWLEN/AWSIZE/AWBURST/WLAST/ARLEN/ARSIZE/ARBURST).
--   * BRESP/RRESP always returned as OKAY ("00").
--------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package axi4_lite_regs_user_pkg is

    --------------------------------------------------------------------------
    -- reg_access
    --
    --   addr     : word-aligned byte address
    --   write_en : '1' on a write cycle, '0' on a read cycle
    --   wstrb    : per-byte write enables (valid when write_en = '1')
    --   wdata    : write data (valid when write_en = '1')
    --   rdata    : read data driven back on a read cycle
    --
    -- The procedure should be combinational from the bus FSM's perspective;
    -- do not include wait statements when used in synthesis.
    --------------------------------------------------------------------------
    procedure reg_access (
        signal addr     : in  std_logic_vector;
        signal write_en : in  std_logic;
        signal wstrb    : in  std_logic_vector;
        signal wdata    : in  std_logic_vector;
        signal rdata    : out std_logic_vector
    );

end package axi4_lite_regs_user_pkg;

package body axi4_lite_regs_user_pkg is

    -- Default stub: writes are dropped, reads return zero. Replace this body
    -- in your project with real register decoding.
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

end package body axi4_lite_regs_user_pkg;


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.axi4_lite_regs_user_pkg.all;

entity axi4_lite_regs_slave is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;  -- must be 32 or 64
        C_S_AXI_ADDR_WIDTH : integer := 32
    );
    port (
        -- Global
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;

        -- Write address channel
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;

        -- Write data channel
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;

        -- Write response channel
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;

        -- Read address channel
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;

        -- Read data channel
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic
    );
end entity axi4_lite_regs_slave;

architecture rtl of axi4_lite_regs_slave is

    signal awaddr_q  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal araddr_q  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

    signal awready_i : std_logic;
    signal wready_i  : std_logic;
    signal bvalid_i  : std_logic;
    signal arready_i : std_logic;
    signal rvalid_i  : std_logic;

    signal acc_addr     : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal acc_write_en : std_logic;
    signal acc_wstrb    : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal acc_wdata    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal acc_rdata    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    signal write_fire : std_logic;

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
    S_AXI_RDATA   <= acc_rdata;

    ----------------------------------------------------------------------------
    -- Write address handshake
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                awready_i <= '0';
                awaddr_q  <= (others => '0');
            else
                if awready_i = '0' and S_AXI_AWVALID = '1'
                   and wready_i = '0' and bvalid_i = '0' then
                    awready_i <= '1';
                    awaddr_q  <= S_AXI_AWADDR;
                else
                    awready_i <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Write data handshake
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                wready_i <= '0';
            else
                if wready_i = '0' and awready_i = '1' and S_AXI_AWVALID = '1' then
                    wready_i <= '1';
                elsif S_AXI_WVALID = '1' and wready_i = '1' then
                    wready_i <= '0';
                end if;
            end if;
        end if;
    end process;

    write_fire <= S_AXI_WVALID and wready_i;

    ----------------------------------------------------------------------------
    -- Write response
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                bvalid_i <= '0';
            else
                if bvalid_i = '0' and write_fire = '1' then
                    bvalid_i <= '1';
                elsif bvalid_i = '1' and S_AXI_BREADY = '1' then
                    bvalid_i <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Read address handshake
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                arready_i <= '0';
                araddr_q  <= (others => '0');
            else
                if arready_i = '0' and S_AXI_ARVALID = '1' and rvalid_i = '0' then
                    arready_i <= '1';
                    araddr_q  <= S_AXI_ARADDR;
                else
                    arready_i <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Read data valid
    ----------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                rvalid_i <= '0';
            else
                if arready_i = '1' and S_AXI_ARVALID = '1' and rvalid_i = '0' then
                    rvalid_i <= '1';
                elsif rvalid_i = '1' and S_AXI_RREADY = '1' then
                    rvalid_i <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Mux address/control to the external register-access procedure
    ----------------------------------------------------------------------------
    process (write_fire, awaddr_q, araddr_q, S_AXI_WDATA, S_AXI_WSTRB)
    begin
        if write_fire = '1' then
            acc_addr     <= awaddr_q;
            acc_write_en <= '1';
            acc_wstrb    <= S_AXI_WSTRB;
            acc_wdata    <= S_AXI_WDATA;
        else
            acc_addr     <= araddr_q;
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
