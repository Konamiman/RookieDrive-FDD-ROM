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
    ld de,OEM_USBRESET
    push hl
    ld hl,OEM_USBRESET
    ld de,PROCNM

_OEMSTA_LOOP:
    ld a,(de)
    cp (hl)
    jr nz,_OEMSTA_UNKNOWN
    inc hl
    or a
    jr z,_OEMSTA_FOUND
    inc de
    jr _OEMSTA_LOOP

_OEMSTA_FOUND:
    call RESET_AND_PRINT_INFO
    pop hl
    or a
    ret

_OEMSTA_UNKNOWN:
    pop hl
	scf
	ret

OEM_USBRESET:
    db  "USBRESET",0
