## N64 Controller Interface

The attiny841 serves as a serial interface to the N64 controller, replacing it's native onewire custom comunication protocol.

It runs at 8MHz, and it is completely written in assembly, as it needs to speed up GPIO operations.
