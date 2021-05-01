; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the CALL statements handler and the
; implementations of the statements themselves.


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
    push hl
    ld hl,OEM_COMMANDS

_OEMSTA_CHECK_COMMAND:
    ld a,(hl)
    or a
    jr z,_OEMSTA_UNKNOWN
    ld de,PROCNM
_OEMSTA_CHECK_COMMAND_LOOP:
    ld a,(de)
    cp (hl)
    jr nz,_OEMSTA_SKIP_COMMAND
    or a
    jr z,_OEMSTA_FOUND
    inc hl
    inc de
    jr _OEMSTA_CHECK_COMMAND_LOOP

_OEMSTA_SKIP_COMMAND:
    ld a,(hl)
    inc hl
    or a
    jr nz,_OEMSTA_SKIP_COMMAND
    inc hl  ;Skip routine address
    inc hl
    jr _OEMSTA_CHECK_COMMAND

_OEMSTA_FOUND:
    inc hl
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp (hl)

_OEMSTA_UNKNOWN:
    pop hl
	scf
	ret

OEM_COMMANDS:

    if USE_ALTERNATIVE_PORTS=1
    db "USBRESET2",0
    dw OEMC_USBRESET
    db "USBERROR2",0
    dw OEMC_USBERROR
    else
    db "USBRESET",0
    dw OEMC_USBRESET
    db "USBERROR",0
    dw OEMC_USBERROR
    endif

    db "USBMENU",0
    dw OEMC_USBMENU
    db "USBCD",0
    dw OEMC_USBCD
    db 0


    ;--- CALL USBRESET
    ;    Resets USB hardware and prints device info, just like at boot time

OEMC_USBRESET:
    ld a,1
    ld ix,VERBOSE_RESET
    call OEM_CALL_BANK_1
    jp OEM_END


    ;--- CALL USBERROR
    ;    Displays information about the USB or UFI error returned
    ;    by the last executed UFI command

OEMC_USBERROR:
    ld ix,WK_GET_ERROR
    call OEM_CALL_BANK_1
    or a
    jr z,_OEMC_USBERROR_ASC

    push af
    ld hl,OEM_S_USBERR
    call OEM_PRINT
    pop af
    call PRINT_ERROR_DESCRIPTION
    jr OEM_END

_OEMC_USBERROR_HEX:
    call OEM_PRINTHEX
    jr OEM_END

_OEMC_USBERROR_ASC:
    ld a,d
    or a
    ld hl,OEM_S_NOERRDATA
    push af
    call z,OEM_PRINT
    pop af
    jr z,OEM_END

    ld hl,OEM_S_ASC
    call OEM_PRINT
    ld a,d
    call OEM_PRINTHEX
    ld hl,OEM_S_H_CRLF
    call OEM_PRINT
    ld hl,OEM_S_ASCQ
    call OEM_PRINT
    ld a,e
    call OEM_PRINTHEX
    ld hl,OEM_S_H_CRLF

OEM_PRINT_AND_END:
    call OEM_PRINT

OEM_END:
    pop hl
    or a
    ret

OEM_S_USBERR:
    db "USB error: ",0
OEM_S_H_CRLF:
    db  "h"
OEM_S_CRLF:
    db 13,10,0
OEM_S_ASC:
    db  "ASC:  ",0
OEM_S_ASCQ:
    db  "ASCQ: ",0
OEM_S_NOERRDATA:
    db  "No error data recorded",0
    

    ;--- CALL USBMENU
    ;    Open the USB menu if there's a storage device inserted

OEMC_USBMENU:
    ld a,1
    ld ix,DO_BOOT_MENU
    call OEM_CALL_BANK_1
    cp 3
    ld hl,OEM_S_NO_STDEV
    jp z,OEM_PRINT_AND_END
    cp 2
    ld hl,OEM_S_NO_MEM
    jp z,OEM_PRINT_AND_END
    jp OEM_END

OEM_S_NO_STDEV:
    db "No USB storage device present",7,0
OEM_S_NO_MEM:
    db "Not enough memory",7,0


    ;--- CALL USBCD - Print the current directory
    ;    CALL USBCD("dir/dir")  - Change to the specified relative directory
    ;    CALL USBCD("/dir/dir") - Change to the specified absolute directory

OEMC_USBCD:
    pop hl

    push iy
    ld iy,-65
    add iy,sp
    ld sp,iy
    call _OEMC_USBCD
    ld iy,65
    add iy,sp
    ld sp,iy
    pop iy

    or a
    ret
_OEMC_USBCD:

    dec hl
    ld ix,CHRGTR
    call OEM_CALBAS
    jp z,OEMC_USBCD_PRINT

    ;--- Change the current directory

    cp '('
    jp nz,THROW_SYNTAX_ERROR
    inc hl
    ld ix,FRMEVL
    call OEM_CALBAS
    push hl
    ld ix,FRESTR
    call OEM_CALBAS
    ex de,hl
    pop hl
    dec hl
    ld ix,CHRGTR
    call OEM_CALBAS
    cp ')'
    jp nz,THROW_SYNTAX_ERROR

    ;Here DE = Pointer to string descriptor

    push hl ;Save BASIC text pointer
    ex de,hl

    ld a,(hl)
    or a
    jp z,THROW_ILLEGAL_FN_CALL
    cp 64+1
    jp nc,THROW_STRING_TOO_LONG

    ld b,0
    ld c,a  ;BC = Length of string
    inc hl
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a  ;HL = Pointer to string

    push iy
    pop de
    push bc
    ldir
    pop bc
    xor a
    ld (de),a   ;IY contains now the zero-terminated string

    push iy
    pop hl
    ld a,(hl)
    cp '.'
    jr nz,_OEMC_USBCD_DO
    inc hl
    ld a,(hl)
    dec hl
    cp '.'
    jp nz,THROW_DIR_NOT_FOUND

    ;"..": go to parent directory

    push iy
    pop de
    ld ix,DSK_READ_CURDIR_FILE
    call OEM_CALL_BANK_1
    dec a
    jp z,THROW_DISK_ERROR

    ld a,b  ;Length of current directory
    or a
    jp z,THROW_DIR_NOT_FOUND    ;Root directory: it has no parent
    ld e,b
    ld c,b
    ld b,0
    push iy
    pop hl
    add hl,bc   ;HL points now at the terminating zero
    ld b,e
_OEMC_USBCD_FIND_PARENT:
    dec hl
    ld a,(hl)
    cp '/'
    jr z,_OEMC_USBCD_PARENT_FOUND
    djnz _OEMC_USBCD_FIND_PARENT
    ;If this is reached: no '/' in current dir, so parent is root

_OEMC_USBCD_PARENT_FOUND:
    ld (hl),0   ;Remove last '/' and everything after it
    push iy
    pop hl
    ld a,1  ;Set absolute dir
    jr _OEMC_USBCD_DO2

_OEMC_USBCD_DO:
    cp '/'
    ld a,0
    jr nz,_OEMC_USBCD_DO2    ;Relative dir
    inc hl  ;Absolute dir
    inc a
_OEMC_USBCD_DO2:
    call OEM_TOUPPER
    ld ix,DSK_CHANGE_DIR_U
    call OEM_CALL_BANK_1
    or a
    jr z,_OEMC_USBCD_END

    push af
    ld ix,DSK_REMOUNT
    call OEM_CALL_BANK_1
    pop af

    dec a
    dec a
    jp z,THROW_DIR_NOT_FOUND
    dec a
    jp z,THROW_FILE_EXISTS
    dec a
    jp z,THROW_STRING_TOO_LONG
    jp THROW_DISK_ERROR

_OEMC_USBCD_END:
    pop hl
    inc hl
    or a
    ret

    ;--- Print the current directory

OEMC_USBCD_PRINT:
    push hl

    push iy
    pop de
    ld ix,DSK_READ_CURDIR_FILE
    call OEM_CALL_BANK_1
    dec a
    jp z,THROW_DISK_ERROR

    ld a,'/'
    call CHPUT
    push iy
    pop hl
    call OEM_PRINT
    ld hl,OEM_S_CRLF
    call OEM_PRINT

    ld ix,DSK_REMOUNT
    call OEM_CALL_BANK_1

    pop hl
    ret


; -----------------------------------------------------------------------------
; Call a routine in the ROM bank 1 preserving IY
;
; Input:  IX = Routine address
;         AF, BC, DE, HL: Depends on the routine
; Output: AF, BC, DE, HL: Depends on the routine

OEM_CALL_BANK_1:
    push iy
    ld iy,ROM_BANK_1
    call CALL_BANK
    pop iy
    ret


; -----------------------------------------------------------------------------
; Convert a string to uppercase (ASCII characters only)
; Input: HL = Address of string

OEM_TOUPPER:
    push af
    push hl
_OEM_TOUPPER:
    ld a,(hl)
    or a
    jr z,_TOUPPER_END
    cp 'a'
    jr c,_TOUPPER_NEXT
    cp 'z'+1
    jr nc,_TOUPPER_NEXT
    and 0DFh
    ld (hl),a
_TOUPPER_NEXT:
    inc hl
    jr _OEM_TOUPPER
_TOUPPER_END:
    pop hl
    pop af
    ret


; -----------------------------------------------------------------------------
; Call a routine in the BASIC interpreter preserving IY
;
; Input:  IX = Routine address
;         AF, BC, DE, HL: Depends on the routine
; Output: AF, BC, DE, HL: Depends on the routine

OEM_CALBAS:
    push iy
    call CALBAS
    pop iy
    ret


; -----------------------------------------------------------------------------
; Throw various BASIC errors

THROW_FILE_EXISTS:
    ld e,65
    jr BASIC_ERR
THROW_STRING_TOO_LONG:
    ld e,15
    jr BASIC_ERR
THROW_TYPE_MISMATCH:
    ld e,13
    jr BASIC_ERR
THROW_ILLEGAL_FN_CALL:
    ld e,5
    jr BASIC_ERR
THROW_SYNTAX_ERROR:
    ld e,2
    jr BASIC_ERR
THROW_DIR_NOT_FOUND:
    ld e,74
    ld a,(0F313h)
    or a
    jr nz,BASIC_ERR
THROW_FILE_NOT_FOUND:
    ld e,53
    jr BASIC_ERR
THROW_DISK_ERROR:
    ld e,69

BASIC_ERR:
    ld a,(0F313h)
    or a
    jr nz,BASIC_ERR2

    ld bc,0
    xor a
    ld (NLONLY),a		; not loading basic program, close i/o channels when requested
    ld (FLBMEM),a		; ascii mode
    push de
    ld ix,6B24h
    call CALBAS
    pop	de

BASIC_ERR2:
    ld ix,406fh
    jp CALBAS


; -----------------------------------------------------------------------------
; Print the description of an USB error code
;
; Input: A = USB error code

PRINT_ERROR_DESCRIPTION:
    cp USB_ERR_MAX+1
    jp nc,OEM_PRINTHEX

    dec a
    ld c,a
    sla c
    ld b,0
    ld hl,USBERR_S_TABLE
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jp OEM_PRINT

USBERR_S_TABLE:
    dw USBERR_S_1
    dw USBERR_S_2
    dw USBERR_S_3
    dw USBERR_S_4
    dw USBERR_S_5
    dw USBERR_S_6
    dw USBERR_S_7

USBERR_S_1: db "NAK",0
USBERR_S_2: db "Stall",0
USBERR_S_3: db "Timeout",0
USBERR_S_4: db "Data error",0
USBERR_S_5: db "Device was disconnected",0
USBERR_S_6: db "Panic button pressed",0
USBERR_S_7: db "Unexpected status received from USB host hardware",0


; -----------------------------------------------------------------------------
; Print a byte in hexadecimal format
;
; Input: A = byte to print

OEM_PRINTHEX:
    push af
	call	_OEM_PRINTHEX_1
	pop af
	jr	_OEM_PRINTHEX_2

_OEM_PRINTHEX_1:	rra
	rra
	rra
	rra
_OEM_PRINTHEX_2:	or	0F0h
	daa
	add	a,0A0h
	adc	a,40h

	call CHPUT
	ret


; -----------------------------------------------------------------------------
; Print a zero-terminated string
;
; Input: HL = Pointer to the string

OEM_PRINT:
	ld a,(hl)
	or a
	ret z
	call CHPUT
	inc hl
	jr OEM_PRINT