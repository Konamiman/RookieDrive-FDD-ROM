; We do the hardware reset in INIENV and not in INIHRD
; because we need to setup the work area during reset, but work area
; is zeroed by kernel between INIHRD and INIENV.

; -----------------------------------------------------------------------------
; INIHRD
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

INIHRD:
	ld hl,ROOKIE_S
	jp PRINT


; -----------------------------------------------------------------------------
; INIENV
; -----------------------------------------------------------------------------
; Input: 	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
;
; Remark:	-
; -----------------------------------------------------------------------------

INIENV:

WAIT_KEY: equ 1

    if WAIT_KEY = 1
    ld hl,INIHRD_NEXT
    push hl
    endif

RESET_AND_PRINT_INFO:
    call HW_TEST
    ld hl,NOHARD_S
    jp c,PRINT

    call HW_RESET
    ld hl,RESERR_S
    jp c,PRINT
    inc a
    ld hl,NODEV_S
    jp z,PRINT

    call INIT_USB_DEV
    ;xor a
    ;inc a
    ;nop
    or a
    ld hl,YES_CBI_DEV_S
    push af
    call z,PRINT
    pop af
    jp z,DO_INQUIRY

    dec a
    ld hl,NO_CBI_DEV_S
    jp z,PRINT

    push bc
    ld hl,DEVERR_S
    call PRINT
    pop af
    add a,"0"
    call CHPUT
    ld hl,CRLF_S
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

DO_INQUIRY:
    ld hl,INIQUIRY_CMD
    ld de,9000h
    ld bc,36
    or a
    call USB_EXECUTE_CBI
    or a
    ld hl,ERR_INQUIRY_S
    jp nz,PRINT

    xor a
    ld (9000h+36),a
    ld hl,9000h+8
    call PRINT
    ret

GET_CONFIG_CMD:
    db 80h, 8, 0, 0, 0, 0, 1, 0

INIQUIRY_CMD:
    db 12
    db 12h, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0
  
ROOKIE_S:
	db "Rookie Drive FDD BIOS v1.0",13,10
	db "(c) Konamiman 2018",13,10
	db 13,10
	db 0

NOHARD_S:
    db  "USB host hardware not found!"
CRLF_S:
    db 13,10,0

NODEV_S:
    db  "No USB device found",13,10,0

NO_CBI_DEV_S:
    db  "USB device found, but it's not a FDD unit",13,10,0

YES_CBI_DEV_S:
    db  "USB FDD unit found!",13,10,0    

RESERR_S:
    db  "ERROR initializing USB host hardware or resetting USB device",13,10,0

DEVERR_S:
    db  "ERROR querying or initializing USB device: ",0

ERR_INQUIRY_S:
    db  "ERROR querying the device name",0

DEV_DESC:
    db 80h, 6, 0, 1, 0, 0, 20, 0 

;In:  BC = Required space
;Out: HL = Address of allocated space
STACKALLOC:
    pop ix
    ld hl,2
    or a
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
