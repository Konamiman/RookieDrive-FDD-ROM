; -----------------------------------------------------------------------------
; CHOICE
; -----------------------------------------------------------------------------
; Input: 	None
; Output:	HL	pointer to choice string, 0 if no choice
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

CHOICE:
	ld   hl,0
	ret

; -----------------------------------------------------------------------------
; DSKFMT
; -----------------------------------------------------------------------------
; Input: 	A	choicecode (1-9)
;		D	drivenumber
;		HL	begin of workarea
;		BC	length of workarea
; Output:	F	Cx set for error
;			Cx reset for ok
;		A	if error, errorcode
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

DSKFMT:
	ld   a,16
	scf
	ret