--------------------------------------------------------------------------------
-- axi4_regs_slave.vhd
--
-- Basic AXI4 (full) compliant memory-mapped slave that supports single-beat
-- read and write transactions. Read and write data paths are passed to an
-- external user procedure (`reg_access`) that is responsible for decoding the
-- word address and producing/consuming the actual register data.
--
-- Notes:
--   * Supports AWLEN/ARLEN = 0 (single-beat) cleanly. Burst transactions are
--     accepted but treated as a sequence of independent word accesses to the
--     same address, which is sufficient for register-file behavior. For full
--     burst support, extend the address counter logic.
--   * AXI4 requires BRESP/RRESP. This slave always returns OKAY ("00").
--   * Default data width 32, address width 32. Adjust generics as needed.
--   * The external procedure `reg_access` must be supplied in a package or
--     architecture body that this module is compiled against. Its signature
--     is documented below.
--------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

-- The external procedure is declared in this package so the slave can `use`
-- it. Provide a body for it in your project to implement register behavior.
package axi4_regs_user_pkg is

    --------------------------------------------------------------------------
    -- reg_access
    --
    --   addr     : word-aligned address (byte address with low bits zeroed)
    --   write_en : '1' on a write cycle, '0' on a read cycle
    --   wstrb    : per-byte write enables (only valid when write_en = '1')
    --   wdata    : write data (only valid when write_en = '1')
    --   rdata    : read data driven back on a read cycle
    --
    -- The procedure should be combinational/non-blocking from the bus FSM's
    -- point of view; do not include wait statements when used in synthesis.
    --------------------------------------------------------------------------
    procedure reg_access (
        signal   addr     : in  std_logic_vector;
        signal   write_en : in  std_logic;
        signal   wstrb    : in  std_logic_vector;
        signal   wdata    : in  std_logic_vector;
        signal   rdata    : out std_logic_vector
    );

end package axi4_regs_user_pkg;

package body axi4_regs_user_pkg is

    -- Default stub implementation: writes are dropped, reads return zero.
    -- Replace this body in your project with real register decoding.
    procedure reg_access (
        signal   addr     : in  std_logic_vector;
        signal   write_en : in  std_logic;
        signal   wstrb    : in  std_logic_vector;
        signal   wdata    : in  std_logic_vector;
        signal   rdata    : out std_logic_vector
    ) is
    begin
        rdata <= (rdata'range => '0');
    end procedure reg_access;

end package body axi4_regs_user_pkg;


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.axi4_regs_user_pkg.all;

entity axi4_regs_slave is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 32
    );
    port (
        -- Global
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;

        -- Write address channel
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_AWLEN   : in  std_logic_vector(7 downto 0);
        S_AXI_AWSIZE  : in  std_logic_vector(2 downto 0);
        S_AXI_AWBURST : in  std_logic_vector(1 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;

        -- Write data channel
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WLAST   : in  std_logic;
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;

        -- Write response channel
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;

        -- Read address channel
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_ARLEN   : in  std_logic_vector(7 downto 0);
        S_AXI_ARSIZE  : in  std_logic_vector(2 downto 0);
        S_AXI_ARBURST : in  std_logic_vector(1 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;

        -- Read data channel
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RLAST   : out std_logic;
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic
    );
end entity axi4_regs_slave;

architecture rtl of axi4_regs_slave is

    constant ADDR_LSB : integer := (C_S_AXI_DATA_WIDTH / 32) + 1;  -- byte->word

    -- Latched address signals
    signal awaddr_q : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal araddr_q : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);

    -- Handshake signals
    signal awready_i : std_logic;
    signal wready_i  : std_logic;
    signal bvalid_i  : std_logic;
    signal arready_i : std_logic;
    signal rvalid_i  : std_logic;

    -- Procedure interface signals
    signal acc_addr     : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal acc_write_en : std_logic;
    signal acc_wstrb    : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal acc_wdata    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal acc_rdata    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    -- Internal write transaction qualifier
    signal write_fire : std_logic;

begin

    ----------------------------------------------------------------------------
    -- Output assignments
    ----------------------------------------------------------------------------
    S_AXI_AWREADY <= awready_i;
    S_AXI_WREADY  <= wready_i;
    S_AXI_BVALID  <= bvalid_i;
    S_AXI_BRESP   <= "00";  -- always OKAY

    S_AXI_ARREADY <= arready_i;
    S_AXI_RVALID  <= rvalid_i;
    S_AXI_RRESP   <= "00";  -- always OKAY
    S_AXI_RLAST   <= rvalid_i;  -- single-beat

    S_AXI_RDATA   <= acc_rdata;

    ----------------------------------------------------------------------------
    -- Write address handshake: accept AW when no outstanding write
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
    -- Write data handshake: assert WREADY one cycle after AW captured
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
    -- Write response: assert BVALID after W beat is captured
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
    -- Drive the external register-access procedure.
    --
    -- On a write cycle we route the latched write address + WDATA/WSTRB.
    -- Otherwise we present the latched read address.
    ----------------------------------------------------------------------------
    process (write_fire, awaddr_q, araddr_q,
             S_AXI_WDATA, S_AXI_WSTRB)
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

    -- Invoke the user-supplied register-access procedure combinationally.
    reg_access_proc : process (acc_addr, acc_write_en, acc_wstrb, acc_wdata)
    begin
        reg_access(acc_addr, acc_write_en, acc_wstrb, acc_wdata, acc_rdata);
    end process;

end architecture rtl;
