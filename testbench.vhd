-- ============================================================
-- TESTBENCH for led_dimmer (final version)
-- ============================================================
-- This testbench targets the entity interface exactly as defined
-- in design.vhd (generics DEBOUNCE_MAX / LONGPRESS_MAX, ports
-- clk_in, button_no_1, button_nc_1, led_0..7, seg_left_*, seg_right_*,
-- pmod_c_pin_1..4). No changes were made to design.vhd.

-- SIMULATION-SCALE GENERICS:
-- The design's default generics (DEBOUNCE_MAX=480_000, LONGPRESS_MAX
-- =12_000_000) are sized for a real 24 MHz clock (20 ms / 500 ms).
-- Simulating that many cycles here would take a long time, so this
-- testbench overrides the generics to small values (G_DEBOUNCE=5,
-- G_LONGPRESS=30) via a generic map. This changes ONLY the timing
-- scale for simulation speed -- the design's logic is exercised
-- exactly as written. Clock period = 10 ns.
--
-- With G_DEBOUNCE=5: a level must be stable for 6 clk_in cycles
-- before btn_debounced updates (symmetric: applies to both press
-- and release, since the debounce process re-triggers on ANY
-- difference between btn_sync_1 and btn_debounced).
-- With G_LONGPRESS=30: button must remain registered-pressed for
-- more than 30 cycles after entering PRESS_COUNT to trigger a
-- long press.
--
-- TEST PLAN / SCHEDULE:
--   TEST A  (~50 ns)   button glitch shorter than debounce window
--                       -> btn_debounced must NOT change (noise rejection)
--   TEST B  (~300 ns)  SHORT press while lamp OFF -> lamp turns ON,
--                       brightness unchanged (starts at reset value 2)
--   TEST C  (~700 ns)  LONG press -> brightness step 2 -> 3 (dim_dir='1', going up)
--   TEST D  (~1100 ns) LONG press -> brightness step 3 -> 4
--   TEST E  (~1500 ns) LONG press -> brightness = 4 hits max, dim_dir reverses
--                       to '0', brightness steps 4 -> 3 (limit-reversal check)
--   TEST F  (~1900 ns) LONG press -> brightness step 3 -> 2
--   TEST G  (~2300 ns) SHORT press -> lamp turns OFF, brightness stays at 2
--   TEST H  (~2700 ns) LONG press while lamp is OFF -> long_press pulse still
--                       fires (visible on pmod_c_pin_4), but brightness must
--                       NOT change (Brightness Controller gates on lamp_on='1')
--   TEST I  (~3100 ns) SHORT press -> lamp turns ON again, brightness still 2
--                       (confirms TEST H did not silently change it)
--   TEST J  (~3500 ns) Button held for 3x the long-press threshold -> long_press
--                       must pulse exactly ONCE (single tick), not repeatedly,
--                       while held (LONG_HELD state does not re-arm); brightness
--                       therefore changes by exactly one step, not several
-- ============================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity led_dimmer_tb is
end entity;

architecture tb of led_dimmer_tb is

    constant G_DEBOUNCE  : integer := 5;
    constant G_LONGPRESS : integer := 30;
    constant T_clk       : time := 10 ns;

    component led_dimmer
        generic(
            DEBOUNCE_MAX  : integer;
            LONGPRESS_MAX : integer
        );
        port(
            clk_in        : in  std_logic;
            button_no_1   : in  std_logic;
            button_nc_1   : in  std_logic;

            led_0         : out std_logic;
            led_1         : out std_logic;
            led_2         : out std_logic;
            led_3         : out std_logic;
            led_4         : out std_logic;
            led_5         : out std_logic;
            led_6         : out std_logic;
            led_7         : out std_logic;

            seg_left_a    : out std_logic;
            seg_left_b    : out std_logic;
            seg_left_c    : out std_logic;
            seg_left_d    : out std_logic;
            seg_left_e    : out std_logic;
            seg_left_f    : out std_logic;
            seg_left_g    : out std_logic;

            seg_right_a   : out std_logic;
            seg_right_b   : out std_logic;
            seg_right_c   : out std_logic;
            seg_right_d   : out std_logic;
            seg_right_e   : out std_logic;
            seg_right_f   : out std_logic;
            seg_right_g   : out std_logic;

            pmod_c_pin_1  : out std_logic;
            pmod_c_pin_2  : out std_logic;
            pmod_c_pin_3  : out std_logic;
            pmod_c_pin_4  : out std_logic
        );
    end component;

    signal clk_in       : std_logic := '0';
    signal button_no_1  : std_logic := '0';
    signal button_nc_1  : std_logic := '0';  

    signal led_0, led_1, led_2, led_3 : std_logic;
    signal led_4, led_5, led_6, led_7 : std_logic;

    signal seg_left_a, seg_left_b, seg_left_c, seg_left_d : std_logic;
    signal seg_left_e, seg_left_f, seg_left_g             : std_logic;

    signal seg_right_a, seg_right_b, seg_right_c, seg_right_d : std_logic;
    signal seg_right_e, seg_right_f, seg_right_g               : std_logic;

    signal pmod_c_pin_1, pmod_c_pin_2, pmod_c_pin_3, pmod_c_pin_4 : std_logic;

    signal seg_left_vec  : std_logic_vector(6 downto 0);
    signal seg_right_vec : std_logic_vector(6 downto 0);

    -- decode helpers for reporting only (not part of the design)
    function decode_left(v : std_logic_vector(6 downto 0)) return string is
    begin
        case v is
            when "1111110" => return "0 (lamp OFF)";
            when "0110000" => return "1 (lamp ON)";
            when others    => return "?? (" & to_hstring(v) & ")";
        end case;
    end function;

    function decode_right(v : std_logic_vector(6 downto 0)) return string is
    begin
        case v is
            when "1111110" => return "level 0";
            when "0110000" => return "level 1";
            when "1101101" => return "level 2";
            when "1111001" => return "level 3";
            when "0110011" => return "level 4";
            when "0000000" => return "blank";
            when others    => return "?? (" & to_hstring(v) & ")";
        end case;
    end function;

begin

    UUT : led_dimmer
        generic map(
            DEBOUNCE_MAX  => G_DEBOUNCE,
            LONGPRESS_MAX => G_LONGPRESS
        )
        port map(
            clk_in        => clk_in,
            button_no_1   => button_no_1,
            button_nc_1   => button_nc_1,
            led_0         => led_0, led_1 => led_1, led_2 => led_2, led_3 => led_3,
            led_4         => led_4, led_5 => led_5, led_6 => led_6, led_7 => led_7,
            seg_left_a    => seg_left_a, seg_left_b => seg_left_b, seg_left_c => seg_left_c,
            seg_left_d    => seg_left_d, seg_left_e => seg_left_e, seg_left_f => seg_left_f,
            seg_left_g    => seg_left_g,
            seg_right_a   => seg_right_a, seg_right_b => seg_right_b, seg_right_c => seg_right_c,
            seg_right_d   => seg_right_d, seg_right_e => seg_right_e, seg_right_f => seg_right_f,
            seg_right_g   => seg_right_g,
            pmod_c_pin_1  => pmod_c_pin_1,
            pmod_c_pin_2  => pmod_c_pin_2,
            pmod_c_pin_3  => pmod_c_pin_3,
            pmod_c_pin_4  => pmod_c_pin_4
        );

    clk_in <= not clk_in after T_clk / 2;

    seg_left_vec  <= seg_left_a & seg_left_b & seg_left_c & seg_left_d & seg_left_e & seg_left_f & seg_left_g;
    seg_right_vec <= seg_right_a & seg_right_b & seg_right_c & seg_right_d & seg_right_e & seg_right_f & seg_right_g;

    -- monitor: report whenever short_press / long_press pulse (visible on PMOD)
    -- or the displayed lamp/brightness state changes
    process(pmod_c_pin_3, pmod_c_pin_4)
    begin
        if pmod_c_pin_3 = '1' then
            report "t=" & time'image(now) & "  SHORT-PRESS EVENT (pmod_c_pin_3)";
        end if;
        if pmod_c_pin_4 = '1' then
            report "t=" & time'image(now) & "  LONG-PRESS EVENT  (pmod_c_pin_4)";
        end if;
    end process;

    process(seg_left_vec, seg_right_vec)
    begin
        report "t=" & time'image(now) & "  lamp=" & decode_left(seg_left_vec) &
               "   brightness=" & decode_right(seg_right_vec);
    end process;

    -- ------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------
    process
    begin
        button_nc_1 <= '0';
        wait for 100 ns;   -- let synchronizer/debounce settle in known idle state

        -- ============================================================
        -- TEST A: glitch shorter than debounce window -> must be rejected
        -- glitch width = 1 cycle (10 ns), well under (G_DEBOUNCE+1)*10ns = 60 ns
        -- ============================================================
        button_nc_1 <= '1';
        wait for 10 ns;
        button_nc_1 <= '0';
        wait for 100 ns;   -- observe: btn_debounced / pmod_c_pin_2 must stay '0'

        -- ============================================================
        -- TEST B: SHORT press -> lamp ON
        -- hold 150 ns (15 cycles): long enough to pass debounce (~60-80 ns
        -- round trip) but short of the long-press threshold
        -- ============================================================
        button_nc_1 <= '1';
        wait for 150 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST C: LONG press -> brightness 2 -> 3
        -- hold 600 ns (60 cycles): well past debounce + LONGPRESS_MAX(30)
        -- ============================================================
        button_nc_1 <= '1';
        wait for 600 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST D: LONG press -> brightness 3 -> 4
        -- ============================================================
        button_nc_1 <= '1';
        wait for 600 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST E: LONG press -> brightness hits max(4), direction reverses,
        -- steps to 3
        -- ============================================================
        button_nc_1 <= '1';
        wait for 600 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST F: LONG press -> brightness 3 -> 2
        -- ============================================================
        button_nc_1 <= '1';
        wait for 600 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST G: SHORT press -> lamp OFF, brightness frozen at 2
        -- ============================================================
        button_nc_1 <= '1';
        wait for 150 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST H: LONG press while lamp is OFF -> long_press pulses but
        -- brightness must NOT change (still 2 once lamp comes back on)
        -- ============================================================
        button_nc_1 <= '1';
        wait for 600 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST I: SHORT press -> lamp ON again, brightness still 2
        -- ============================================================
        button_nc_1 <= '1';
        wait for 150 ns;
        button_nc_1 <= '0';
        wait for 200 ns;

        -- ============================================================
        -- TEST J: hold for 3x LONGPRESS_MAX -> long_press must fire only
        -- ONCE (single tick), not repeatedly, while held
        -- ============================================================
        button_nc_1 <= '1';
        wait for 1500 ns;
        button_nc_1 <= '0';
        wait for 300 ns;

        report "t=" & time'image(now) & "  SIMULATION COMPLETE";
        wait;
    end process;

end architecture;
