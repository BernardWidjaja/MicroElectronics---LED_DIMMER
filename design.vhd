-- Code your design here
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Declaring Ports
entity led_dimmer is
  generic(
  	DEBOUNCE_MAX : integer := 480_000;-- 20ms ; for 1ms: 24,000,000 / 1000 = 24,000 ticks; for 20ms: 24,000*20=480,000 ticks
    LONGPRESS_MAX : integer := 12_000_000 --500ms; for 1ms: 24,000 ticks; for 500ms: 500*24,000=12,000,000
  );
  port (
    clk_in : in std_logic;
    button_no_1: in std_logic;  --open contact of push button
    button_nc_1: in std_logic;  --closed contact of push button

    led_0 : out std_logic;
    led_1 : out std_logic;
    led_2 : out std_logic;
    led_3 : out std_logic;
    led_4 : out std_logic;
    led_5 : out std_logic;
    led_6 : out std_logic;
    led_7 : out std_logic;

    seg_left_a : out std_logic;
    seg_left_b : out std_logic;
    seg_left_c : out std_logic;
    seg_left_d : out std_logic;
    seg_left_e : out std_logic;
    seg_left_f : out std_logic;
    seg_left_g : out std_logic;

    seg_right_a : out std_logic;
    seg_right_b : out std_logic;
    seg_right_c : out std_logic;
    seg_right_d : out std_logic;
    seg_right_e : out std_logic;
    seg_right_f : out std_logic;
    seg_right_g : out std_logic;

    pmod_c_pin_1 : out std_logic;
    pmod_c_pin_2 : out std_logic;
    pmod_c_pin_3 : out std_logic;
    pmod_c_pin_4 : out std_logic
  );
end entity led_dimmer;


architecture rtl of led_dimmer is

  -- calculated from 24MHz clock
  constant CLK_FREQ : integer := 24_000_000;

  --clock ticks we wait to confirm the button has stopped bouncing
--  constant DEBOUNCE_MAX : integer := 480_000; -- 20ms ; for 1ms: 24,000,000 / 1000 = 24,000 ticks; for 20ms: 24,000*20=480,000 ticks

  --clock ticks the button must be held before we call it a "long press"
--  constant LONGPRESS_MAX : integer := 12_000_000; --500ms; for 1ms: 24,000 ticks; for 500ms: 500*24,000=12,000,000


  constant PWM_PERIOD : integer := 1024; --length of one complete PWM cycle; PWM freq = 24,000,000 / 1024 = 23,437 Hz

  constant DIM_STEP: integer := 256; --1024 / 5 = 256 ticks per level


  -- BUTTON
  signal btn_sync_0 : std_logic := '0';
  signal btn_sync_1 : std_logic := '0';
  signal btn_debounced : std_logic := '0';

  -- Press events
  signal short_press : std_logic := '0';
  signal long_press : std_logic := '0';

  -- Brightness state
  signal lamp_on : std_logic := '0'; -- initially OFF
  signal brightness : unsigned(2 downto 0) := "010";
  signal dim_dir : std_logic := '1'; -- 1- going up; 0- going down

  -- PWM signals
  signal pwm_counter : unsigned(9 downto 0) := (others => '0');
  signal duty_cycle : unsigned(10 downto 0) := (others => '0');
  signal pwm_out : std_logic := '0';

  -- 7-segment patterns
  signal seg_left_a_sig : std_logic := '0';
  signal seg_left_b_sig : std_logic := '0';
  signal seg_left_c_sig : std_logic := '0';
  signal seg_left_d_sig : std_logic := '0';
  signal seg_left_e_sig : std_logic := '0';
  signal seg_left_f_sig : std_logic := '0';
  signal seg_left_g_sig : std_logic := '0';
  
  signal seg_right_a_sig : std_logic := '0';
  signal seg_right_b_sig : std_logic := '0';
  signal seg_right_c_sig : std_logic := '0';
  signal seg_right_d_sig : std_logic := '0';
  signal seg_right_e_sig : std_logic := '0';
  signal seg_right_f_sig : std_logic := '0'; 
  signal seg_right_g_sig : std_logic := '0';  
  
  -- FSM state type
  type t_press_state is (IDLE, PRESS_COUNT, LONG_HELD, LONG_RELEASE);
  signal press_state : t_press_state := IDLE;

begin

  ----- Process: Button Synchronizer
  process(clk_in)
  begin
      if rising_edge(clk_in) then
          btn_sync_0 <= button_no_1;
          btn_sync_1 <= btn_sync_0;
      end if;
  end process;
  
  
  ----- Process: Debounce
  process(clk_in)
  	variable deb_count : integer range 0 to DEBOUNCE_MAX := 0;
  begin
  	if rising_edge(clk_in) then
    	if btn_sync_1 /= btn_debounced then      --is the current button state and previous button state the not same;   yes=button changed, start counter;  no=same as before, do nothing, reset counter 
        	if deb_count < DEBOUNCE_MAX then
            	deb_count := deb_count + 1;  --incrementing the counter
            else
            	btn_debounced <= btn_sync_1;
                deb_count := 0;
            end if;            
        else
        	deb_count := 0;
        end if;
     end if;
  end process;
  
  
  ----- Process: Press Detector FSM
  process(clk_in)
  	variable press_cnt : integer range 0 to LONGPRESS_MAX := 0;
  begin
  	if rising_edge(clk_in) then
    	short_press <= '0';
        long_press <= '0';
        
        case press_state is
        
        	-- State: IDLE; just wait do nothing
        	when IDLE =>
            	press_cnt := 0;                
                if btn_debounced = '1' then --checks whther button is pressed; i- so button just pressed, so start counting its duration
                	press_state <= PRESS_COUNT;
                end if;
            
            -- State: PRESS_COUNT; button is held, start counting how long its held
            when PRESS_COUNT =>            	
                if btn_debounced = '0' then --button released, counter never reached long pressed, this was a short press
                	short_press <= '1';
                	press_state <= IDLE;
                elsif press_cnt < LONGPRESS_MAX then
                	press_cnt := press_cnt + 1;
                else
                	long_press <= '1';
                    press_state <= LONG_HELD;
                end if;
                
            -- State: LONG_HELD; its a long press and waiting to release
            when LONG_HELD =>
            	if btn_debounced = '0' then --button is released
                	press_state <= LONG_RELEASE;
                end if;
                
            -- State: LONG_RELEASE; go back to IDLE, no pulse here
            when LONG_RELEASE =>
            	press_cnt := 0;
                press_state <= IDLE;                
                
        end case;
    end if;
  end process;
  
  ----- Process: Brightness Controller
  process(clk_in)
  begin
  	if rising_edge(clk_in) then
    	-- short press: toggle off or on
        if short_press = '1' then
        	if lamp_on = '0' then
            	lamp_on <= '1';
            else
            	lamp_on <= '0';
            end if;
        end if;
        
        -- long press: change brightness
        if long_press ='1' and lamp_on = '1' then
        	if dim_dir = '1' then --going up
            	if brightness = 4 then
                	dim_dir <= '0';
                    brightness <= brightness - 1;
                else
                	brightness <= brightness + 1;
                end if;
            else
            	if brightness = 0 then -- going down
                	dim_dir <= '1';
                    brightness <= brightness + 1;
                else
                	brightness <= brightness - 1;
                end if;
            end if;
        end if;
        
    end if;
  end process;
  
  
  ----- Process: PWM Generator
  process(clk_in)
  begin
  	if rising_edge(clk_in) then
    	
        -- counter 0 to 1023, then wraps to 0, this repeats 23,437 times per second
        if pwm_counter = PWM_PERIOD - 1 then
        	pwm_counter <= (others => '0');
        else
        	pwm_counter <= pwm_counter + 1;
        end if;
        
        -- calculate duty cycle; duty_cycle=brightness*256
        duty_cycle <= to_unsigned(to_integer(brightness)*DIM_STEP,11);
        
        -- generate PWM output; LED is on while counter < duty_cycle
        if lamp_on = '1' and pwm_counter < duty_cycle then
        	pwm_out <= '1';
        else
        	pwm_out <= '0';
        end if;        
        
    end if;
  end process;
  
  
  ----- Process: 7-Segment Display
  process(clk_in)
  begin
  	if rising_edge(clk_in) then
    
    	-- LEFT segment: '0' for lamp_off and '1' for lamp_on
        if lamp_on ='0' then
        	-- '0' lamp_off
        	seg_left_a_sig <= '1';
            seg_left_b_sig <= '1';
            seg_left_c_sig <= '1';
            seg_left_d_sig <= '1';
            seg_left_e_sig <= '1';
            seg_left_f_sig <= '1';
            seg_left_g_sig <= '0';                        
        else
        	-- '1' lamp_on
            seg_left_a_sig <= '0';
            seg_left_b_sig <= '1';
            seg_left_c_sig <= '1';
            seg_left_d_sig <= '0';
            seg_left_e_sig <= '0';
            seg_left_f_sig <= '0';
            seg_left_g_sig <= '0'; 
        end if;
        
        -- RIGHT segment: brightness level 0 to 4 
        case brightness is
        
        	when "000" =>
            	-- Level 0
            	seg_right_a_sig <= '1';
                seg_right_b_sig <= '1';
                seg_right_c_sig <= '1';
                seg_right_d_sig <= '1';
                seg_right_e_sig <= '1';
                seg_right_f_sig <= '1';
                seg_right_g_sig <= '0';
            
            when "001" =>
            	-- Level 1
            	seg_right_a_sig <= '0';
                seg_right_b_sig <= '1';
                seg_right_c_sig <= '1';
                seg_right_d_sig <= '0';
                seg_right_e_sig <= '0';
                seg_right_f_sig <= '0';
                seg_right_g_sig <= '0';
                
            when "010" =>
            	-- Level 2
            	seg_right_a_sig <= '1';
                seg_right_b_sig <= '1';
                seg_right_c_sig <= '0';
                seg_right_d_sig <= '1';
                seg_right_e_sig <= '1';
                seg_right_f_sig <= '0';
                seg_right_g_sig <= '1';
                
            when "011" =>
            	-- Level 3
            	seg_right_a_sig <= '1';
                seg_right_b_sig <= '1';
                seg_right_c_sig <= '1';
                seg_right_d_sig <= '1';
                seg_right_e_sig <= '0';
                seg_right_f_sig <= '0';
                seg_right_g_sig <= '1';
                
            when "100" =>
            	-- Level 4
            	seg_right_a_sig <= '0';
                seg_right_b_sig <= '1';
                seg_right_c_sig <= '1';
                seg_right_d_sig <= '0';
                seg_right_e_sig <= '0';
                seg_right_f_sig <= '1';
                seg_right_g_sig <= '1';
                
            when others =>
            	-- outside 0-4, display blank
            	seg_right_a_sig <= '0';
                seg_right_b_sig <= '0';
                seg_right_c_sig <= '0';
                seg_right_d_sig <= '0';
                seg_right_e_sig <= '0';
                seg_right_f_sig <= '0';
                seg_right_g_sig <= '0';
        
        end case;
    
    end if;
  end process;
  
  
  
 ----- Wiring outputs to pins; connect internal signals to physical output ports
 
 -- LEDs: all 8 get the same PWM signal
 led_0 <= pwm_out;
 led_1 <= pwm_out;
 led_2 <= pwm_out;
 led_3 <= pwm_out;
 led_4 <= pwm_out;
 led_5 <= pwm_out;
 led_6 <= pwm_out;
 led_7 <= pwm_out;
 
 -- Left 7-segment digit
 seg_left_a <= seg_left_a_sig;
 seg_left_b <= seg_left_b_sig;
 seg_left_c <= seg_left_c_sig;
 seg_left_d <= seg_left_d_sig;
 seg_left_e <= seg_left_e_sig;
 seg_left_f <= seg_left_f_sig;
 seg_left_g <= seg_left_g_sig;
 
 -- Right 7-segment digit
 seg_right_a <= seg_right_a_sig;
 seg_right_b <= seg_right_b_sig;
 seg_right_c <= seg_right_c_sig;
 seg_right_d <= seg_right_d_sig;
 seg_right_e <= seg_right_e_sig;
 seg_right_f <= seg_right_f_sig;
 seg_right_g <= seg_right_g_sig;
 
 -- PMOD connector (oscilloscope signals)
 pmod_c_pin_1 <= pwm_out; -- pin 1: PWM output (see duty cycle change as you dim)
 pmod_c_pin_2 <= btn_debounced; -- pin 2: debounced button (clean signal, no bounce)
 pmod_c_pin_3 <= short_press; -- pin 3: short press pulse (tiny 1-tick spike)
 pmod_c_pin_4 <= long_press; -- pin 4: long press pulse (tiny 1-tick spike at 500ms)
                
        
end architecture rtl;
