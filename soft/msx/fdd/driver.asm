; Base code for the FDD driver for Rookie Drive
; By Konamiman, 2018
; -----------------------------------------------------------------------------
; based on DSK2ROM - ASCII8/KonamiSCC megarom driver
; (C)2007 Vincent van Dam (vincentd@erg.verweg.com)
; -----------------------------------------------------------------------------
; based on the template by Arjen Zeilemaker (C)1992-2005 Ultrasoft.
; many thanks to Ramones for his help, support & testing (and getdpb code!)
; -----------------------------------------------------------------------------
; This driver requires a patched BDOS kernel; without the patched kernel it
; doesn't make much sense.
; -----------------------------------------------------------------------------

; Note that INIHRD, DSKIO, DSKCHG, CHOICE and FORMAT are in separate files

; symbols which can be used from the kernel

; GETSLT	get my slotid
; DIV16		divide
; GETWRK	get my workarea
; SETINT	install my interrupt handler
; PRVINT	call orginal interrupt handler
; PROMPT	prompt for phantom drive
; RAWFLG	verify flag
; $SECBUF	temporary sectorbuffer
; XFER		transfer to TPA
; DISINT	inform interrupts are being disabled
; ENAINT	inform interrupts are being enabled
; PROCNM	CALL statement name

 ; symbols which must be defined by the driver

; INIHRD	initialize diskdriver hardware
; DRIVES	how many drives are connected
; INIENV	initialize diskdriver workarea
; DSKIO		diskdriver sector i/o
; DSKCHG	diskdriver diskchange status
; GETDPB	build Drive Parameter Block
; CHOICE	get format choice string
; DSKFMT	format disk
; DSKSTP	stop diskmotor
; OEMSTA	diskdriver special call statements

; MYSIZE	size of diskdriver workarea
; SECLEN	size of biggest sector supported by the diskdriver
; DEFDPB	pointer to a default Drive Parameter Block

; errorcodes used by DSKIO, DSKCHG and GETDPB
;
; 0	write protect error
; 2	not ready error
; 4	data (crc) error
; 6	seek error
; 8	record not found error
; 10	write fault error
; 12	other error

; errorcodes used by DSKFMT
;
; 0	write protect error
; 2	not ready error
; 4	data (crc) error
; 6	seek error
; 8	record not found error
; 10	write fault error
; 12	bad parameter
; 14	insufficient memory
; 16	other error

; -----------------------------------------------------------------------------
; some constants
; -----------------------------------------------------------------------------
	
MYSIZE:		equ	0		; Size of environment
SECLEN:		equ	512		; Size of biggest sector


; -----------------------------------------------------------------------------
; INIHRD_BASIC
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	No registers may be affected
; -----------------------------------------------------------------------------
	
INIHRD_BASIC:
	ret
	if 0
	push hl
	push de
	push bc
	push af
	push ix
	push iy
	call INIHRD
	pop  iy
	pop  ix
	pop  af
	pop  bc
	pop  de
	pop  hl
	ret
	endif


; -----------------------------------------------------------------------------
; DRIVES
; -----------------------------------------------------------------------------
; Input: 	F	Zx set if to return physical drives
;			Zx reset if to return at least 2 drives, if only one
;			  physical drive it becomes a phantom drive
; Output:	L	number of drives
; Changed:	F,HL,IX,IY may be affected
;
; Remark:	DOS1 does not handle L=0 correctly
; -----------------------------------------------------------------------------

DRIVES:
	xor  a
	ld   l,1
	ret


; -----------------------------------------------------------------------------
; GETDPB
; -----------------------------------------------------------------------------
; Input: 	A	Drivenumber
; 		B	first byte of FAT
; 		C	Media descriptor
; 		HL	pointer to DPB
; Output:	[HL+1]
;		..
;		[HL+18]	updated
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

GETDPBERR:
	pop  bc
	pop  af
	ld   a,12
	scf
	ret
GETDPB:
	push af 
	push bc 
	push hl 
	ld   hl,(SECBUF)
	push hl
	ld   b,1
	ld   de,0 
	or   a 
	ld   c,0FFh 
	call DSKIO
	pop  iy 
	pop  hl 
	jr   c,GETDPBERR
	inc  hl
	push hl
	ex   de,hl
	ld   hl,DEFDPB+1
	ld   bc,18
	ldir
	pop  hl
	ld   a,(iy+21)
	cp   0F9h
	jr   z,GETDPBEND 
	ld   (hl),a
	inc  hl
	ld   a,(iy+11)
	ld   (hl),a
	inc  hl
	ld   a,(iy+12)
	ld   (hl),a
	inc  hl
	ld   (hl),0Fh
	inc  hl
	ld   (hl),04h
	inc  hl
	ld   a,(iy+0Dh)
	dec  a
	ld   (hl),a
	inc  hl
	add  a,1
	ld   b,0
GETDPB0: 
	inc  b
	rra 
	jr   nc,GETDPB0
	ld   (hl),b
	inc  hl
	push bc
	ld   a,(iy+0Eh)
	ld   (hl),a
	inc  hl
	ld   d,(iy+0Fh)
	ld   (hl),d
	inc  hl
	ld   b,(iy+010h)
	ld   (hl),b
	inc  hl
GETDPB1: 
	add  a,(iy+016h)
	jr   nc,GETDPB2
	inc  d
GETDPB2: 
	djnz GETDPB1
	ld   c,a
	ld   b,d
	ld   e,(iy+011h)
	ld   d,(iy+012h)
	ld   a,d
	or   a
	ld   a,0FEh
	jr   nz,GETDPB3
	ld   a,e
GETDPB3: 
	ld   (hl),a
	inc  hl
	dec  de
	ld   a,4
GETDPB4: 
	srl  d
	rr   e
	dec  a
	jr   nz,GETDPB4
	inc  de
	ex   de,hl
	add  hl,bc
	ex   de,hl
	ld   (hl),e
	inc  hl
	ld   (hl),d
	inc  hl
	ld   a,(iy+013h)
	sub  e
	ld   e,a
	ld   a,(iy+014h)
	sbc  a,d
	ld   d,a
	pop  af
GETDPB5: 
	dec  a
	jr   z,GETDPB6
	srl  d
	rr   e
	jr   GETDPB5
GETDPB6:
	inc  de
	ld   (hl),e
	inc  hl
	ld   (hl),d
	inc  hl
	ld   a,(iy+016h)
	ld   (hl),a
	inc  hl
	ld   (hl),c
	inc  hl
	ld   (hl),b
GETDPBEND: 
	pop  bc
	pop  af 
	xor  a
	ret

DEFDPB:
	db   0
	;; default dpb
	db   0F9h		; Media F9
	dw   512		; 80 Tracks	
	db   0Fh		; 9 sectors
	db   04h		; 2 sides
	db   01h		; 3.5" 720 Kb
	db   02h
	dw   1
	db   2
	db   112
	dw   14
	dw   714
	db   3
	dw   7
	
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
	scf
	ret

; -----------------------------------------------------------------------------
; DSKSTP (Not the offical name)
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

DSKSTP:
	ret
