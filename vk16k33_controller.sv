// Copyright ⓒ 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
// Licensed under Solderpad Hardware License 2.1 - see LICENSE

// Generic controller for Vinka VK16K33 LED Driver IC.
// This handles only the LED output for now, and not key input.
// This should be similar to the Holtek HT16K33 chip.
// See datasheet Rev 1.0 2017-06-27.

// Maximum clock frequency is 400kHz (p29).
// Buss free time of 1.3µs is required between transmissions.

// Use an ALTIOBUF with open-drain set for I2C.
// Datain means IN TO THE BUFFER, which would be OUT FROM THIS MODULE
// and hence OUT TO THE EXTERNAL PIN.
// Example:
/*
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
*/

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
// This doesn't work in Questa for some reason. vlog-2892 errors.
`default_nettype none // Disable implicit creation of undeclared nets
`endif


module vk16k33_controller #(

  parameter CLK_DIV = 32,

  // clocks to delay during power up
  parameter POWER_UP_DELAY = 32'd50_000_000, // 1 second
  parameter REFRESH_DELAY = 32'd01_000_000, // 50x a second or 20ms

  // Do not change these!
  parameter MEM_LEN = 16,
  parameter MEM_SZ = $clog2(MEM_LEN)
) (
  input  logic        clk,
  input  logic        reset,

  // I²C Signals for the SHM
  input  logic        scl_i,
  output logic        scl_o, 
  output logic        scl_e,
  input  logic        sda_i, 
  output logic        sda_o, 
  output logic        sda_e,

  // What to display: physical leds in _some_ manner
  input  logic [7:0]  mem[MEM_LEN]
);

localparam REPEAT_SZ = 0;

// I2C controller outputs
logic busy, abort, success;

// I2C controller inputs
logic       activate;  // True to begin when !busy
logic [7:0] location;
logic [7:0] data;

localparam CMD_SYSTEM_ON = 8'h21;
localparam CMD_DISPLAY_ON = 8'h81;

I2C_CONTROLLER #(
  .CLK_DIV(CLK_DIV),
  .REPEAT_SZ(REPEAT_SZ)
) scroll_hat_mini_i2c (
  .clk,
  .reset,

  .scl_i, .scl_o, .scl_e,
  .sda_i, .sda_o, .sda_e,

  .busy,
  .abort,
  .success,

  .activate,
  .read('0), // We never do a read
  .read_two('0), // We never read two let alone one byte
  .address(7'h70), // Fixed address
  .location,
  .data,
  .data_repeat('0),

  // Intentionally unconnected:
  .data1(), .data2(), // We don't read
  .start_pulse(), .stop_pulse(), .got_ack() // We aren't debugging
);

typedef enum int unsigned {
  S_POWER_UP_DELAY   = 0,
  S_INIT_1           = 1,
  S_INIT_2           = 2,
  S_UPDATE_DISPLAY   = 3,
  S_IDLE             = 4,
  S_SEND_COMMAND     = 5,
  S_AWAIT_COMMAND    = 6
} state_t;

state_t state;

// Send command subroutine
// The state to return to after sending a command
state_t return_after_command;
logic [7:0] send_location;
logic [7:0] send_data;
logic send_busy_seen;

logic [31:0] power_up_delay = POWER_UP_DELAY;

logic [MEM_SZ-1:0] mem_loc;


always_ff @(posedge clk) begin: controller

  case (state)

  S_POWER_UP_DELAY: begin: power_delay
    if (power_up_delay == 0)
      state <= S_INIT_1;
    else
      power_up_delay <= power_up_delay - 1'd1;
  end: power_delay

  S_INIT_1: begin
    send_location <= CMD_SYSTEM_ON;
    send_data     <= CMD_SYSTEM_ON; // Ideally, suppress sending this

    return_after_command <= S_INIT_2;
    state                <= S_SEND_COMMAND;
  end

  S_INIT_2: begin
    send_location <= CMD_DISPLAY_ON;
    send_data     <= CMD_DISPLAY_ON; // Ideally, suppress sending this

    return_after_command <= S_UPDATE_DISPLAY;
    mem_loc              <= '0;
    state                <= S_SEND_COMMAND;
  end

  S_UPDATE_DISPLAY: begin
    // Location command: 8'b0000_#### where #### is the address
    send_location <= {4'b0000, mem_loc};
    send_data     <= mem[mem_loc];

    state <= S_SEND_COMMAND;
    if (mem_loc == (MEM_SZ)'(MEM_LEN - 1)) begin
      power_up_delay <= REFRESH_DELAY;
      return_after_command <= S_IDLE;
    end else begin
      mem_loc <= mem_loc + 1'd1;
      return_after_command <= S_UPDATE_DISPLAY;
    end
  end

  S_IDLE: begin
    if (power_up_delay == 0) begin
      state <= S_UPDATE_DISPLAY;
      mem_loc <= '0;
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
      activate    <= '1;
      state       <= S_AWAIT_COMMAND;
      send_busy_seen <= '0;
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

end: controller




endmodule

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
`default_nettype wire // turn implicit nets on again to avoid side-effects
`endif
