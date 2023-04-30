// Copyright ⓒ 2023 Douglas P. Fields, Jr. All Rights Reserved.

module DE2_ScrollHatMini (
  //////////// CLOCK //////////
  input  logic        CLOCK_50,
  input  logic        CLOCK2_50,
  input  logic        CLOCK3_50,

  //////////// LED //////////
  output logic  [8:0] LEDG,
  output logic [17:0] LEDR,

  //////////// KEY //////////
  // These are logic 0 when pressed
  input  logic  [3:0] KEY,

  //////////// SW //////////
  input  logic [17:0] SW,

  //////////// SEG7 //////////
  // All of these use logic 0 to light up the segment
  // These are off with logic 1
  output logic  [6:0] HEX0,
  output logic  [6:0] HEX1,
  output logic  [6:0] HEX2,
  output logic  [6:0] HEX3,
  output logic  [6:0] HEX4,
  output logic  [6:0] HEX5,
  output logic  [6:0] HEX6,
  output logic  [6:0] HEX7,

	//////////// GPIO, GPIO connect to GPIO Default //////////
	inout        [35:0] GPIO
);

// GPIO Mappings:
// Logical GPIO  -  GPIO Pin  - FPGA Pin  - RPi Pin - Name
// 28               33          AH22        29        A
// 30               35          AE20        31        B
// 32               37          AF20        36        X
// 34               39          AH23        18        Y
// 35               40          AG26        5         SCL (I²C)
// 33               38          AH23        3         SDA (I²C)

// Feed power and ground
// I am feeding 3.3V to the 5V inputs

// Try an internal weak-pull-up for the two I2C pins and see
// if we can get away with that.

/////////////////////////////////////////////////////////////////////////////////////
// Scroll Hat Mini Buttons

// The Pimoroni ScrollHatMini buttons are pulled to ground when unpressed,
// so use a weak pullup on those pins in the .qsf file/assignment editor.
// These buttons aren't on Schmitt triggers so they should also be debounced.
/*
  set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to GPIO[34]
  set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to GPIO[32]
  set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to GPIO[30]
  set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to GPIO[28]
*/

assign LEDG[0] = ~GPIO[28];
assign LEDG[1] = ~GPIO[30];
assign LEDG[2] = ~GPIO[32];
assign LEDG[3] = ~GPIO[34];

// The scroll hat mini keys, debounced
logic [3:0] shm_key;

PushButton_Debouncer db_a (.clk(CLOCK_50), .PB(GPIO[28]), .PB_state(shm_key[0]));
PushButton_Debouncer db_b (.clk(CLOCK_50), .PB(GPIO[30]), .PB_state(shm_key[1]));
PushButton_Debouncer db_x (.clk(CLOCK_50), .PB(GPIO[32]), .PB_state(shm_key[2]));
PushButton_Debouncer db_y (.clk(CLOCK_50), .PB(GPIO[34]), .PB_state(shm_key[3]));

assign LEDR[3:0] = shm_key;

/////////////////////////////////////////////////////////////////////////////////////
// Scroll Hat Mini Display
// I²C address: 0x74

// I²C signals
logic scl_i, scl_o, scl_e;
logic sda_i, sda_o, sda_e;

localparam REPEAT_SZ = 6;

// assign I2C_GPIO = {GPIO[33], GPIO[35]}; // SDA, SCL

// Use an ALTIOBUF with open-drain set for I2C.
// Datain means IN TO THE BUFFER, which would be OUT FROM THIS MODULE
// and hence OUT TO THE EXTERNAL PIN
altiobuf_opendrain sda_iobuf (
	.dataio  (GPIO[33]),
	.oe      (sda_e),
	.datain  (sda_o),
	.dataout (sda_i)
);
altiobuf_opendrain scl_iobuf (
	.dataio  (GPIO[35]),
	.oe      (scl_e),
	.datain  (scl_o),
	.dataout (scl_i)
);

// I2C controller outputs
logic busy, abort, success;

// I2C controller inputs
logic       activate;  // True to begin when !busy
logic [7:0] location;
logic [7:0] data;
logic [REPEAT_SZ-1:0] data_repeat;

localparam LOC_COMMAND_REGISTER = 8'hFD;
localparam LOC_SHUTDOWN_REGISTER = 8'h0A; // bit 0 is shutdown, defaults to 0
localparam PAGE_FUNCTION_REGISTER = 8'b0000_1011;
localparam PAGE_FRAME_1 = 8'b0000_0000;
localparam FRAME_LED_CONTROL_REGISTER = 8'h00;
localparam FRAME_PWM_OFFSET = 8'h24; // Where the PWM registers start - 144 of them
localparam NUM_LED_CONTROL_REGISTERS = 8'h12; // 0x00-11
localparam NUM_PWM_REGISTERS = 8'd144; // Not all are connected in our 17x7

localparam NUM_COLS = 8'd17;
localparam NUM_ROWS = 8'd7;
localparam NUM_LEDS = (8)'(NUM_COLS * NUM_ROWS); // 17 x 7 = 119

I2C_CONTROLLER #(
  .CLK_DIV(32),
  .REPEAT_SZ(REPEAT_SZ)
) scroll_hat_mini_i2c (
  .clk(CLOCK_50),
  .reset(),

  .scl_i, .scl_o, .scl_e,
  .sda_i, .sda_o, .sda_e,

  .busy,
  .abort,
  .success,

  .activate,
  .read('0), // We never do a read
  .read_two('0), // We never read two let alone one byte
  .address(7'h74), // Fixed address
  .location,
  .data,
  .data_repeat,

  // Intentionally unconnected:
  .data1(), .data2(), // We don't read
  .start_pulse(), .stop_pulse(), .got_ack() // We aren't debugging
);

typedef enum int unsigned {
  S_POWER_UP_DELAY   = 0,
  S_SET_FUNCTION_REGISTER = 1,
  S_CLEAR_SHUTDOWN   = 2,
  S_SET_FRAME_0      = 3,
  S_SET_ENABLES_1    = 4,
  S_SET_ENABLES_2    = 5,
  S_SET_PWM          = 6,
  S_BEGIN_UPDATE_ALL = 7,
  S_UPDATE_ALL       = 8,
  S_UPDATE_ALL_DONE  = 9,
  S_DONE             = 10,
  S_SEND_COMMAND     = 11,
  S_AWAIT_COMMAND    = 12
} state_t;

state_t state;

// Send command subroutine
// The state to return to after sending a command
state_t return_after_command;
logic [7:0] send_location;
logic [7:0] send_data;
logic [REPEAT_SZ-1:0] send_repeat;
logic send_busy_seen;

logic [31:0] power_up_delay = 32'd50_000_000; // 1 second

// We have to send 144 PWMs, which is 4 x 36
localparam NUM_PWM_REPEAT = 3'd4;
localparam PWM_EACH_TIME = (REPEAT_SZ)'(36);
// FIXME: ASSERT NUM_PWM_REPEAT * PWM_EACH_TIME == 144
logic [2:0] repeat_pwm_count;
logic [7:0] next_pwm_location;
logic [3:0] subroutine_calls = '0;
logic ever_abort = '0;

assign LEDR[9:6] = state;
assign LEDR[17:14] = return_after_command;
assign LEDR[13:10] = subroutine_calls;
assign LEDG[8:5] = {busy, success, ever_abort, activate};

logic [7:0] which_led;

// We have physical leds in a 17x7 matrix
logic [NUM_LEDS-1:0] physical_leds = 1;
// And we have in-memory LEDs
logic [NUM_PWM_REGISTERS-1:0] shm_leds;

// Map a 17x7 array (with the first entry at the top left and
// the last at the bottom right) to the 144 memory locations.
/*
           00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 - columns
          ┌--------------------------------------------------
        0 |86 76 66 56 46 36 26 16 06 08 18 28 38 48 58 68 78
        1 |                     15 05 09
        2 |                     14 04 0A
        3 |                     13 03 0B
        4 |                     12 02 0C
        5 |                     11 01 0D
        6 |80 70 60 50 40 30 20 10 00 0E 1E 2E 3E 4E 5E 6E 7E
*/
always begin
  shm_leds = '0;
  for (int i = 0; i < 9; i++) begin: p1
    shm_leds[8'h10 * (8 - i) + 6] = physical_leds[i + 17 * 0];
    shm_leds[8'h10 * (8 - i) + 5] = physical_leds[i + 17 * 1];
    shm_leds[8'h10 * (8 - i) + 4] = physical_leds[i + 17 * 2];
    shm_leds[8'h10 * (8 - i) + 3] = physical_leds[i + 17 * 3];
    shm_leds[8'h10 * (8 - i) + 2] = physical_leds[i + 17 * 4];
    shm_leds[8'h10 * (8 - i) + 1] = physical_leds[i + 17 * 5];
    shm_leds[8'h10 * (8 - i) + 0] = physical_leds[i + 17 * 6];
  end: p1
  for (int i = 0; i < 8; i++) begin: p2
    shm_leds[8'h10 * i + 8]  = physical_leds[9 + i + 17 * 0];
    shm_leds[8'h10 * i + 9]  = physical_leds[9 + i + 17 * 1];
    shm_leds[8'h10 * i + 10] = physical_leds[9 + i + 17 * 2];
    shm_leds[8'h10 * i + 11] = physical_leds[9 + i + 17 * 3];
    shm_leds[8'h10 * i + 12] = physical_leds[9 + i + 17 * 4];
    shm_leds[8'h10 * i + 13] = physical_leds[9 + i + 17 * 5];
    shm_leds[8'h10 * i + 14] = physical_leds[9 + i + 17 * 6];
  end: p2
end

always_ff @(posedge CLOCK_50) begin: scroll_hat_mini_controller

  ever_abort <= ever_abort || abort;

  case (state)

  S_POWER_UP_DELAY: begin: power_delay
    if (power_up_delay == 0)
      state <= S_SET_FUNCTION_REGISTER;
    else
      power_up_delay <= power_up_delay - 1'd1;
  end: power_delay

  S_SET_FUNCTION_REGISTER: begin
      send_location <= LOC_COMMAND_REGISTER;
      send_data     <= PAGE_FUNCTION_REGISTER;
      send_repeat   <= '0;

      return_after_command <= S_CLEAR_SHUTDOWN;
      state                <= S_SEND_COMMAND;
  end

  S_CLEAR_SHUTDOWN: begin
      send_location <= LOC_SHUTDOWN_REGISTER;
      send_data     <= 8'h01; // Disable shutdown (bit 0)
      send_repeat   <= '0;

      return_after_command <= S_SET_FRAME_0;
      state                <= S_SEND_COMMAND;
  end

  S_SET_FRAME_0: begin
      send_location <= LOC_COMMAND_REGISTER;
      send_data     <= PAGE_FRAME_1;
      send_repeat   <= '0;

      return_after_command <= S_SET_ENABLES_1;
      state                <= S_SEND_COMMAND;
  end

  S_SET_ENABLES_1: begin
      send_location <= FRAME_LED_CONTROL_REGISTER;
      send_data     <= 8'b0111_1111; // Our pattern is 17x this and then 1x 0
      send_repeat   <= (REPEAT_SZ)'(NUM_LED_CONTROL_REGISTERS - 1'd1 - 1'd1); // We already do one, and we want to do one fewer than total registers

      return_after_command <= S_SET_ENABLES_2;
      state                <= S_SEND_COMMAND;
  end

  S_SET_ENABLES_2: begin
      send_location <= FRAME_LED_CONTROL_REGISTER + NUM_LED_CONTROL_REGISTERS - 1'd1;
      send_data     <= '0; // 1x 0
      send_repeat   <= '0;

      return_after_command <= S_SET_PWM;
      state                <= S_SEND_COMMAND;
      repeat_pwm_count     <= '0;
      next_pwm_location    <= FRAME_PWM_OFFSET;
  end

  S_SET_PWM: begin
      send_location <= next_pwm_location;
      send_data     <= 8'b0000_1000 << repeat_pwm_count; // Vary the brightness (8'hFF is super bright)
      send_repeat   <= PWM_EACH_TIME - 1'd1; // Repeat one less than total # we want it to do

      next_pwm_location <= next_pwm_location + PWM_EACH_TIME;
      repeat_pwm_count  <= repeat_pwm_count + 1'd1;

      state                <= S_SEND_COMMAND;

      if (repeat_pwm_count == (NUM_PWM_REPEAT - 1'd1))
        return_after_command <= S_BEGIN_UPDATE_ALL;
      else
        return_after_command <= S_SET_PWM;
  end

  S_DONE: begin
    // Nothing to do
  end

  S_BEGIN_UPDATE_ALL: begin
    // Send data for all LEDs from our shm_leds bits
    next_pwm_location <= FRAME_PWM_OFFSET;
    which_led         <= '0;
    state             <= S_UPDATE_ALL;
    power_up_delay    <= 32'd0_000_100;
  end

  S_UPDATE_ALL: begin
    send_location <= next_pwm_location;
    send_data     <= shm_leds[which_led] ? 8'hFF : 8'h00; // On or off
    send_repeat   <= '0;

    next_pwm_location <= next_pwm_location + 1'd1;
    which_led         <= which_led + 1'd1;

    state <= S_SEND_COMMAND;
    if (next_pwm_location == FRAME_PWM_OFFSET + NUM_PWM_REGISTERS - 1'd1)
      return_after_command <= S_UPDATE_ALL_DONE;
    else
      return_after_command <= S_UPDATE_ALL;
  end

  S_UPDATE_ALL_DONE: begin
    if (power_up_delay == 0) begin
      // Light the next LED
      // shm_leds <= {shm_leds[NUM_PWM_REGISTERS-2:0], shm_leds[NUM_PWM_REGISTERS-1]};
      physical_leds <= {physical_leds[NUM_LEDS-2:0], physical_leds[NUM_LEDS-1]};
      state <= S_BEGIN_UPDATE_ALL;
    end else begin
      power_up_delay <= power_up_delay - 1'd1;
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////
  // SUBROUTINES /////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  S_SEND_COMMAND: begin: send_command
    // Send a specific I2C command, and return to the specified state
    // after it is done.
    if (busy) begin
      // Wait for un-busy
      activate <= '0;
    end else begin
      location    <= send_location;
      data        <= send_data;
      data_repeat <= send_repeat;
      activate    <= '1;
      state       <= S_AWAIT_COMMAND;
      send_busy_seen <= '0;

      // Debugging
      subroutine_calls <= subroutine_calls + 1'd1;
    end
  end: send_command

  S_AWAIT_COMMAND: begin: await_command
    // Wait for busy to go true, then go false
    case ({send_busy_seen, busy})
    2'b01: begin: busy_starting
      // We are seeing busy for the first time
      send_busy_seen <= '1;
      activate <= '0;
    end: busy_starting
    2'b10: begin: busy_ending
      // Busy is now ending
      state <= return_after_command;
    end: busy_ending
    endcase
  end: await_command


  endcase // state

end: scroll_hat_mini_controller




endmodule
