; -----------------------------------------------------------------------------
; INIHRD
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

INIHRD:
	ld hl,ROOKIE_S
	call PRINT

	ret

PRINT:
	ld a,(hl)
	or a
	ret z
	call CHPUT
	inc hl
	jr PRINT

ROOKIE_S:
	db "Rookie Drive FDD BIOS v1.0",13,10
	db "(c) Konamiman 2018",13,10
	db 13,10
	db 0

