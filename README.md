# Doug's I²C FPGA Components

Copyright ⓒ 2023 [Douglas P. Fields, Jr.](mailto:symbolics@lisp.engineer)

Licensed under Solderpad Hardware License 2.1 - see LICENSE

## Inventory

* I2C Controller v1 & v2
  * v2 sends a configurable amount of data before receiving a configurable number
    of bytes and except for repeating a single value over and over, is
    more flexible in every way than v1
* Pimoroni Scroll Hat Mini - using v1
* Keyestudio 8x8 LED matrix - using v1
  * Similar to others like [Adafruit's](https://www.adafruit.com/product/872)


### Next Up

* [ALMOCN 0.96" SSD1306 Yellow/Blue I²C OLED](https://www.amazon.com/gp/product/B08J25QLK7/)
  * 128x64 OLED display with top 16 pixels yellow, then remaining cyan
  * Working initialization sequence below

* [Hiletgo SSH1106/SSD1306](https://www.amazon.com/gp/product/B01MRR4LVE/)
  * 128x64 OLED = 16 x 4 characters if using 8x16 characters
  * See my original I²C Controller code for a really bad driver for this display
    (`sh1106_draw.sv`)


## TODO

* [DONE] Enhance `I2C_CONTROLLER` to handle any parameterized size of send data instead of
  a single location & data (and repeat).
* Convert SHM & Keyestudio controllers to use I²C Controller v2
* Enhance text pixel generator to send characters 8 vertical pixels at a time
  instead of 8 horizontal pixels at a time.
  * This will require a new font that gives the font data 8 vertical pixels per byte
    rather than 8 horizontal pixels per byte.
  * Need to write a little program to "rotate" every 8 bytes in the ROM file.



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

Note: This works fine with 3.3V Vcc.

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

-------------------------------------------------------------------------------

# SSH1106 OLED display

* Address: 3C in I2CDriver
* Voltage: 3.3V
* Speed: 400 kHz

This will require a significant change for the text character generator
because instead of providing 8 horizontal pixels at a time, it will need
to provide a column of 8 vertical pixels at a time.

## Datasheet notes

* Page 13: Two 7-bit slave addresses: 011_1100, 011_1101 (3C, 3D) are used.
* After slave address, one or more command words
  * Command word = control byte (Co and DnotC) plus a data byte
  * Last control byte is tagged with a cleared MSB, continuation bit "Co".
  * After a control byte with cleared Co bit, only data bytes will follow.
  * DnotC defines if data byte is a command or RAM data
* Example from p14:
  * Write: 7 bit address, 0 bit for WRITE
  * Continuation example:
    * 1 bit Co = 1
    * 1 bit DnotC: 0 = data byte for command; 1 = data byte for RAM
    * 6 bits control "byte"
    * (ack)
    * 8 bits data byte
  * No continuation example:
    * 1 bit Co = 0
    * 1 bit DnotC
    * 6 bits control "byte"
    * (ack)
    * 0 or more 8-bit data bytes until Stop
* Not really sure how SA0 and A0 work for various data commands


## Initialization

Wait 100ms after Vcc is powered up before turning on display.
(See OLED module section 4.2.1)

* Turn on: 80 AF
  * Turn off again: 80 AE

Optional:
* Reverse drawing (normally bottom right to bottom left): 80 A1
  * This makes it draw from left to right
* Reverse display colors: 80 A7
  * Back to normal: 80 A6
* Flip display top to bottom: 80 C8

## Drawing

* 80 B0 - page address 0 up through 80 B7
* 80 00 - column address 0 (lower part)
* 80 10 - column address 0 (upper part)
* 40 00 00 00 00 00 00 00 00 (8x 00) - draws the bottom left square of the screen
  (40 FF FF FF FF FF FF FF FF for white)
  * First two bytes are NOT displayed on the screen (either in normal or reverse mode)
  * MSB in each byte is the bottom most dot
* Send that over and over to continue drawing leftward

When reverse drawing and flip display are on (80 A1, 80 C8):
* First two bytes are skipped in each row (still)
* 80 is a 8-pixel column with MSB at the bottom and LSB at the top

Better to send this:
* 80 B0 80 02 80 10 - set first page, first VISIBLE column
* 128 bytes (40 then any number of bytes until 128 sent)
  * These are a single column of 8 pixels each byte
  * MSB is at the bottom of the column

------------------------------------------------------------------------

# MakerFocus I2C OLED Display 0.91-inch

* [Amazon](https://www.amazon.com/gp/product/B079BN2J8V/) - do not buy!
* Resolution: 128x32
* Driver: SSD1306

I could not get these to work with the I2CDriver after soldering on headers.

------------------------------------------------------------------------

# ALMOCN OLED Module

* [Amazon](https://www.amazon.com/gp/product/B08J25QLK7/)
* Resolution: 128x64
* Driver: SSD1306

References:
* [Initialization Sequence](https://github.com/adafruit/Adafruit_SSD1306/blob/master/Adafruit_SSD1306.cpp#LL564C19-L564C19)
* [Another initialization sequence](https://embetronicx.com/tutorials/linux/device-drivers/ssd1306-i2c-linux-device-driver-using-raspberry-pi/)
  * Running this initialization routine turned on the display!

## Initialization

Commands start with `00` and data starts with `40`. Each command seems to be 1-byte.

This display wraps around - you can keep writing data and it will fill the whole screen.

Each data byte is 8 vertical pixels, MSB on the bottom.

The top 16 pixels are yellow, then a small horizontal gap about 1-2 pixels high, 
then the bottom 48 pixels are blue.

See Datasheet Rev 0.4 Jan 2009 Solomon Systech SSD1306 App Note, section 3
page 64 for initialization sequence.

Here's one that works:
```
  /*
  ** Commands to initialize the SSD_1306 OLED Display
  */
  SSD1306_Write(true, 0xAE); // Entire Display OFF
  SSD1306_Write(true, 0xD5); // Set Display Clock Divide Ratio and Oscillator Frequency
  SSD1306_Write(true, 0x80); // Default Setting for Display Clock Divide Ratio and Oscillator Frequency that is recommended
  SSD1306_Write(true, 0xA8); // Set Multiplex Ratio
  SSD1306_Write(true, 0x3F); // 64 COM lines
  SSD1306_Write(true, 0xD3); // Set display offset
  SSD1306_Write(true, 0x00); // 0 offset
  SSD1306_Write(true, 0x40); // Set first line as the start line of the display
  SSD1306_Write(true, 0x8D); // Charge pump
  SSD1306_Write(true, 0x14); // Enable charge dump during display on
  SSD1306_Write(true, 0x20); // Set memory addressing mode
  SSD1306_Write(true, 0x00); // Horizontal addressing mode
  SSD1306_Write(true, 0xA1); // Set segment remap with column address 127 mapped to segment 0
  SSD1306_Write(true, 0xC8); // Set com output scan direction, scan from com63 to com 0
  SSD1306_Write(true, 0xDA); // Set com pins hardware configuration
  SSD1306_Write(true, 0x12); // Alternative com pin configuration, disable com left/right remap
  SSD1306_Write(true, 0x81); // Set contrast control
  SSD1306_Write(true, 0x80); // Set Contrast to 128
  SSD1306_Write(true, 0xD9); // Set pre-charge period
  SSD1306_Write(true, 0xF1); // Phase 1 period of 15 DCLK, Phase 2 period of 1 DCLK
  SSD1306_Write(true, 0xDB); // Set Vcomh deselect level
  SSD1306_Write(true, 0x20); // Vcomh deselect level ~ 0.77 Vcc
  SSD1306_Write(true, 0xA4); // Entire display ON, resume to RAM content display
  SSD1306_Write(true, 0xA6); // Set Display in Normal Mode, 1 = ON, 0 = OFF
  SSD1306_Write(true, 0x2E); // Deactivate scroll
  SSD1306_Write(true, 0xAF); // Display ON in normal mode
```  

I2C Driver script:
```
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
```

To write data:
* Go to home position: 
  * 00 21 00 7F - column start and end
  * 00 22 00 07 - page start and end


Fill screen with cross-hatch:
```
.\i2ccl COM4 w 0x3C 0x00,0x21,0x00,0x7F p
.\i2ccl COM4 w 0x3C 0x00,0x22,0x00,0x07 p
.\i2ccl COM4 w 0x3C 0x40,0x55,0xAA p
... 128 * 8 / 2 times
```

To return to the beginning of the current page:
```
.\i2ccl COM4 w 0x3C 0x00,0x00 p
.\i2ccl COM4 w 0x3C 0x00,0x10 p
or simply just
.\i2ccl COM4 w 0x3C 0x00,0x00,0x10 p
```

To go to the first page: (same column)
```
.\i2ccl COM4 w 0x3C 0x00,0xB0 p
```

To return to the top corner:
```
.\i2ccl COM4 w 0x3C 0x00,0xB0,0x00,0x10 p
```

------------------------------------------------------------------------------

# Converting font

To use the `isoFont.mif` font for a display that draws 8 vertical pixels at a
time requires us to have a font with data in that order.

So, take the 8x16 (w x h) font, and transpose the bits of every block of 8 bytes.

```
ABCDEFGH     A1234567
11111111     B1234567
22222222     C1234567
33333333 --> D1234567
44444444     E1234567
55555555     F1234567
66666666     G1234567
77777777     H1234567
```

To get the raw font data:

```
egrep '^ ?[0-9]+: *[0-9a-fA-F]+;' isoFont.mif | cut -d: -f2 | cut -d\; -f1 >clj/font.raw
```

To transpose: see the clojure program in `clj` directory

To get the data entries for the MIF file back:

```
nl --starting-line-number=0 --number-separator=": " font-transposed.raw >../isoFont-transposed.mif
```

And then edit in the top and bottom lines