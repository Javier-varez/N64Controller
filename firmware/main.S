
#include <avr/io.h>

.global main

main:         // Configure oscillator
              // CLKPR = 1
              cli
              ldi   r17,                          0xD8
              ldi   r16,                          0x01
              sts   CCP,                          r17
              sts   CLKPR,                        r16

              // Configure timer
              ldi   r17,                          0x00
              out   _SFR_IO_ADDR(TCNT0),          r17
              ldi   r17,                          _BV(COM0A0)
              ori   r17,                          _BV(WGM01)
              out   _SFR_IO_ADDR(TCCR0A),         r17
              ldi   r17,                          _BV(CS02) //Prescaler at 256
              out   _SFR_IO_ADDR(TCCR0B),         r17
              ldi   r17,                          0xFF
              out   _SFR_IO_ADDR(OCR0A),          r17
              ldi   r17,                          _BV(OCIE0A)
              out   _SFR_IO_ADDR(TIMSK0),          r17

              // Configure I2C Slave
              ldi   r17,                          0x54  // Dev addr = 0x54
              sts   TWSA,                         r17

              ldi   r17,                          _BV(TWEN) // Enable I2C
              ori   r17,                          _BV(TWASIE) // ADDR interrupt enable
              ori   r17,                          _BV(TWDIE) // Data interrupt enable
              sts   TWSCRA,                       r17



              // Configure ports
              ldi   r16,                          0x04
              ldi   r17,                          0x00
              out   _SFR_IO_ADDR(DDRA),           r16
              out   _SFR_IO_ADDR(PORTA),          r16
              ldi   r18,                          _BV(PB2)
              out   _SFR_IO_ADDR(DDRB),           r18
              sei // enable interrupts

loop:         rjmp  loop


readN64:      ldi    r26,                         0x00
              ldi    r27,                         0x01
              ldi    r20,                         0x20 //32 bits to read
              rcall  zero
              rcall  zero
              rcall  zero
              rcall  zero
              rcall  zero
              rcall  zero
              rcall  zero
              rcall  one
              nop
              nop
              nop
              nop
              rcall  one
              // Set Port A as inputs, and start reading
              out    _SFR_IO_ADDR(DDRA),           r17

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
              // Port as output again
              out    _SFR_IO_ADDR(DDRA),           r16
              //return
              ret






zero:         // OFF
              out   _SFR_IO_ADDR(PORTA),           r17
              // 23 Cycles Delay
              ldi   r18,                           0x07
zeroloop:     dec   r18
              brne  zeroloop
              rjmp  zeroON // 2 cycle nop, 16 bit instruction as well
              // ON
zeroON:       out   _SFR_IO_ADDR(PORTA),           r16
              ret




one:          // OFF
              out   _SFR_IO_ADDR(PORTA),           r17
              // 7 cycles delay
              ldi   r18,                           0x02
sevCycLoop:   dec   r18
              brne  sevCycLoop
              nop
              // ON
oneON:        out   _SFR_IO_ADDR(PORTA),           r16
              // 12 cycle delay
              ldi   r18,                           0x03
oneloop:      dec   r18
              breq  oneexit
              rjmp  oneloop
oneexit:      ret



// Interrupts


.global TIMER0_COMPA_vect

TIMER0_COMPA_vect:  in  r31,  _SFR_IO_ADDR(SREG)
                    cli

                    rcall readN64

                    lds r18,                  0x0100
                    out _SFR_IO_ADDR(PORTB),  r18


                    out _SFR_IO_ADDR(SREG), r31
                    reti


.global TWI_SLAVE_vect

TWI_SLAVE_vect:     in  r31,  _SFR_IO_ADDR(SREG)
                    cli

                    lds  r18,                  TWSSRA
                    andi r18,                 _BV(TWDIF)
                    cpi r18,                  _BV(TWDIF)
                    breq  TWI_SLAVE_data

                    lds  r18,                  TWSSRA
                    andi r18,                 _BV(TWASIF)
                    cpi r18,                  _BV(TWASIF)
                    breq  TWI_SLAVE_addr

                    out _SFR_IO_ADDR(SREG), r31
                    reti


TWI_SLAVE_data: ld  r18,                  X+//0x0100
                sts TWSD,                 r18

                ldi r18,      _BV(TWDIF) // Clear Flag
                sts TWSSRA, r18

                out _SFR_IO_ADDR(SREG), r31
                reti




TWI_SLAVE_addr: ldi r26, 0x00
                ldi r27, 0x01 ; Set reg X to 0x0100

                ldi r18,      _BV(TWASIF) // Clear Flag
                sts TWSSRA, r18

                out _SFR_IO_ADDR(SREG), r31
                reti
