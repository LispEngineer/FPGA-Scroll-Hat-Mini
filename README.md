# Doug's I²C FPGA Components

Copyright ⓒ 2023 [Douglas P. Fields, Jr.](mailto:symbolics@lisp.engineer)

Licensed under Solderpad Hardware License 2.1 - see LICENSE

## TODO

* Enhance `I2C_CONTROLLER` to be able to send a single byte.
* Enhance `I2C_CONTROLLER` to handle any parameterized size of input instead of
  a single location & data (and repeat).



-------------------------------------------------------------------------------

# Pimoroni Scroll Hat Mini for FPGA


## FPGA Connections

Use 3.3V GPIO (pins 29-30) per IS31FL3731
* Tested with both 5V and 3.3V feeds from GPIO and both work
  (5V may be brighter)

GPIO connections:
* Buttons: GPIO 28, 30, 32, 34 (odd pins 33-39)
* I2C SDA: GPIO 33 (pin 38)
* I2C SCL: GPIO 35 (pin 40)
  * This must be open collector, pull up resistor (typically 4.7Ω)

## Order of the LEDs on the display vs. in memory

There are 7 rows of 17 LEDs = 119 LEDs.

There are 144 memory areas, two matrixes of 8 x 9

* First 7: bottom of middle column to top
* 8th: unused? (or is it the 0th unused?)
* Second 7: top to bottom of column to the right of middle
* unused
* Third 7: bottom to top of column to the left of middle
* unused
* .. and so forth ..

           00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 - columns
          ┌--------------------------------------------------
        0 |86 76 66 56 46 36 26 16 06 08 18 28 38 48 58 68 78
        1 |                     15 05 09
        2 |                     14 04 0A
        3 |                     13 03 0B
        4 |                     12 02 0C
        5 |                     11 01 0D
        6 |80 70 60 50 40 30 20 10 00 0E 1E 2E 3E 4E 5E 6E 7E


## TODO

* Try using built-in weak pull-up to make I2C bus work instead of external pullups
  * [StackOverflow Question](https://electronics.stackexchange.com/questions/248248/altera-fpga-i-o-weak-pull-ups) on this matter
* Make a 17x7 (119 bit) register that is used to refresh the screen 50-100x a second
  * Try to write 255s to all the PWM registers and just changing the enables?
* Enhance I2C controller to send multiple different bytes simultaneously
  * Maybe 4 or 8?
* Make a 17x7 (119 byte) RAM and use that to refresh the screen 50-100x a second
  * Read the RAM in large chunks like 4-8 bytes to do fewer transactions on I2C
    (reduced overhead, faster refresh rate)


## PiMoroni Scroll Hat Mini Reverse Engineering

* [Product page](https://shop.pimoroni.com/products/scroll-hat-mini)
* [Driver chip](https://cdn.shopify.com/s/files/1/0174/1800/files/31FL3731_f2c53799-e354-4fe7-8111-71cfdacf2712.pdf?27380) - ISSI IS31FL3731
  * 400 kHz I2C
  * I2C Address: 0x74
* [Python Library](https://github.com/pimoroni/scroll-phat-hd)
* [Pinout](https://pinout.xyz/pinout/scroll_phat_hd#)

This appears to need reverse engineering. It has no pinout.

Pinout:
* RPi GPIO2 (Pin 3) - I2C1 SDA
* RPi GPIO3 (Pin 5) - I2C1 SCL
* 5v Power (Pins 2, 4) - Both connected on ScrollHatMini
* Ground (pins 6, 14, 20, 30, 34, 9, 25, 39) - All cross connected on the ScrollHatMini
* Buttons - not shown in pinout above, from [GitHub](https://github.com/pimoroni/scroll-phat-hd/search?q=button)
  * ABXY = 5, 6, 16, 24 GPIO? PIN #? I am guessing GPIO #
  * = PIN 29, 31, 36, 18
  * They are floating when unpressed, and pulled to ground when pressed

### Other References

* [Pinout for Unicorn HAT Mini](https://pinout.xyz/pinout/unicorn_hat_mini#)
  * ABXY on GPIO 5,6,16,20 or pin 29, 31, 36, 38 

* [Pico Scroll Pack](https://shop.pimoroni.com/en-us/products/pico-scroll-pack)
  may use the same interface with different pinouts


## How to use it?

From: https://github.com/pimoroni/scroll-phat-hd/blob/master/library/scrollphathd/is31fl3731.py

These are the addresses for the Function Register (Page 9):
* _MODE_REGISTER = 0x00
* _FRAME_REGISTER = 0x01
* _AUTOPLAY1_REGISTER = 0x02
* _AUTOPLAY2_REGISTER = 0x03
* _BLINK_REGISTER = 0x05
* _AUDIOSYNC_REGISTER = 0x06
* _BREATH1_REGISTER = 0x08
* _BREATH2_REGISTER = 0x09
* _SHUTDOWN_REGISTER = 0x0a
* _GAIN_REGISTER = 0x0b
* _ADC_REGISTER = 0x0c

First write to the 0xFD "Command Register" which bank you want:
* 0-8 = Eight LED frames
* _CONFIG_BANK = 0x0b (0000_1011)
* _BANK_ADDRESS = 0xfd

Values for the mode register:
* _PICTURE_MODE = 0x00
* _AUTOPLAY_MODE = 0x08
* _AUDIOPLAY_MODE = 0x18

For the Frame 1-8 registers, these are the offsets:
* _ENABLE_OFFSET = 0x00
* _BLINK_OFFSET = 0x12
* _COLOR_OFFSET = 0x24

_NUM_PIXELS = 144
_NUM_FRAMES = 8

### Set the enabled LEDs

    enable_pattern = [
        # Matrix A   Matrix B
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b01111111,
        0b01111111, 0b00000000,
    ]

### To write frame data

1. Take it out of shutdown mode:
  * Set bank to function register: write 8'b0000_1011 to 8'hFD
  * Write 8'h01 to 8'h0A
1. Set the frame bank:
  * Write to 0xFD the bank you want, 0-7
2. Set the enable pattern above starting at address 0
  * Send seventeen 0111_1111 and one 0000_0000 to addresses 0-11
3. Write data starting at COLOR_OFFSET for brightness
  * See [example gamma curve](https://github.com/pimoroni/scroll-phat-hd/blob/master/library/scrollphathd/__init__.py#L20)
    or the Gamma curves in the data sheet
  * 255 is super bright
4. Show the specified frame
   * Switch to config bank
   * Write frame # to FRAME_REGISTER (1)

### Turn all of them on

1. Write 0 into FD
2. Send seventeen 0111_1111 and one 0000_0000 to addresses 0-11
3. Send 255 in to addresses 24-B3

-------------------------------------------------------------------------------

# Keyestudio I2C 8x8 LED Matrix

References:
* [Product page](https://wiki.keyestudio.com/Ks0064_keyestudio_I2C_8x8_LED_Matrix_HT16K33)
* Chip: Vinka VK16K33 (Datasheet in [`datasheets/`](datasheets/) directory.
* I²C address: 0x70
* Python code on [GitHub](https://github.com/smittytone/HT16K33-Python)

## Initialization & drawing

Per the [code here](https://github.com/smittytone/HT16K33-Python/blob/main/ht16k33.py#L91),
it's just a matter of:
* HT16K33_GENERIC_SYSTEM_ON 0x21
* HT16K33_GENERIC_DISPLAY_ON 0x81 (no blinking, display on)
  * Contents of display will be random

For Drawing it's:
* Write 0x00 (HT16K33_GENERIC_DISPLAY_ADDRESS) and also
  * Write all the RAM locations in one I²C transaction

See the VK16K33 Datasheet, Rev 1.0 2017-06-27 page 26 for initialization & drawing
flow chart.


## Display mapping

Reverse engineer it with I2CDriver.

Send 00 and then these hex codes:

```
80 = top col 1 (leftmost)
40 = top col 8 (rightmost)
20 = top col 7
10 = top col 6
08 = top col 5
04 = top col 4
02 = top col 3
01 = top col 2

00 FF = nothing

00 00 FF = second row, same as above

00 00 00 FF = nothing

00 00 00 00 FF = third row
```

Or alternately, send `8'b0000_####` with the address of the byte you want to write next.

For dimming, write E0 to EF.

For blinking, write `8'b1000_xBB1` with 00 off, to 11 the slowest blinking