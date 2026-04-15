	.feature STRING_ESCAPES
	.feature leading_dot_in_identifiers 

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

reset: 
	jmp main_loop

acia_init:
	stz ACIA_STATUS ; clear any pending status flags

	lda #%00010000 ; 115200 baud 8N1
	sta ACIA_CTRL

	lda #%00000111 ; no parity, no IRQs, transmitter enabled
	sta ACIA_CMD

	jsr acia_clear_screen

	ldx #0
@loop:
	lda acia_init_message, x
	beq @done
	jsr acia_send_byte
	inx
	jmp @loop
@done:

	rts

acia_clear_screen:
	; send ESC[2J to clear screen
	lda #$1B ; ESC
	jsr acia_send_byte
	lda #'['
	jsr acia_send_byte
	lda #'2'
	jsr acia_send_byte
	lda #'J'
	jsr acia_send_byte
	rts

acia_wait_tx:
	pha
@spin:
	lda ACIA_STATUS
	and #%00010000
	beq @spin
	pla
	rts

acia_wait_rx:
	pha
@spin:
	lda ACIA_STATUS
	and #%00001000
	beq @spin
	pla
	rts

acia_send_byte:
	jsr acia_wait_tx
	cmp #'\n'
	beq @newline
	sta ACIA_DATA
	rts
	
@newline:
	sta ACIA_DATA
	jsr acia_wait_tx
	lda #'\r'
	sta ACIA_DATA
	lda #'\n'
	rts

acia_read_byte:
	jsr acia_wait_rx
	lda ACIA_DATA
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
	ldx #$FF   
    txs        

	jsr acia_init
	jsr via_init

	; print boot message
	ldx #0
@loop:
	lda boot_message, x
	beq @done
	jsr acia_send_byte
	inx
	jmp @loop
@done:

INPUT_BUFFER = $0200 ; spans from $200 to $2FF
ADDRESS = $F0 ; 2 bytes for address field in commands
ADDRESS2 = $F2
DATA = $F4 ; 1 byte for data field in write command
TEMP = $F5 ; 2 byte temporary variable for calculations
INPUT_LENGTH = $F7 ; 1 byte to store length of input command for validation

main_loop:
	; print the prompt
	lda prompt
	jsr acia_send_byte

	lda #' '
	jsr acia_send_byte

	; read from ACIA
	ldx #0 ; input_buffer idx

@read_prompt:
	jsr acia_read_byte ; read a byte from ACIA
	sta INPUT_BUFFER, x ; store it in the input buffer
	
	inx
	beq @done ; increase the pointer and check for overflow

	cmp #13 ; '\n'
	beq @done ; check for new line i.e. end

	; echo back the input
	jsr acia_send_byte

	jmp @read_prompt

@done:
	lda #'\n'
	jsr acia_send_byte

	txa
	dec ; adjust for the extra increment of \n
	sta INPUT_LENGTH

	; x is the length of the valid buffer
	ldy #0 ; y will index it

	; parse the 4 bytes after the command byte for address 
	; and the 2 bytes for the value in case of write command
	

	; parse the commands 
	lda INPUT_BUFFER, y
	cmp #'H'
	beq @cmd_help

	cmp #'W'
	beq @cmd_write

	cmp #'R'
	beq @cmd_read

	cmp #'B'
	beq @cmd_boot

	cmp #'L'
	beq @cmd_list

	jmp main_loop

; jump to the appropriate command handler based on the command byte
; workaround 65c02 limitation of not being able to branch to an absolute address
@cmd_help:
	jmp cmd_help
@cmd_write:
	jmp cmd_write
@cmd_read:
	jmp cmd_read
@cmd_boot:
	jmp cmd_boot
@cmd_list:
	jmp cmd_list

parse_char_to_hex:
	; converts the ASCII character in A to its hex value (0-15)
	cmp #'0'
	bcc @invalid
	cmp #':'  ; ':' is 1 after '9'
	bcc @is_digit
	
	cmp #'A'
	bcc @invalid
	cmp #'G'  ; 'G' is 1 after 'F'
	bcc @is_upper
	
	cmp #'a'
	bcc @invalid
	cmp #'g'  ; 'g' is 1 after 'f'
	bcc @is_lower
	
	bra @invalid

@is_digit:
	sec
	sbc #'0'
	rts

@is_upper:
	sec
	sbc #'A'
	clc
	adc #10
	rts

@is_lower:
	sec
	sbc #'a'
	clc
	adc #10
	rts

@invalid:
	lda #$FF
	rts

parse_data_field:
	phx
	; x is the offset in the input buffer where the hex byte starts
	; we need to convert the 2 ASCII hex digits into an 8-bit value and push it on the stack
	stz DATA

	; parse the first hex digit (most significant)
	lda INPUT_BUFFER, x
	jsr parse_char_to_hex
	asl
	asl
	asl
	asl
	sta DATA
	; parse the second hex digit
	inx
	lda INPUT_BUFFER, x
	jsr parse_char_to_hex
	ora DATA
	sta DATA
	plx
	rts

parse_address_field:
	phx
	; x is the offset in the input buffer where the address field starts
	; we need to convert the 4 ASCII hex digits into a 16-bit address
	stz ADDRESS
	stz ADDRESS + 1

	; parse the first hex digit (most significant) - high byte
	lda INPUT_BUFFER, x
	jsr parse_char_to_hex
	asl
	asl
	asl
	asl
	sta ADDRESS + 1

	; parse the second hex digit - high byte
	inx
	lda INPUT_BUFFER, x
	jsr parse_char_to_hex
	ora ADDRESS + 1
	sta ADDRESS + 1

	; parse the third hex digit (most significant) - low byte
	inx
	lda INPUT_BUFFER, x
	jsr parse_char_to_hex
	asl
	asl
	asl
	asl
	sta ADDRESS

	; parse the fourth hex digit - low byte
	inx
	lda INPUT_BUFFER, x
	jsr parse_char_to_hex
	ora ADDRESS
	sta ADDRESS

	plx
	rts

cmd_help:
	; check for correct length of command (1 for command)
	lda INPUT_LENGTH
	cmp #1
	bne @print_error

	ldx #0
@loop:
	lda help_message, x
	beq @done
	jsr acia_send_byte
	inx
	jmp @loop
@done:
	jmp main_loop
@print_error:
	jmp print_error
	
cmd_write:
	; check for correct length of command (1 for command + 4 for address + 2 for data)
	lda INPUT_LENGTH
	cmp #7
	bne @print_error

	ldx #1
	jsr parse_address_field

	ldx #5
	jsr parse_data_field

	ldy #0
	lda DATA
	sta (ADDRESS), y ; write the byte to the specified address

	; after writing, read back the value and print it for verification
	dec INPUT_LENGTH
	dec INPUT_LENGTH ; decrease the length so the command doesnt fail validation in cmd_read
	jmp cmd_read
@print_error:
	jmp print_error

cmd_read:
	; check for correct length of command (1 for command + 4 for address)
	lda INPUT_LENGTH
	cmp #5
	bne @print_error

	ldx #1
	jsr parse_address_field

	lda INPUT_BUFFER, x 
	jsr acia_send_byte
	inx
	lda INPUT_BUFFER, x 
	jsr acia_send_byte
	inx
	lda INPUT_BUFFER, x 
	jsr acia_send_byte
	inx
	lda INPUT_BUFFER, x 
	jsr acia_send_byte

	lda #':'
	jsr acia_send_byte
	lda #' '
	jsr acia_send_byte

	ldy #0
	lda (ADDRESS), y ; read the byte from the specified address
	jsr print_byte_as_hex ; print it as hex

	lda #'\n'
	jsr acia_send_byte

	jmp main_loop
@print_error:
	jmp print_error

cmd_boot:
	; check for correct length of command (1 for command + 4 for address)
	lda INPUT_LENGTH
	cmp #5
	bne @print_error

	ldx #1
	jsr parse_address_field

	jmp (ADDRESS) ; jump to the specified address to execute code
	jmp main_loop

@print_error:
	jmp print_error

print_byte_as_hex:
    ; Use the stack instead of TEMP to avoid zero-page collisions
	pha

    pha 

    lsr
    lsr
    lsr
    lsr
    phy
    tay
    lda hex, y
    ply
    jsr acia_send_byte

    pla 
    and #$0F
    phy
    tay
    lda hex, y
    ply
    jsr acia_send_byte

	pla
    rts

cmd_list:
	; check for correct length of command (1 for command + 8 for two addresses)
	lda INPUT_LENGTH
	cmp #9
	bne @print_error

	; parse start address into ADDRESS
	ldx #1
	jsr parse_address_field

	; save start address to TEMP
	lda ADDRESS
	sta TEMP
	lda ADDRESS + 1
	sta TEMP + 1

	; parse end address into ADDRESS
	ldx #5
	jsr parse_address_field

	; loop through addresses from TEMP to ADDRESS
@list_loop:
	; stop if TEMP >= ADDRESS
	lda TEMP + 1
	cmp ADDRESS + 1
	bne @check_low
	lda TEMP
	cmp ADDRESS
	bcs @list_done

@check_low:
	; if high bytes different and TEMP > ADDRESS, stop
	lda TEMP + 1
	cmp ADDRESS + 1
	bcc @print_line
	bne @list_done

@print_line:
	; print address
	lda TEMP + 1
	jsr print_byte_as_hex
	lda TEMP
	jsr print_byte_as_hex

	lda #':'
	jsr acia_send_byte
	lda #' '
	jsr acia_send_byte

	; print 16 bytes
	ldy #0
@print_loop:
	lda (TEMP), y
	jsr print_byte_as_hex
	lda #' '
	jsr acia_send_byte
	iny
	cpy #16
	bcc @print_loop

	; newline
	lda #'\n'
	jsr acia_send_byte

	; increment TEMP by 16
	lda TEMP
	clc
	adc #16
	sta TEMP
	lda TEMP + 1
	adc #0
	sta TEMP + 1

	jmp @list_loop

@list_done:
	jmp main_loop

@print_error:
	jmp print_error

print_error:
	ldx #0
@loop:
	lda syntax_eror_message, x
	beq @done
	jsr acia_send_byte
	inx
	jmp @loop
@done:
	jmp main_loop

boot_message:
	.asciiz "MOLD-2 BIOS Console\nUse H for help\n"

help_message:
	.asciiz "Available commands:\nH - help\nW<address><byte> - write #<byte> to $<address>\nR<address> - read from $<address>\nB<address> - execute code at $<address>\nL<address><address> - list memory from $<address> to $<address>\n" 

syntax_eror_message:
	.asciiz "Syntax error\n"

hex:
	.asciiz "0123456789ABCDEF"

acia_init_message:
	.asciiz "\nACIA initialised\n"

prompt:
	.byte '>'

	.segment "RESET_VECTOR"
	.word _irq
	.word _reset
	.word _irq