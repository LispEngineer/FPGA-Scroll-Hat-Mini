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