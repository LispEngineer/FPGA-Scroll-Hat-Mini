// Copyright ⓒ 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
// Licensed under Solderpad Hardware License 2.1 - see LICENSE

// Controller for Keyestudio 8x8 LED matrix.

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
// This doesn't work in Questa for some reason. vlog-2892 errors.
`default_nettype none // Disable implicit creation of undeclared nets
`endif


module keyestudio_8x8_controller #(

  parameter CLK_DIV = 32,

  // clocks to delay during power up
  parameter POWER_UP_DELAY = 32'd50_000_000, // 1 second
  parameter REFRESH_DELAY = 32'd01_000_000, // 50x a second or 20ms

  parameter LED_BYTES = 8,
  parameter LED_SZ = $clog2(LED_BYTES)
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
  input  logic [7:0]  leds[LED_BYTES]
);

// From VK16K33 controller
localparam MEM_LEN = 16;
localparam MEM_SZ = $clog2(MEM_LEN);

logic [7:0] mem[MEM_LEN];

/*
80 = col 1 (leftmost)
40 = col 8 (rightmost)
20 = col 7
10 = col 6
08 = col 5
04 = col 4
02 = col 3
01 = col 2
*/

// Map our LEDs to our MEMory
always_comb begin
  for (int i = 0; i < LED_BYTES; i++) begin
    // Odd bytes are not used
    mem[(i << 1) + 1] = 8'h00;
    mem[i << 1][7] = leds[i][7];
    for (int j = 0; j < 7; j++)
      mem[i << 1][j] = leds[i][6-j];
  end
end

vk16k33_controller #(
  .REFRESH_DELAY(32'd00_200_000) // 250x a second
) keyestudio_8x8_inst (
  .clk,
  .reset,

  // I²C Signals
  .scl_i,
  .scl_o, 
  .scl_e,
  .sda_i, 
  .sda_o, 
  .sda_e,

  // LED memory
  .mem
);



endmodule

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
`default_nettype wire // turn implicit nets on again to avoid side-effects
`endif
