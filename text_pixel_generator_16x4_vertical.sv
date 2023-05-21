// Copyright ⓒ 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
// Licensed under Solderpad Hardware License 2.1 - see LICENSE
//
// Text pixel delivery from character memory. This differs from the
// non _vertical version because it prepares pixels for displays which
// take an 8-vertical list of pixels instead of an 8-horizontal list of
// pixels ata a time.
//
// Font used is IBM Code Page 437 https://en.wikipedia.org/wiki/Code_page_437
// with two additions:
// Char 8'h00 = empty box, except for the last column
// Char 8'hFF = five full-width horizontal lines
// (these are blank in the original font)
//
// The font size is 8x16 for ease of display (powers of 2).
//
// The font is transposed for every 8 bytes (along the bits of those 8 bytes in
// a square matrix) from the non _vertical version. See README.md for how
// this transposition was accomplished.

// When the inputs TOGGLE, it will then (with appropriate latency)
// output the next character and the pixels for the row for those
// characters.
//
// This is done because this may be called from a module which uses
// a divider of the input clock (here) such that it can't easily use
// a single-cycle ready signal or any other single-cycle live signal
// (as in an AXI stream, or an Altera FIFO read).

// TODO: Figure out how to parameterize a 2-port RAM to have different
// size according to TEXT_WIDTH & _HEIGHT.

// TODO: Add color to each text character

// For testing: Characters

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
// This doesn't work in Questa for some reason. vlog-2892 errors.
`default_nettype none // Disable implicit creation of undeclared nets
`endif


module text_pixel_generator_16x4_vertical #(
  // DO NOT CHANGE THESE
  parameter TEXT_WIDTH  = 16,
  parameter TEXT_HEIGHT = 4,
  parameter TEXT_LEN = TEXT_WIDTH * TEXT_HEIGHT,
  parameter TEXT_SZ = $clog2(TEXT_LEN)
) (
  input  logic clk,
  input  logic reset,

  // Inputs to the text pixel generator.
  // If these both toggle at the same time, only restart will be actioned.
  input  logic toggle_restart,
  input  logic toggle_next,

  // Outputs from the text pixel generator
  output logic [7:0] cur_char,   // One (extended) ASCII character
  output logic [7:0] cur_pixels, // One character's width of pixels

  // Memory write interface to text RAM
  input logic               clk_text_wr,
  input logic               text_wr_ena,
  input logic         [7:0] text_wr_data,
  input logic [TEXT_SZ-1:0] text_wr_addr
);

// The screen is this & each character is this big
localparam CHAR_WIDTH = 8;
localparam CHAR_WIDTH_SZ = $clog2(CHAR_WIDTH);
localparam CHAR_HEIGHT = 16;
localparam CHAR_HEIGHT_SZ = $clog2(CHAR_HEIGHT);

localparam TEXT_WIDTH_SZ = $clog2(TEXT_WIDTH);
localparam TEXT_HEIGHT_SZ = $clog2(TEXT_HEIGHT);


/////////////////////////////////////////////////////////////////////
// Text RAM
//
// Currently does not use a registered output

logic [TEXT_SZ-1:0] text_rd_address;
logic [7:0] char; // Character we will show
assign cur_char = char;

text_ram_16x4 text_ram_inst (
  // RAM has two clock domains
	.wrclock  (clk_text_wr),
	.data     (text_wr_data),
	.wraddress(text_wr_addr),
	.wren     (text_wr_ena),

	.rdclock  (clk),
	.rdaddress(text_rd_address),
	.q        (char)
);

/////////////////////////////////////////////////////////////////////
// Character ROM
//
// Output is not registered

// 4096 byte ROM = 16 height x 256 characters (x 8 width_bits)

localparam ROM_ADDR_SZ = 12;

logic [ROM_ADDR_SZ-1:0] rom_rd_addr;
logic [7:0] rom_data;
assign cur_pixels = rom_data;

character_rom_vertical	character_rom_inst (
	.clock  (clk),
	.address(rom_rd_addr),
	.q      (rom_data)
);

/////////////////////////////////////////////////////////////////////
// Character pixel generator state machine

// Count height pixel rows before moving to the next text memory row
localparam LAST_TEXT_COL = (TEXT_WIDTH_SZ)'(TEXT_WIDTH - 1);

localparam PIXEL_WIDTH = TEXT_WIDTH * CHAR_WIDTH;
localparam PIXEL_WIDTH_SZ = $clog2(PIXEL_WIDTH + 1);
localparam LAST_PIXEL_COL = (PIXEL_WIDTH_SZ)'(PIXEL_WIDTH - 1);

// Number of rows of 8 pixel columns we have to send
localparam PIXEL_ROWS = TEXT_HEIGHT * (CHAR_HEIGHT / 8);
localparam PIXEL_ROW_SZ = $clog2(PIXEL_ROWS + 1);
localparam LAST_PIXEL_ROW = (PIXEL_ROW_SZ)'(PIXEL_ROWS - 1);

// Registers
logic [CHAR_HEIGHT_SZ:0] pixel_row; // 0-15
logic [PIXEL_WIDTH_SZ:0] pixel_col; // 0-128 (16 * 8)
logic last_restart = '0;
logic last_next = '0;

// 0000
// 0001
// 0111
// 1000

// We always read the ROM address for the specific character
// (which has a number of ROM addresses) for the specific
// pixel row we're reading from now.
always_comb begin: calc_addrs
  rom_rd_addr = (ROM_ADDR_SZ)'((char * CHAR_HEIGHT) + pixel_col + (pixel_row & 4'b1000));
  text_rd_address = (TEXT_SZ)'((pixel_col / PIXEL_WIDTH) + ((pixel_row / 2) * TEXT_WIDTH));
end: calc_addrs


// Display order:
// Char 0 column 0
// Char 0 column 1
// Char 0 column 2
// Char 0 column 3
// Char 0 column 4
// Char 0 column 5
// Char 0 column 6
// Char 0 column 7
// <repeat Chars 1-15>
// New set of 8 rows
// Char 0 column 8
// Char 0 column 9
// Char 0 column 10
// Char 0 column 11
// Char 0 column 12
// Char 0 column 13
// Char 0 column 14
// Char 0 column 15
// <repeat Chars 1-15>
// New set of 8 rows
// Char 16 column 0 ...


always_ff @(posedge clk) begin: text_gen_main
  last_restart <= toggle_restart;
  last_next <= toggle_next;

  if (last_restart != toggle_restart || reset) begin: do_restart
    pixel_row <= '0;
    pixel_col <= '0;

  end: do_restart else if (last_next != toggle_next) begin: do_next

    if (pixel_col == LAST_PIXEL_COL) begin: next_pixel_row
      pixel_col <= '0;

      // Display the next 8 rows of pixels, including wrapping if necessary
      pixel_row <= pixel_row == LAST_PIXEL_ROW ? '0 : pixel_row + 1'd1;;

    end: next_pixel_row else begin
      pixel_col <= pixel_col + 1'd1;
    end

  end: do_next

end: text_gen_main


endmodule

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
`default_nettype wire // turn implicit nets on again to avoid side-effects
`endif
