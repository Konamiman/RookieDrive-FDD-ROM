; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This routine resets the USB hardware, resets and initializes the device,
; and prints the device name or the appropriate error message.
; It is executed at boot time and by CALL USBRESET.


VERBOSE_RESET:
    call HW_TEST
    ld hl,NOHARD_S
    jp c,PRINT

    ld hl,0C000h
    call HWF_MOUNT_DISK
    jr c,_HW_RESET_NO_STOR

    ld hl,STOR_FOUND_S
    call PRINT
    ld hl,0C000h
    ld b,0
    ;Print the device name, collapsing multiple spaces to a single one
_HW_RESET_PRINT:
    ld a,(hl)
    inc hl
    or a
    jr z,_HW_RESET_PRINT_END
    cp ' '
    jr nz,_HW_RESET_PRINT_GO
    cp b
    jr z,_HW_RESET_PRINT
_HW_RESET_PRINT_GO:
    ld b,a
    call CHPUT
    jr _HW_RESET_PRINT
_HW_RESET_PRINT_END:
    call WK_INIT_FOR_STORAGE_DEV
    ret

_HW_RESET_NO_STOR:
    ld b,5
_HW_RESET_TRY:
    push bc
    call HW_RESET
    pop bc
    jr nc,_HW_RESET_TRY_OK
    djnz _HW_RESET_TRY
    ld hl,RESERR_S
    jp PRINT
_HW_RESET_TRY_OK:
    inc a
    ld hl,NODEV_S
    jp z,PRINT

    ;Experiments with hubs, please ignore
    if 0

    ld a,2
    call HW_SET_ADDRESS
    ld a,2
    ld b,1
    call HW_SET_CONFIG
    ld hl,CMD_PORT_POWER
    ld de,0
    ld a,2
    ld b,64
    call HW_CONTROL_TRANSFER
    ld hl,CMD_PORT_RESET
    ld de,0
    ld a,2
    ld b,64
    call HW_CONTROL_TRANSFER
    jr HUBDONE

CMD_PORT_POWER:
    db  00100011b, 3, 8, 0, 1, 0, 0, 0
CMD_PORT_RESET:
    db  00100011b, 3, 4, 0, 1, 0, 0, 0
HUBDONE:

    endif

    ld b,5
_TRY_USB_INIT_DEV:
    push bc
    call USB_INIT_DEV
    ld h,b
    pop bc
    cp 2
    jr c,_TRY_USB_INIT_DEV_OK
    djnz _TRY_USB_INIT_DEV
    ld a,h
    ld hl,DEVERR_S
    jp PRINT_ERROR
_TRY_USB_INIT_DEV_OK:

    or a
    ld hl,NO_CBI_DEV_S
    jp nz,PRINT

    ld hl,YES_CBI_DEV_S
    call PRINT
    jp PRINT_DEVICE_INFO

    if WAIT_KEY_ON_INIT = 1
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


; -----------------------------------------------------------------------------
; Print the device name from INQUIRY command

PRINT_DEVICE_INFO_STACK_SPACE: equ 36

PRINT_DEVICE_INFO:
    ld hl,-PRINT_DEVICE_INFO_STACK_SPACE
    add hl,sp
    ld sp,hl

    ld b,3  ;Some drives stall on first command after reset so try a few times
_TRY_INQUIRY:    
    push bc
    push hl
    pop de
    ld hl,INIQUIRY_CMD
    ld bc,36
    ld a,1
    or a
    push de
    call USB_EXECUTE_CBI_WITH_RETRY
    pop hl
    pop bc
    or a
    jr z,_INQUIRY_OK
    djnz _TRY_INQUIRY
    jr _PRINT_DEVICE_INFO_ERR
_INQUIRY_OK:

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

    ld hl,CRLF_S
    call PRINT

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


    ; Print a fixed-length space-padded string, skipping the padding
    ; Input: HL = String address
    ;        B  = String length

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


; -----------------------------------------------------------------------------
; Print an error message and the description of an USB error code
;
; Input: HL = Error message
;        A = Error code

PRINT_ERROR:
    push af
    call PRINT
    pop af

    ld ix,PRINT_ERROR_DESCRIPTION
    ld iy,ROM_BANK_0
    call CALL_BANK

    ld hl,CRLF_S
    jp PRINT


; -----------------------------------------------------------------------------
; Strings

ROOKIE_S:
	db "Rookie Drive NestorBIOS v2.0",13,10
    db "Prerelease version 2021.02.22",13,10
	db "(c) Konamiman 2018,2021",13,10
	db 13,10
    db "Initializing device...",13
	db 0

NOHARD_S:
    db  "USB host hardware not found!"
CRLF_S:
    db 13,10,0

NODEV_S:
    db  "No USB device found",27,"K",13,10,0

NO_CBI_DEV_S:
    db  "USB device found, but it's not a FDD unit",13,10,0

YES_CBI_DEV_S:
    db  "USB FDD found: ",27,"K",0    

RESERR_S:
    db  "ERROR initializing USB host hardware or resetting USB device",13,10,0

DEVERR_S:
    db  "ERROR querying or initializing USB device: ",0

ERR_INQUIRY_S:
    db  "ERROR querying the device name: ",0

STOR_FOUND_S:
    db "USB storage device found: ",0
