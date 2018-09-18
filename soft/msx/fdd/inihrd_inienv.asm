; We do the hardware reset in INIENV and not in INIHRD
; because we need to setup the work area during reset, but work area
; is zeroed by kernel between INIHRD and INIENV.

INITXT: equ 006Ch

; -----------------------------------------------------------------------------
; INIHRD
; -----------------------------------------------------------------------------
; Input:	None
; Output:	None
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

INIHRD:
    call INITXT
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

    call USB_INIT_DEV
    or a
    ld hl,YES_CBI_DEV_S
    push af
    call z,PRINT
    pop af
    jp z,PRINT_DEVICE_INFO

    dec a
    ld hl,NO_CBI_DEV_S
    jp z,PRINT

    ld a,b
    ld hl,DEVERR_S
    jp PRINT_ERROR

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


PRINT_DEVICE_INFO_STACK_SPACE: equ 36

PRINT_DEVICE_INFO:
    ld hl,-PRINT_DEVICE_INFO_STACK_SPACE
    add hl,sp
    ld sp,hl

    push hl
    pop de
    ld hl,INIQUIRY_CMD
    ld bc,36
    or a
    push de
    call USB_EXECUTE_CBI
    pop hl
    or a
    jr nz,_PRINT_DEVICE_INFO_ERR

    ld bc,8
    add hl,bc
    ld b,8
    call PRINT_SPACE_PADDED_STRING
    ld a,' '
    call CHPUT

    ld bc,8 ;base + 16
    add hl,bc
    ld b,16
    call PRINT_SPACE_PADDED_STRING
    ld a,' '
    call CHPUT

    ld bc,16 ;base + 32
    add hl,bc
    ld b,4
    call PRINT_SPACE_PADDED_STRING

    jr _PRINT_DEVICE_INFO_END

_PRINT_DEVICE_INFO_ERR:
    ld hl,ERR_INQUIRY_S
    call PRINT_ERROR
_PRINT_DEVICE_INFO_END:    
    ld hl,PRINT_DEVICE_INFO_STACK_SPACE
    add hl,sp
    ld sp,hl
    ret

INIQUIRY_CMD:
    db 12h, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0


;In: HL = Address
;    B  = Length

PRINT_SPACE_PADDED_STRING:
    push hl
    call _PRINT_SPACE_PADDED_STRING
    pop hl
    ret

_PRINT_SPACE_PADDED_STRING:
    ld e,b
    ld d,0
    push hl
    add hl,de   ;HL points past the last char of the string
_PSPS_Z_LOOP:
    dec hl
    ld a,(hl)
    cp ' '
    jr nz,_PSPS_DO
    djnz _PSPS_Z_LOOP
    pop hl
    ret         ;All the string is spaces, do nothing

_PSPS_DO:
    pop hl
_PSPS_P_LOOP:
    ld a,(hl)
    call CHPUT
    inc hl
    djnz _PSPS_P_LOOP

    ret


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

DO_READ_SECTOR_CMD:
    ld hl,READ_SECTOR_0_CMD
    ld de,9000h
    ld bc,512
    ld a,1
    or a
    call USB_EXECUTE_CBI_WITH_RETRY
    jr READ_SECTOR_0

READ_SECTOR_0_CMD:
    db 28h, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0

    endif

  
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
    db  "USB FDD found: ",0    

RESERR_S:
    db  "ERROR initializing USB host hardware or resetting USB device",13,10,0

DEVERR_S:
    db  "ERROR querying or initializing USB device: ",0

ERR_INQUIRY_S:
    db  "ERROR querying the device name: ",0

DEV_DESC:
    db 80h, 6, 0, 1, 0, 0, 20, 0 

;In: HL = Error message, A = Error code
PRINT_ERROR:
    push af
    call PRINT
    pop af
    add "0"
    call CHPUT
    ld hl,CRLF_S
    jp PRINT
