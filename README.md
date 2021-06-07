## N64 Controller Interface

Firmware for an `attiny841` that adapts the custom onewire comunication protocol and tranlates it into an i2c slave.

It runs at 8MHz, and it is completely written in assembly, because it needs deterministic timing at 1MHz.
