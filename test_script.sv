// Copyright ⓒ 2023 Douglas P. Fields, Jr. symbolics@lisp.engineer
// Licensed under Solderpad Hardware License 2.1 - see LICENSE
//
// Adapted from my ADV7513 HDMI transmitter setup script.

`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
// This doesn't work in Questa for some reason. vlog-2892 errors.
`default_nettype none // Disable implicit creation of undeclared nets
`endif


// Unclocked ROM.
// Contains 7'address, 1'read-not-write, 8'data1, 8'data2
// TODO: Add expected result (abort/success)
// TODO: Add repeat
// TODO: For reads, add expected data read (past tense, "red")
module test_rom (
  input  logic [7:0]  address,
  output logic [23:0] data,
  output logic [7:0]  rom_length
);

assign rom_length = 8'd6;

// Test target address: 7'b101_0101
// So write is 1010_1010 0xAA
// Read is ... 1010_1011 0xAB

// If it is a READ, then the last bit is the "read two" parameter.

always_comb
  case (address)
    8'd0:  data = 24'hAA_01_00; // Send a write to an existing address
    8'd1:  data = 24'h2A_02_18; // Send a write to a non-existing address
    8'd2:  data = 24'hAB_03_00; // Send a read to an existing address for one byte
    8'd3:  data = 24'hAB_03_01; // Send a read to an existing address for two bytes
    8'd4:  data = 24'h2B_15_00; // Send a read to a non-existing address
    8'd5:  data = 24'hAA_16_61; // Send a write to an existing address
    default: data = 24'h0;
  endcase

endmodule // setup_rom


module test_script (
  input logic clk,
  input logic rst,
  
  // Interface with the I2C controller
  output logic       i2c_activate,
  input  logic       i2c_busy,
  // The results of the most recent request, when !busy
  input  logic       i2c_success,
  input  logic       i2c_abort,

  // Command the I2C to do something
  output logic [6:0] i2c_address,
  output logic       i2c_readnotwrite,
  output logic [7:0] i2c_byte1,
  output logic [7:0] i2c_byte2,
  output logic       i2c_read_two, // Read two bytes if true, otherwise just 1

  // If we read from the I2C, then...
  input  logic [7:0] i2c_read_byte1,
  input  logic [7:0] i2c_read_byte2,
  
  // Test status outputs
  output logic active,
  output logic done
);

// This is a state machine that runs once, after 200ms,
// setting up the ADV7513 per the ROM above.

localparam S_RESET    = 3'd0, // Reset all our setup params, goes to WAIT
           S_WAIT     = 3'd1, // Does nothing anymore, just advances
           S_SEND     = 3'd2, // Send a byte of the ROM to I2C controller, goes to BUSYWAIT or DONE
           S_BUSYWAIT = 3'd3, // Wait for the I2C controller to be done sending, always returns to SEND after incrementing the rom_step
           S_DONE     = 3'd4; // Finished all the sending; terminal state

logic [2:0]  setup_state = S_RESET; // BAD, but I always feel like I must do it.
logic [7:0]  rom_step;
logic [7:0]  rom_length;
logic [23:0] rom_comb; // Combinatoric output. I2C address (with read/write bit set to write), then two (write) data fields

logic busy_seen; // Have we seen the I2C controller go busy?

// The ROM is implemented combinatorically
test_rom test_rom(
  .address(rom_step),
  .data(rom_comb),
  .rom_length
);

always_ff @(posedge clk) begin

  if (rst) begin
    setup_state <= S_RESET;
    active <= 0;
    done <= 0;
    i2c_activate <= 0; // TODO: Add this to the adv7513_setup script
  
  end else case (setup_state)
  
    S_RESET: begin
      // Start our whole state machine over
      rom_step <= 0;
      setup_state <= S_WAIT;
      i2c_activate <= 0;
      busy_seen <= 0;
      active <= 1;
      done <= 0;
    end // S_RESET
    
    S_WAIT: begin
      // We don't do any waiting anymore, this is a vestige from
      // our ADV7513 days.
      setup_state <= S_BUSYWAIT; // Always check if I2C is busy before starting
      busy_seen <= 1; // But pretend it was already busy, else it will wait to see it busy first
      rom_step <= 0;
    end // S_WAIT
    
    S_SEND: begin
      // Send the next command from our ROM to the ADV7513 via I2C
      if (rom_step == rom_length)
        // We have run out of commands and are done with setup!
        setup_state <= S_DONE;
        
      else begin
        // Always reset for our next busy wait
        busy_seen <= 0;
        setup_state <= S_BUSYWAIT;
        
        // Activate our I2C controller (next cycle, of course)
        // and then wait for it to finish this command.
        i2c_activate <= 1;
        {i2c_address, i2c_readnotwrite, i2c_byte1, i2c_byte2} <= rom_comb;
        i2c_read_two <= rom_comb[0]; // Only matters if it's a read
        
      end // Not done
    end // S_SEND
    
    S_BUSYWAIT: begin
      // Wait until we see the I2C start and then stop being busy.
      // Remember that we are running at full clock speed
      // compared to the 128x slower 400 kHz I2C bus
      // (assuming we're running at 50MHz).
      
      if (!busy_seen) begin
        // Do nothing, wait to see I2C controller go busy
        if (i2c_busy) begin
          // Okay we saw the busy go on, we can deactivate
          busy_seen <= 1;
          i2c_activate <= 0;
          // And move on to the next step
          rom_step <= rom_step + 8'd1;
        end
        
      end else if (!i2c_busy) begin
        // We saw it go from busy to non-busy, so we're done waiting
        busy_seen <= 0;
        i2c_activate <= 0; // Just in case?
        // rom step was already advanced
        setup_state <= S_SEND;
      end
      
      // TODO: Make it so it stops busy waiting after a reasonable number of I2C cycles.
      // If we see that happen, go to reset state.
      // Log something in systemverilog so we know it happens in simulation.
      // For now, we have the "reset" button to get us out of this situation.
    end // S_BUSYWAIT
    
    S_DONE: begin
      // We're done. :)
      // Stay in this state forever... or until rst.
      active <= 0;
      done <= 1;
      i2c_activate <= 0; // Just in case
    end
    
    default: begin
      // This should never happen - log something in simulation
      $display("Default case in run_tests state - should never happen.");
      $stop;
      setup_state <= S_RESET;
    end // default
  
  endcase // setup_state

end // always_ff for state machine

endmodule // run_tests




`ifdef IS_QUARTUS // Defined in Assignments -> Settings -> ... -> Verilog HDL Input
// Restore the default_nettype to prevent side effects
// See: https://front-end-verification.blogspot.com/2010/10/implicit-net-declartions-in-verilog-and.html
// and: https://sutherland-hdl.com/papers/2006-SNUG-Boston_standard_gotchas_presentation.pdf
`default_nettype wire // turn implicit nets on again to avoid side-effects
`endif
