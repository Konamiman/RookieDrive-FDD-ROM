; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the entry points for the driver functions
; that live in ROM bank 1, plus the implementation of DRIVES.


; The following symbols information was borrowed from
; https://github.com/joyrex2001/dsk2rom

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

;How many bytes to allocate in page 3.
;We don't allocate any because the 8 bytes assigned to our slot
;in SLTWRK are enough.	
MYSIZE:		equ	0

SECLEN:		equ	512		; Size of biggest sector


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
	ld   l,1
    ret z
    inc l
	ret


; -----------------------------------------------------------------------------
; Entry points for the driver functions
; -----------------------------------------------------------------------------

DSKIO:
    ld ix,DSKIO_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK

DSKCHG:
    ld ix,DSKCHG_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK

GETDPB:
    ld ix,GETDPB_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK

CHOICE:
    ld ix,CHOICE_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK
    
DSKFMT:
    ld ix,DSKFMT_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK

INIHRD:
    ld ix,INIHRD_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK

INIENV:
    ld ix,INIENV_IMPL
    ld iy,ROM_BANK_1
    jp CALL_BANK


    ;Disk access experiments
    if 0

READ_SECTOR_0:
    ld hl,8000h
    ld de,8000h+1
    ld bc,4000h-1
    ld (hl),0ffh
    ldir

    xor a
    ld b,32
    ld de,0
    ld hl,8000h
    call DSKIO
    ret

    xor a
    ld hl,9000h
    call DSKCHG

    ds 7500h-$,0FFh

DO_READ_SECTOR_CMD:
    ld b,80
    push bc
    ld hl,READ_SECTOR_0_CMD
    ld de,0C000h
    ld bc,12
    ldir
    pop bc
    ld a,b
    ld (0C008h),a
    sla b
    ld c,0
    ld hl,0C000h
    ld de,2000h
    ld a,1
    or a
    ld ix,USB_EXECUTE_CBI_WITH_RETRY
    ld iy,ROM_BANK_1
    call CALL_BANK
    jr DO_READ_SECTOR_CMD

READ_SECTOR_0_CMD:
    db 28h, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0

    endif