# Pimoroni Scroll Hat Mini for FPGA

Copyright ⓒ 2023 Douglas P. Fields, Jr. All Rights Reserved.


# FPGA Connections

Use 3.3V GPIO (pins 29-30) per IS31FL3731

* Buttons: GPIO 28, 30, 32, 34 (odd pins 33-39)
* I2C SDA: GPIO 33 (pin 38)
* I2C SCL: GPIO 35 (pin 40)
  * This must be open collector, pull up resistor (typically 4.7Ω)

# PiMoroni Scroll Hat Mini

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



# Others

* [Pinout for Unicorn HAT Mini](https://pinout.xyz/pinout/unicorn_hat_mini#)
  * ABXY on GPIO 5,6,16,20 or pin 29, 31, 36, 38 






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

## Set the enabled LEDs

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


## To write frame data

1. Set the bank:
  * Write to 0xFD the bank you want 0-7
2. Set the enable pattern above starting at 0
3. Write data starting at COLOR_OFFSET for brightness
4. Show the specified frame
   * Switch to config bank
   * Write frame # to FRAME_REGISTER (1)

# Turn all of them on

1. Write 0 into FD
2. Send seventeen 0111_1111 and one 0000_0000 to addresses 0-11
3. Send 255 in to addresses 24-B3