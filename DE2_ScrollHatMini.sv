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


I2C_CONTROLLER #(
  .CLK_DIV(128),
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


always_ff @(posedge CLOCK_50) begin
end




endmodule
