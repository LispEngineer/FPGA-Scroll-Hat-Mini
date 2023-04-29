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
	inout  logic [35:0]	GPIO

);

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

endmodule
