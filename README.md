## N64 Controller Interface

Firmware for an `attiny841` that adapts the custom onewire comunication protocol and tranlates it into an i2c slave.

It runs at 8MHz, and it is completely written in assembly, because it needs deterministic timing at 1MHz.

I2C slave address is `0x54` and the data is stored in I2C registers in the following order:

```
Address 0 -> A
Address 1 -> B
Address 2 -> Z
Address 3 -> Start
Address 4 -> Up
Address 5 -> Down
Address 6 -> Left
Address 7 -> Right
Address 8 -> /
Address 9 -> /
Address 10 -> L
Address 11 -> R
Address 12 -> C-Up
Address 13 -> C-Down
Address 14 -> C-Left
Address 15 -> C-Right
Address 16-23 -> X-Axis
Address 24-31 -> Y-Axis
Address 32 -> Stop bit (1)
```

Pinout:
```
PA2 -> N64 controller data
PA3 -> Status output. High when controller is connected. Low otherwise.
PA6 -> SDA
PA4 -> SCL
PB2 -> Status of the A button. High when pressed.
```
