// Copyright ⓒ 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
// Licensed under Solderpad Hardware License 2.1 - see LICENSE

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
// This doesn't work in Questa for some reason. vlog-2892 errors.
`default_nettype none // Disable implicit creation of undeclared nets
`endif


module DE2_I2CPeripherals (
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
	inout        [35:0] GPIO,

  // EX_IO (See p51, Figure 4-20, table 4-13)
  // 6 = Pull down
  // 4 = Pull up & inline resistor
  // All others = pull up resistors
  inout        [6:0] EX_IO
);

////////////////////////////////////////////////////////////////////////////////////////
// Common I2C Signals

// I²C signals
logic scl_i, scl_o, scl_e;
logic sda_i, sda_o, sda_e;

// Use an ALTIOBUF with open-drain set for I2C.
// Datain means IN TO THE BUFFER, which would be OUT FROM THIS MODULE
// and hence OUT TO THE EXTERNAL PIN
altiobuf_opendrain scl_iobuf (
	.dataio  (EX_IO[0]),
	.oe      (scl_e),
	.datain  (scl_o),
	.dataout (scl_i)
);
altiobuf_opendrain sda_iobuf (
	.dataio  (EX_IO[1]),
	.oe      (sda_e),
	.datain  (sda_o),
	.dataout (sda_i)
);


////////////////////////////////////////////////////////////////////////////////////////
// Keyestudio 8x8 matrix demo


`define KEYESTUDIO_8x8_DEMO
`ifdef KEYESTUDIO_8x8_DEMO

localparam MEM_LEN = 8;
localparam MEM_SZ = $clog2(MEM_LEN);

logic [7:0] mem[MEM_LEN];

initial begin
  // Draw a silly box
  mem[0] = 8'hFF;
  mem[1] = 8'h81;
  mem[2] = 8'h81;
  mem[3] = 8'h81;
  mem[4] = 8'h81;
  mem[5] = 8'h81;
  mem[6] = 8'h81;
  mem[7] = 8'hFF;
end

keyestudio_8x8_controller #(
  .REFRESH_DELAY(32'd00_200_000) // 250x a second
) keyestudio_8x8_inst (
  .clk(CLOCK_50),
  .reset(),

  // I²C Signals
  .scl_i,
  .scl_o, 
  .scl_e,
  .sda_i, 
  .sda_o, 
  .sda_e,

  // LED memory
  .leds(mem)
);


localparam INTERVAL = 32'd20_000_000;
logic [31:0] interval_count = INTERVAL;

// Animate
always_ff @(posedge CLOCK_50) begin
  if (interval_count == '0) begin
    interval_count <= INTERVAL;
    for (int i = 0; i < MEM_LEN; i++) begin
      mem[i][7:1] = mem[i][6:0];
      mem[i][0] = mem[i == 0 ? MEM_LEN - 1 : i - 1][7];
    end
  end else begin
    interval_count <= interval_count - 1'd1;
  end
end

`endif

////////////////////////////////////////////////////////////////////////////////////////
// Scroll Hat Mini Demo

`undef SCROLL_HAT_MINI_DEMO
`ifdef SCROLL_HAT_MINI_DEMO

// GPIO Mappings:
// Logical GPIO  -  GPIO Pin  - FPGA Pin  - RPi Pin - Name
// 28               33          AH22        29        A
// 30               35          AE20        31        B
// 32               37          AF20        36        X
// 34               39          AH23        18        Y
// EX_IO[0]         13           J10        5         SCL (I²C)
// EX_IO[1]         11           J14        3         SDA (I²C)
// EX_IO Vcc        14          3.3V        2/4       5V
// EX_IO Gnd        12                      6         Gnd

// Feed power and ground
// I am feeding 3.3V to the 5V input of the SHM, which is fine.

// An internal weak-pull-up for the two I2C pins does not work.

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

localparam REPEAT_SZ = 6;

localparam NUM_COLS = 8'd17;
localparam NUM_ROWS = 8'd7;
localparam NUM_LEDS = (8)'(NUM_COLS * NUM_ROWS); // 17 x 7 = 119

logic [NUM_LEDS-1:0] shm_leds = 1;

scroll_hat_mini_controller shm_inst /* #(

  parameter CLK_DIV = 32,

  // clocks to delay during power up
  parameter POWER_UP_DELAY = 32'd50_000_000, // 1 second
  parameter REFRESH_DELAY = 32'd00_500_000, // 100x a second or 10ms

  // Do not change these!
  parameter NUM_COLS = 8'd17,
  parameter NUM_ROWS = 8'd7,
  parameter NUM_LEDS = (8)'(NUM_COLS * NUM_ROWS) // 17 x 7 = 119

) */ (
  .clk(CLOCK_50),
  .reset(),

  // I²C Signals for the SHM
  .scl_i,
  .scl_o, 
  .scl_e,
  .sda_i, 
  .sda_o, 
  .sda_e,

  // What to display: physical leds in a 17x7 matrix
  .physical_leds(shm_leds)
);

localparam INTERVAL = 32'd2_000_000;
logic [31:0] interval_count = INTERVAL;

// Animate
always_ff @(posedge CLOCK_50) begin
  if (interval_count == '0) begin
    interval_count <= INTERVAL;
    shm_leds = {shm_leds[NUM_LEDS-2:0], shm_leds[NUM_LEDS-1]};
  end else begin
    interval_count <= interval_count - 1'd1;
  end
end

`endif //  SCROLL_HAT_MINI_DEMO

endmodule



`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
`default_nettype wire // turn implicit nets on again to avoid side-effects
`endif
