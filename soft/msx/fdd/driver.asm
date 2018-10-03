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
; DSKSTP (Not the offical name)
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

DSKSTP:
	ret


; Entry points for the driver functions

DSKIO:
    ld ix,DSKIO_IMPL
    jp CALL_BANK_1

DSKCHG:
    ld ix,DSKCHG_IMPL
    jp CALL_BANK_1

GETDPB:
    ld ix,GETDPB_IMPL
    jp CALL_BANK_1

CHOICE:
    ld ix,CHOICE_IMPL
    jp CALL_BANK_1
    
DSKFMT:
    ld ix,DSKFMT_IMPL
    jp CALL_BANK_1

INIHRD:
    ld ix,INIHRD_IMPL
    jp CALL_BANK_1

INIENV:
    ld ix,INIENV_IMPL
    jp CALL_BANK_1
