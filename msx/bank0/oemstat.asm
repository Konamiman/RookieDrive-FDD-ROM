; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the CALL statements handler and the
; implementations of the statements themselves.


; -----------------------------------------------------------------------------
; OEMSTATEMENT
; -----------------------------------------------------------------------------
; Input:	HL	basicpointer
; Output:	F	Cx set if statement not recognized
;			Cx reset if statement is recognized
;		HL	basicpointer,	updated if recognized
;					unchanged if not recognized
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

OEMSTA:
    push hl
    ld hl,OEM_COMMANDS

_OEMSTA_CHECK_COMMAND:
    ld a,(hl)
    or a
    jr z,_OEMSTA_UNKNOWN
    ld de,PROCNM
_OEMSTA_CHECK_COMMAND_LOOP:
    ld a,(de)
    cp (hl)
    jr nz,_OEMSTA_SKIP_COMMAND
    or a
    jr z,_OEMSTA_FOUND
    inc hl
    inc de
    jr _OEMSTA_CHECK_COMMAND_LOOP

_OEMSTA_SKIP_COMMAND:
    ld a,(hl)
    inc hl
    or a
    jr nz,_OEMSTA_SKIP_COMMAND
    inc hl  ;Skip routine address
    inc hl
    jr _OEMSTA_CHECK_COMMAND

_OEMSTA_FOUND:
    inc hl
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp (hl)

_OEMSTA_UNKNOWN:
    pop hl
	scf
	ret

OEM_COMMANDS:

    if USE_ALTERNATIVE_PORTS=1
    db "USBRESET2",0
    dw OEMC_USBRESET
    db "USBERROR2",0
    dw OEMC_USBERROR
    else
    db "USBRESET",0
    dw OEMC_USBRESET
    db "USBERROR",0
    dw OEMC_USBERROR
    endif

    db "USBMENU",0
    dw OEMC_USBMENU
    db 0


    ;--- CALL USBRESET
    ;    Resets USB hardware and prints device info, just like at boot time

OEMC_USBRESET:
    ld ix,VERBOSE_RESET
    ld iy,ROM_BANK_1
    call CALL_BANK
    jp OEM_END


    ;--- CALL USBERROR
    ;    Displays information about the USB or UFI error returned
    ;    by the last executed UFI command

OEMC_USBERROR:
    ld ix,WK_GET_ERROR
    ld iy,ROM_BANK_1
    call CALL_BANK
    or a
    jr z,_OEMC_USBERROR_ASC

    push af
    ld hl,OEM_S_USBERR
    call OEM_PRINT
    pop af
    call PRINT_ERROR_DESCRIPTION
    jr OEM_END

_OEMC_USBERROR_HEX:
    call OEM_PRINTHEX
    jr OEM_END

_OEMC_USBERROR_ASC:
    ld a,d
    or a
    ld hl,OEM_S_NOERRDATA
    push af
    call z,OEM_PRINT
    pop af
    jr z,OEM_END

    ld hl,OEM_S_ASC
    call OEM_PRINT
    ld a,d
    call OEM_PRINTHEX
    ld hl,OEM_S_H_CRLF
    call OEM_PRINT
    ld hl,OEM_S_ASCQ
    call OEM_PRINT
    ld a,e
    call OEM_PRINTHEX
    ld hl,OEM_S_H_CRLF

OEM_PRINT_AND_END:
    call OEM_PRINT

OEM_END:
    pop hl
    or a
    ret

OEM_S_USBERR:
    db "USB error: ",0
OEM_S_H_CRLF:
    db  "h",13,10,0
OEM_S_ASC:
    db  "ASC:  ",0
OEM_S_ASCQ:
    db  "ASCQ: ",0
OEM_S_NOERRDATA:
    db  "No error data recorded",0
    

    ;--- CALL USBMENU
    ;    Open the USB menu if there's a storage device inserted

OEMC_USBMENU:
    ld ix,DO_BOOT_MENU
    ld iy,ROM_BANK_1
    call CALL_BANK
    cp 3
    ld hl,OEM_S_NO_STDEV
    jp z,OEM_PRINT_AND_END
    cp 2
    ld hl,OEM_S_NO_MEM
    jp z,OEM_PRINT_AND_END
    jp OEM_END

OEM_S_NO_STDEV:
    db "No USB storage device present",7,0
OEM_S_NO_MEM:
    db "Not enough memory",7,0


; -----------------------------------------------------------------------------
; Print the description of an USB error code
;
; Input: A = USB error code

PRINT_ERROR_DESCRIPTION:
    cp USB_ERR_MAX+1
    jp nc,OEM_PRINTHEX

    dec a
    ld c,a
    sla c
    ld b,0
    ld hl,USBERR_S_TABLE
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp OEM_PRINT

USBERR_S_TABLE:
    dw USBERR_S_1
    dw USBERR_S_2
    dw USBERR_S_3
    dw USBERR_S_4
    dw USBERR_S_5
    dw USBERR_S_6
    dw USBERR_S_7

USBERR_S_1: db "NAK",0
USBERR_S_2: db "Stall",0
USBERR_S_3: db "Timeout",0
USBERR_S_4: db "Data error",0
USBERR_S_5: db "Device was disconnected",0
USBERR_S_6: db "Panic button pressed",0
USBERR_S_7: db "Unexpected status received from USB host hardware",0


; -----------------------------------------------------------------------------
; Print a byte in hexadecimal format
;
; Input: A = byte to print

OEM_PRINTHEX:
    push af
	call	_OEM_PRINTHEX_1
	pop af
	jr	_OEM_PRINTHEX_2

_OEM_PRINTHEX_1:	rra
	rra
	rra
	rra
_OEM_PRINTHEX_2:	or	0F0h
	daa
	add	a,0A0h
	adc	a,40h

	call CHPUT
	ret


; -----------------------------------------------------------------------------
; Print a zero-terminated string
;
; Input: HL = Pointer to the string

OEM_PRINT:
	ld a,(hl)
	or a
	ret z
	call CHPUT
	inc hl
	jr OEM_PRINT