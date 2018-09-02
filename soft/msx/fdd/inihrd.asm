; -----------------------------------------------------------------------------
; INIHRD
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

WAIT_KEY: equ 1

INIHRD:
    if WAIT_KEY = 1
    ld hl,INIHRD_NEXT
    push hl
    endif

	ld hl,ROOKIE_S
	call PRINT

RESET_AND_PRINT_INFO:
    call HW_TEST
    ld hl,NOHARD_S
    jp c,PRINT

    call HW_RESET
    ld hl,RESERR_S
    jp c,PRINT

    ld hl,YESDEV_S
    dec a
    jp z,PRINT
    ld hl,NODEV_S
    jp PRINT

    if WAIT_KEY = 1
INIHRD_NEXT:
    jp CHGET
    endif

PRINT:
	ld a,(hl)
	or a
	ret z
	call CHPUT
	inc hl
	jr PRINT

DO_GET_DEV_DESC:
    ; Input:  HL = Address of a 8 byte buffer with the setup packet
    ;         DE = Address of the input or output data buffer
    ;         A  = Device address
    ;         B  = Maximum packet size for endpoint 0
    ; Output: A  = Error code (one of USB_ERR_*)
    ;         BC = Amount of data actually transferred (if IN transfer and no error)

    ld bc,32
    call STACKALLOC

    ex de,hl
    ld hl,DEV_DESC
    xor a
    ld b,64
    call HW_CONTROL_TRANSFER

    call STACKFREE
    ret

ROOKIE_S:
	db "Rookie Drive FDD BIOS v1.0",13,10
	db "(c) Konamiman 2018",13,10
	db 13,10
	db 0

NODEV_S:
    db  "No USB device found",13,10,0

YESDEV_S:
    db  "USB device found!",13,10,0

RESERR_S:
    db  "ERROR initializing USB host hardware or USB device",13,10,0

NOHARD_S:
    db  "USB host hardware not found!",13,10,0

DEV_DESC:
    db 80h, 6, 0, 1, 0, 0, 20, 0 

;In:  BC = Required space
;Out: HL = Address of allocated space
STACKALLOC:
    pop ix
    ld hl,2
    sbc hl,bc
    add hl,sp
    ld sp,hl
    push bc
    push ix
    ret

STACKFREE:
    pop ix
    pop hl
    dec hl
    dec hl
    add hl,sp
    ld sp,hl
    push ix
    ret
