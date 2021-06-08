
#include <avr/io.h>

// Program entrypoint
.global main
main:         // Configure oscillator at 8 MHz
              cli
              ldi   r17,                          0xD8
              sts   CCP,                          r17
              ldi   r17,                          0x01
              sts   CLKPR,                        r17

              // Configure timer to approximately 1 ms scans
              // The timer will trigger the N64 controller readout
              // 1. Reset timer to 0
              // 2. Set CTC mode
              // 3. Set prescaler to 256
              // 4. Set output compare register to 255
              // 5. Interrupt on match (overflow)
              ldi   r17,                          0x00
              out   _SFR_IO_ADDR(TCNT0),          r17
              ldi   r17,                          _BV(WGM01)
              out   _SFR_IO_ADDR(TCCR0A),         r17
              ldi   r17,                          _BV(CS02)
              out   _SFR_IO_ADDR(TCCR0B),         r17
              ldi   r17,                          0xFF
              out   _SFR_IO_ADDR(OCR0A),          r17
              ldi   r17,                          _BV(OCIE0A)
              out   _SFR_IO_ADDR(TIMSK0),         r17

              // Configure I2C Slave with slave address = 0x54
              // We get interrupts on DATA and ADDR match
              ldi   r17,                          0x54
              sts   TWSA,                         r17

              ldi   r17,                          _BV(TWEN)
              ori   r17,                          _BV(TWASIE)
              ori   r17,                          _BV(TWDIE)
              sts   TWSCRA,                       r17

              // Configure ports and enable interrupts when done
              // r16 and r17 are reserved during the operation of the program
              // They should not be modified by any other code
              // r16 contains the port configuration as output, r17 is used
              // for input
              ldi   r16,                          0x0C
              ldi   r17,                          0x08
              out   _SFR_IO_ADDR(DDRA),           r16
              out   _SFR_IO_ADDR(PORTA),          r16
              ldi   r18,                          _BV(PB2)
              out   _SFR_IO_ADDR(DDRB),           r18
              sei

// All processing is done in the interrupt service routine,
// so this loop is a busy wait.
// This is because the timing requirements for the
MainLoop:         rjmp  MainLoop

// This is a routine that checks if the N64 controller is present.
IsN64Present: ldi    r26,                         0x00 // X indirect addressing
              ldi    r27,                         0x01
              ldi    r20,                         0x18 //24 bits to read
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  One
              // Set Port A as inputs, and start reading
              out    _SFR_IO_ADDR(DDRA),           r17

readP:        // 15 Cycle delay
              ldi   r18,                           0x05
readPDelay1:  dec   r18
              brne  readPDelay1
              // Read Value and store on X reg
              in    r19,                           _SFR_IO_ADDR(PINA)
              st    X+,                            r19
              // 11 cycle delay
              ldi   r18,                           0x03
readPDelay2:  dec   r18
              brne  readPDelay2
              nop
              nop
              dec   r20
              brne  readP
              // Exiting read
              // 24 cycle delay
              ldi   r18,                           0x08
readPDelay3:  dec   r18
              brne  readPDelay3
              // Port as output again
              out    _SFR_IO_ADDR(DDRA),           r16
              //return
              ret

// Reads 32 bits from the N64 controller
readN64:      ldi    r26,                         0x18
              ldi    r27,                         0x01
              ldi    r20,                         0x20 //32 bits to read
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  Zero
              rcall  One
              nop
              nop
              nop
              nop
              rcall  One
              // Set Port A as inputs, and start reading
              out    _SFR_IO_ADDR(DDRA),           r17

// The actual read of the 32 bytes. Here timing is also critical, shift the clock phase so that we
// read while the signal is stable
read:         // 15 Cycle delay
              ldi   r18,                           0x05
readDelay1:   dec   r18
              brne  readDelay1
              // Read Value and store on X reg
              in    r19,                           _SFR_IO_ADDR(PINA)
              st    X+,                            r19
              // 11 cycle delay
              ldi   r18,                           0x03
readDelay2:   dec   r18
              brne  readDelay2
              nop
              nop
              dec   r20
              brne  read
              // Exiting read
              // 24 cycle delay
              ldi   r18,                           0x08
readDelay3:   dec   r18
              brne  readDelay3
              // Set the pin as output again
              out    _SFR_IO_ADDR(DDRA),           r16
              ret

// Sends a zero through the onewire interface. Timing is carefully calculated to take 1us
Zero:         // OFF
              in    r18,                            _SFR_IO_ADDR(PINA)
              andi  r18,                            0xFB
              out   _SFR_IO_ADDR(PORTA),           r18
              // 19 Cycles Delay
              ldi   r18,                           0x06
ZeroWait:     dec   r18
              brne  ZeroWait
              nop
              in    r18,                            _SFR_IO_ADDR(PINA)
              ori   r18,                            0x04
              out   _SFR_IO_ADDR(PORTA),           r18
              ret

// Sends a one through the onewire interface. Timing is carefully calculated to take 1us
One:          // OFF
              in    r18,                            _SFR_IO_ADDR(PINA)
              andi  r18,                            0xFB
              out   _SFR_IO_ADDR(PORTA),           r18
              // 3-cycle delay
              nop
              nop
              nop
              // ON
              in    r18,                            _SFR_IO_ADDR(PINA)
              ori   r18,                            0x04
              out   _SFR_IO_ADDR(PORTA),           r18
              // 12-cycle delay
              ldi   r18,                           0x03
OneWait:      dec   r18
              breq  ExitOne
              rjmp  OneWait
ExitOne:      ret



// Interrupts

// Timer ISR. Checks if the controller is connected and then
// triggers a read if it is.
.global TIMER0_COMPA_vect

TIMER0_COMPA_vect:  in  r31,  _SFR_IO_ADDR(SREG)
                    cli

                    rcall IsN64Present

                    lds r18,                  0x0107
                    andi r18,                 0x04
                    breq N64NotPresent
                    lds r18,                  0x0105
                    andi r18,                 0x04
                    breq N64NotPresent

                    rjmp  N64Present

ExitTimerISR:       out _SFR_IO_ADDR(SREG), r31
                    reti

N64Present:         ldi   r18,                0xFF
// Wait for a bit before triggering the read, otherwise the controller doesn't
// respond.
WaitBeforeRead:     dec   r18
                    brne  WaitBeforeRead

                    ldi r18,                  0x0C
                    out _SFR_IO_ADDR(PORTA),  r18

                    rcall readN64

                    lds r18,                  0x0118
                    out _SFR_IO_ADDR(PORTB),  r18

                    rjmp ExitTimerISR

// If it is not present, we can leave the interrupt
N64NotPresent:      ldi r18,                  0x04
                    out _SFR_IO_ADDR(PORTA),  r18

                    rjmp ExitTimerISR

// I2C ISR vector
.global TWI_SLAVE_vect

TWI_SLAVE_vect:     in  r31,  _SFR_IO_ADDR(SREG)
                    cli

                    lds  r18,                  TWSSRA
                    andi r18,                 _BV(TWDIF)
                    cpi  r18,                 _BV(TWDIF)
                    breq  TWI_SLAVE_data

                    lds  r18,                  TWSSRA
                    andi r18,                 _BV(TWASIF)
                    cpi r18,                  _BV(TWASIF)
                    breq  TWI_SLAVE_addr

                    out _SFR_IO_ADDR(SREG), r31
                    reti


// Handles an I2C data IRQ and prepares the I2C peripheral to send the next I2C
// register
TWI_SLAVE_data: ld  r18,                  Y+
                sts TWSD,                 r18

                ldi r18,      _BV(TWDIF) // Clear Flag
                sts TWSSRA, r18

                out _SFR_IO_ADDR(SREG), r31
                reti

// Handles an I2C address IRQ and sets the
// register
TWI_SLAVE_addr: ldi r28, 0x18
                ldi r29, 0x01 ; Set reg Y to 0x0118

                ldi r18,      _BV(TWASIF) // Clear Flag
                sts TWSSRA, r18

                out _SFR_IO_ADDR(SREG), r31
                reti
