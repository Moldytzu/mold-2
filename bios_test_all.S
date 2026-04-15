	.feature STRING_ESCAPES
	.segment "CODE"

	VIA_BASE = $A000
	VIA_DDRA = VIA_BASE + 3
	VIA_DDRB = VIA_BASE + 2
	VIA_ORA = VIA_BASE + 1
	VIA_ORB = VIA_BASE + 0
	VIA_T1CL = VIA_BASE + 4
	VIA_T1CH = VIA_BASE + 5
	VIA_PCR = VIA_BASE + 12
	VIA_ACL = VIA_BASE + $B
	VIA_IER = VIA_BASE + $E
	VIA_IFR = VIA_BASE + $D

	ACIA_BASE   = $9000
	ACIA_DATA   = ACIA_BASE + 0
	ACIA_STATUS = ACIA_BASE + 1
	ACIA_CMD    = ACIA_BASE + 2
	ACIA_CTRL   = ACIA_BASE + 3


acia_wait_tx:
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	php
	plp
	rts

acia_init:
	lda #%00010000 ; 115200 baud 8N1
	sta ACIA_CTRL

	lda #%00001011 ; no parity, no IRQs, transmitter enabled
	sta ACIA_CMD
	rts

via_init:
	lda #$FF
	sta VIA_DDRA
	sta VIA_DDRB

	lda #$00
	sta VIA_ORA
	sta VIA_ORB
	rts

_reset:
_irq:
	cld
	sei

	jsr acia_init
	jsr via_init

	lda #$55
	sta ACIA_DATA
	sta VIA_ORA
	sta VIA_ORB

loop:
	clc
	adc #1
	pha
	pha
	pla
	sta VIA_ORA
	sta VIA_ORB

	jsr acia_wait_tx
	sta ACIA_DATA
	pla

	jmp loop
	

	.segment "RESET_VECTOR"
	.word _irq
	.word _reset
	.word _irq