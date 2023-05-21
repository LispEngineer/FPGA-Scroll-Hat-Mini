// Copyright ⓒ 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
// Licensed under Solderpad Hardware License 2.1 - see LICENSE

// Generic controller for SSD1306 displays.

// Make sure to use external pull-up resistors of appropriate values.
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


module ssd1306_controller #(

  parameter CLK_DIV = 32,

  // clocks to delay during power up
  parameter POWER_UP_DELAY = 32'd50_000_000, // 1 second
  parameter REFRESH_DELAY = 32'd01_000_000, // 50x a second or 20ms

  // DO NOT CHANGE THESE - from text_pixel_generator
  parameter TEXT_WIDTH  = 16,
  parameter TEXT_HEIGHT = 4,
  parameter TEXT_LEN = TEXT_WIDTH * TEXT_HEIGHT,
  parameter TEXT_SZ = $clog2(TEXT_LEN)
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

  // Character write interface to text RAM
  input logic               clk_text_wr,
  input logic               text_wr_ena,
  input logic         [7:0] text_wr_data,
  input logic [TEXT_SZ-1:0] text_wr_addr
);

////////////////////////////////////////////////////////////////////////////
// Display characters

logic toggle_restart = '0;
logic toggle_next = '0;
logic [7:0] cur_pixels;

text_pixel_generator_16x4_vertical text_gen_inst (
  .clk, .reset,

  .toggle_restart,
  .toggle_next,

  .cur_pixels,

  // We're not using these signals... yet
  .cur_char(),

  .clk_text_wr,
  .text_wr_ena,
  .text_wr_data,
  .text_wr_addr
);


////////////////////////////////////////////////////////////////////////////
// Initialization


localparam NUM_INIT_BYTES = 3;
localparam NUM_INIT_STEPS = 17;
// Byte 0 = length (including the 00 not in the init strings)
// First byte sent is always 00 (which means a command for SSD1306)
logic [7:0] init [NUM_INIT_STEPS][NUM_INIT_BYTES];

/*
.\i2ccl COM4 w 0x3C 0x00,0xAE p
.\i2ccl COM4 w 0x3C 0x00,0xD5,0x80 p
.\i2ccl COM4 w 0x3C 0x00,0xA8,0x3F p
.\i2ccl COM4 w 0x3C 0x00,0xD3,0x00 p
.\i2ccl COM4 w 0x3C 0x00,0x40 p
.\i2ccl COM4 w 0x3C 0x00,0x8D,0x14 p
.\i2ccl COM4 w 0x3C 0x00,0x20,0x00 p
.\i2ccl COM4 w 0x3C 0x00,0xA1 p
.\i2ccl COM4 w 0x3C 0x00,0xC8 p
.\i2ccl COM4 w 0x3C 0x00,0xDA,0x12 p
.\i2ccl COM4 w 0x3C 0x00,0x81,0x80 p
.\i2ccl COM4 w 0x3C 0x00,0xD9,0xF1 p
.\i2ccl COM4 w 0x3C 0x00,0xDB,0x20 p
.\i2ccl COM4 w 0x3C 0x00,0xA4 p
.\i2ccl COM4 w 0x3C 0x00,0xA6 p
.\i2ccl COM4 w 0x3C 0x00,0x2E p
.\i2ccl COM4 w 0x3C 0x00,0xAF p
*/

initial begin
  init = '{default: 8'd0};
  init[0][0] = 8'd2; init[0][1] = 8'hae;

  init[1][0] = 8'd3; init[1][1] = 8'hd5; init[1][2] = 8'h80;
  init[2][0] = 8'd3; init[2][1] = 8'ha8; init[2][2] = 8'h3f;
  init[3][0] = 8'd3; init[3][1] = 8'hd3; init[3][2] = 8'h00;

  init[4][0] = 8'd2; init[4][1] = 8'h40;

  init[5][0] = 8'd3; init[5][1] = 8'h8d; init[5][2] = 8'h14;
  init[6][0] = 8'd3; init[6][1] = 8'h20; init[6][2] = 8'h00;

  init[7][0]  = 8'd2; init[7][1]  = 8'ha1;
  init[8][0]  = 8'd2; init[8][1]  = 8'hc8;

  init[9][0]  = 8'd3; init[9][1]  = 8'hda; init[9][2]  = 8'h12;
  init[10][0] = 8'd3; init[10][1] = 8'h81; init[10][2] = 8'h80;
  init[11][0] = 8'd3; init[11][1] = 8'hd9; init[11][2] = 8'hf1;
  init[12][0] = 8'd3; init[12][1] = 8'hdb; init[12][2] = 8'h20;
  
  init[13][0] = 8'd2; init[13][1] = 8'ha4;
  init[14][0] = 8'd2; init[14][1] = 8'ha6;
  init[15][0] = 8'd2; init[15][1] = 8'h2e;
  init[16][0] = 8'd2; init[16][1] = 8'haf;
end

////////////////////////////////////////////////////////////////////////////
// I²C Interface

// I2C controller outputs
logic busy, abort, success;

// I2C controller inputs
logic activate;  // True to begin when !busy

localparam SEND_MAX = 5;
localparam SEND_SZ = $clog2(SEND_MAX + 1);
localparam READ_MAX = 1;
localparam READ_SZ = $clog2(READ_MAX + 1);

logic [SEND_SZ-1:0] send_count;
logic         [7:0] send_data [SEND_MAX];

initial send_data = '{default: '0};

i2c_controller_v2 #(
  .CLK_DIV(CLK_DIV),
  .SEND_MAX(SEND_MAX),
  .READ_MAX(READ_MAX)
) ssd1306_i2c_inst (
  .clk,
  .reset,

  .scl_i, .scl_o, .scl_e,
  .sda_i, .sda_o, .sda_e,

  .busy,
  .abort,
  .success,

  .activate,
  .read('0), // We never do a read
  .address(7'h3C), // Fixed address

  .send_count,
  .send_data,
  .read_count('0), // We never read
  .read_data(), 

  // Intentionally unconnected:
  .start_pulse(), .stop_pulse(), .got_ack() // We aren't debugging
);


////////////////////////////////////////////////////////////////////////////
// SSD1306 State Machine

localparam DISP_WIDTH = 128;
localparam DISP_HEIGHT = 64;
localparam PIXELS_PER_UPDATE = 8;
localparam UPDATE_COUNT = DISP_WIDTH * DISP_HEIGHT / PIXELS_PER_UPDATE;
localparam UPDATE_SZ = $clog2(UPDATE_COUNT);
localparam LAST_UPDATE = (UPDATE_SZ)'(UPDATE_COUNT - 1);

typedef enum int unsigned {
  S_POWER_UP         = 0,
  S_INIT             = 1,
  S_UPDATE_START     = 2,
  S_UPDATE_START_2   = 3,
  S_UPDATE           = 4,
  S_IDLE             = 5,
  S_SEND_COMMAND     = 6,
  S_AWAIT_COMMAND    = 7,
  S_DELAY            = 8
} state_t;
localparam state_t S_INIT_START = S_INIT;

state_t state;

// Subroutines:
// The state to return to after sending a command or doing a delay
state_t return_after_command;
logic send_busy_seen;

logic [31:0] delay_count = POWER_UP_DELAY;
logic [5:0] init_step;

logic [UPDATE_SZ-1:0] update_step;



always_ff @(posedge clk) begin: controller

  case (state)

  S_POWER_UP: begin: pwr_up
    // Give the module a moment to power up
    // The datasheet may say a required startup time but I didn't quickly find it
    delay_count          <= POWER_UP_DELAY;
    state                <= S_DELAY;
    return_after_command <= S_INIT_START;
    init_step            <= '0;
    activate             <= '0;
  end: pwr_up

  ////////////////////////////////////////////////////////////////////////////////
  // Initialization

  S_INIT: begin: do_init
    send_data[0]         <= 8'h00; // Location is always 0 meaning "command"
    for (int i = 1; i < NUM_INIT_BYTES; i++)
      send_data[i] <= init[init_step][i];
    send_count <= (SEND_SZ)'(init[init_step][0]);

    init_step            <= init_step + 1'd1;
    state                <= S_SEND_COMMAND;
    return_after_command <= init_step == NUM_INIT_STEPS - 1 ? S_UPDATE_START : S_INIT;
  end: do_init

  ////////////////////////////////////////////////////////////////////////////////
  // Initialization

  S_UPDATE_START: begin
    send_count   <= (SEND_SZ)'(4);
    send_data[0] <= 8'h00; // Location is 0 meaning "command"
    send_data[1] <= 8'hB0; // First page
    send_data[2] <= 8'h00; // First column (low bits)
    send_data[3] <= 8'h10; // First column (high bits)

    state                <= S_SEND_COMMAND;
    return_after_command <= S_UPDATE;

    toggle_restart       <= ~toggle_restart;
    update_step          <= '0;
  end

  S_UPDATE: begin
    send_count   <= (SEND_SZ)'(2);
    send_data[0] <= 8'h40; // Location is 40 meaning "data"
    for (int i = 0; i < 8; i++)
      send_data[1][i] = cur_pixels[7-i]; // Sent data MSB is on on lowest line

    state                <= S_SEND_COMMAND;
    return_after_command <= update_step == LAST_UPDATE ? S_IDLE : S_UPDATE;
    update_step          <= update_step + 1'd1;
    toggle_next          <= ~toggle_next;
    delay_count          <= REFRESH_DELAY;
  end

  S_IDLE: begin
    if (delay_count == 0)
      state <= S_UPDATE_START;
    else
      delay_count <= delay_count - 1'd1;
  end

  ////////////////////////////////////////////////////////////////////////////////////
  // SUBROUTINES /////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  S_SEND_COMMAND: begin: send_command
    // Send a specific I²C command, and return to the specified state
    // after it is done.
    if (busy) begin
      // Wait for un-busy
      activate <= '0;
    end else begin
      // send_data is set by the caller
      // send_count is set by the caller
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

  ////////////////////////////////////////////////////////////////////////////////
  // Delay subroutine

  S_DELAY: begin: do_delay
    if (delay_count == 0)
      state <= return_after_command;
    else
      delay_count <= delay_count - 1'd1;
  end: do_delay

  endcase // state

  if (reset) begin
    state <= S_POWER_UP;
    activate <= '0;
  end

end: controller




endmodule

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
`default_nettype wire // turn implicit nets on again to avoid side-effects
`endif
