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
    db "USBRESET",0
    dw OEMC_USBRESET
    db "USBERROR",0
    dw OEMC_USBERROR
    db 0

OEMC_USBRESET:
    ld ix,RESET_AND_PRINT_INFO
    ld iy,ROM_BANK_1
    call CALL_BANK
    jp OEM_END

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
    cp USB_ERR_MAX+1
    jr nc,_OEMC_USBERROR_HEX

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
    call OEM_PRINT
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

OEM_PRINT:
	ld a,(hl)
	or a
	ret z
	call CHPUT
	inc hl
	jr OEM_PRINT