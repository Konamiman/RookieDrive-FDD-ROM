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

    if USE_ALTERNATIVE_PORTS
    db "USBRESET2",0
    dw OEMC_USBRESET
    db "USBERROR2",0
    dw OEMC_USBERROR
    db "USBMENU2",0
    dw OEMC_USBMENU
    db "USBCD2",0
    dw OEMC_USBCD
    db "USBMOUNT2",0
    dw OEMC_USBMOUNT
    db "USBMOUNTR2",0
    dw OEMC_USBMOUNTR
    db "USBFILES2",0
    dw OEMC_USBFILES
    db "USBFDDMODE2",0
    dw OEMC_USBFDDMODE
    else
    db "USBRESET",0
    dw OEMC_USBRESET
    db "USBERROR",0
    dw OEMC_USBERROR
    db "USBMENU",0
    dw OEMC_USBMENU
    db "USBCD",0
    dw OEMC_USBCD
    db "USBMOUNT",0
    dw OEMC_USBMOUNT
    db "USBMOUNTR",0
    dw OEMC_USBMOUNTR
    db "USBFILES",0
    dw OEMC_USBFILES
    db "USBFDDMODE",0
    dw OEMC_USBFDDMODE
    endif

    db "USBHELP",0
    dw OEMC_USBHELP
    db 0

    ;--- CALL USBHELP
    ;    Show info on available CALL commands

OEMC_USBHELP:
    ld hl,OEM_S_HELP
    call OEM_PRINT
    jp OEM_END

OEM_S_HELP:
    ;   ----------------------------------------
    if USE_ALTERNATIVE_PORTS
    db "_USBRESET2 - Re-initialize device",13,10
    db 13,10
    db "FDD device only:",13,10
    db "_USBERROR2 - Show last ASC/ASCQ err",13,10
    db 13,10
    db "Storage device only:",13,10
    db "_USBMENU2 - Show file navig menu",13,10
    db "_USBCD2 - Show current dir",13,10
    ;db"_USBCD2("dir/dir") - Change dir, rel",13,10
    db "_USBCD2(",34,"dir/dir",34,") - Change dir, rel",13,10
    ;db"_USBCD2("/dir/dir") - Change dir (abs)",13,10
    db "_USBCD2(",34,"/dir/dir",34,") - Change dir,abs",13,10
    db "_USBFILES2 - List files in curr dir",13,10
    db "_USBMOUNT2 - Show mounted file name",13,10
    ;db"_USBMOUNT2("file.ext") - Mount file",13,10
    db "_USBMOUNT2(",34,"file.ext",34,") - Mount file",13,10
    db "_USBMOUNT2(-1) - Unmount file",13,10
    db "_USBMOUNT2(0) - Mount default file",13,10
    db "_USBMOUNT2(n) - Mount nth file, 1-255",13,10
    db "_USBMOUNTR2(...) - Mount and reset",13,10
    db "_USBFDDMODE2(n) - n=0: normal, 1/2: force 1DD/2DD mode",13,10 
    else
    db "_USBRESET - Re-initialize device",13,10
    db 13,10
    db "FDD device only:",13,10
    db "_USBERROR - Show last ASC/ASCQ error",13,10
    db 13,10
    db "Storage device only:",13,10
    db "_USBMENU - Show file navigation menu",13,10
    db "_USBCD - Show current dir",13,10
    ;db"_USBCD("dir/dir") - Change dir, rel",13,10
    db "_USBCD(",34,"dir/dir",34,") - Change dir, rel",13,10
    ;db"_USBCD("/dir/dir") - Change dir (abs)",13,10
    db "_USBCD(",34,"/dir/dir",34,") - Change dir, abs",13,10
    db "_USBFILES - List files in curr dir",13,10
    db "_USBMOUNT - Show mounted file name",13,10
    ;db"_USBMOUNT("file.ext") - Mount file",13,10
    db "_USBMOUNT(",34,"file.ext",34,") - Mount file",13,10
    db "_USBMOUNT(-1) - Unmount file",13,10
    db "_USBMOUNT(0) - Mount default file",13,10
    db "_USBMOUNT(n) - Mount nth file, 1-255",13,10
    db "_USBMOUNTR(...) - Mount and reset",13,10
    db "_USBFDDMODE(n) - n=0: normal, 1/2: force 1DD/2DD mode",13,10 
    endif
    db 0


    ;--- CALL USBRESET
    ;    Resets USB hardware and prints device info, just like at boot time

OEMC_USBRESET:
    ld ix,VERBOSE_RESET
    call OEM_CALL_BANK_1
    ld ix,WK_GET_STORAGE_DEV_FLAGS
    call OEM_CALL_BANK_1
    jp z,OEM_END
    ld a,1
    ld ix,DSK_DO_BOOT_PROC
    call OEM_CALL_BANK_1
    jp OEM_END


    ;--- CALL USBERROR
    ;    Displays information about the USB or UFI error returned
    ;    by the last executed UFI command

OEMC_USBERROR:
    ld ix,WK_GET_STORAGE_DEV_FLAGS
    call OEM_CALL_BANK_1
    jp nz,THROW_ILLEGAL_FN_CALL

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
    

; -----------------------------------------------------------------------------
; Make sure that a storage device is connected, throw an error if not.

OEMC_ENSURE_STORAGE_DEVICE:
    push ix
    push hl
    ld ix,USB_CHECK_DEV_CHANGE
    call OEM_CALL_BANK_1
    ld ix,WK_GET_STORAGE_DEV_FLAGS
    call OEM_CALL_BANK_1
    pop hl
    pop ix
    jp z,THROW_ILLEGAL_FN_CALL
    ret


    ;--- CALL USBMENU
    ;    Open the USB menu if there's a storage device inserted

OEMC_USBMENU:
    call OEMC_ENSURE_STORAGE_DEVICE

    ld a,1
    ld ix,DO_BOOT_MENU
    call OEM_CALL_BANK_1
    cp 3
    jp z,THROW_ILLEGAL_FN_CALL
    cp 2
    jp z,THROW_OUT_OF_MEMORY
    jp OEM_END


    ;--- CALL USBMOUNTR:
    ;    Same as USBMOUNT but resets the machine afterwards
    ;    (it doesn't support the "Show file currently mounted" mode)

OEMC_USBMOUNTR:
    pop hl
    ld b,1
    call _OEMC_USBMOUNT_COMMON

    ld ix,DSK_CREATE_TMP_BOOT_FILE
    call OEM_CALL_BANK_1
    or a
    jp nz,THROW_DISK_ERROR
    
    ld iy,(EXPTBL-1)
    ld ix,0
    jp CALSLT


    ;--- CALL USBMOUNT - Show file currently mounted
    ;    CALL USBMOUNT(-1) - Unmount file
    ;    CALL USBMOUNT(0) - Mount default file in current dir
    ;    CALL USBMOUNT(n) - Mount nth file in current dir
    ;    CALL USBMOUNT("file.ext") - Mount specified file in current dir

OEMC_USBMOUNT:
    pop hl
    ld b,0

_OEMC_USBMOUNT_COMMON:
    push hl
    push bc
    call OEMC_ENSURE_STORAGE_DEVICE
    pop bc
    pop hl

    push iy
    ld iy,-65
    add iy,sp
    ld sp,iy
    call _OEMC_USBMOUNT
    ld iy,65
    add iy,sp
    ld sp,iy
    pop iy

    or a
    ret

_OEMC_USBMOUNT:
    dec hl
    ld ix,CHRGTR
    push bc
    call OEM_CALBAS
    pop bc
    jp z,_OEMC_USBMOUNT_PRINT

    cp '('
    jp nz,THROW_SYNTAX_ERROR
    inc hl
    push hl ;Save BASIC text pointer in case we need to reevaluate expression
    ld ix,FRMEVL
    call OEM_CALBAS
    dec hl
    ld ix,CHRGTR
    call OEM_CALBAS
    cp ')'
    jp nz,THROW_SYNTAX_ERROR

    ld a,(VALTYP)
    cp 3
    jr z,_OEMC_USBMOUNT_BYNAME
    ex (sp),hl  ;Restore saved BASIC text pointer and at the same time save the current pointer
    ld ix,FRMQNT
    call OEM_CALBAS
    pop hl ;Restore the current pointer
    jr _OEMC_USBMOUNT_NUM

    ;--- Mount a file by name

_OEMC_USBMOUNT_BYNAME:
    pop bc  ;Discard saved BASIC text pointer
    push hl
    ld ix,FRESTR
    call OEM_CALBAS
    ex de,hl
    pop hl

    ;Here DE = Pointer to string descriptor

    push hl ;Save BASIC text pointer
    ex de,hl

    ld a,(hl)
    or a
    jp z,THROW_ILLEGAL_FN_CALL
    cp 12+1
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
    ldir
    xor a
    ld (de),a   ;IY contains now the zero-terminated string

_OEMC_USBMOUNT_BYNAME_GO:
    push iy
    pop hl
    call OEM_TOUPPER
    xor a
    ld ix,DSK_MOUNT
    call OEM_CALL_BANK_1
    or a
    jp z,_OEM_USBMOUNT_END

    push af
    ld ix,DSK_REMOUNT
    call OEM_CALL_BANK_1
    pop af
    dec a
    dec a
    jp z,THROW_FILE_NOT_FOUND
    dec a
    jp z,THROW_FILE_EXISTS
    jp THROW_DISK_ERROR

_OEMC_USBMOUNT_NUM:
    bit 7,d
    jr nz,_OEMC_USBMOUNT_UNMOUNT

    ld a,d
    or a
    jp nz,THROW_ILLEGAL_FN_CALL

    or e
    jr z,_OEMC_USBMOUNT_DEFAULT

    ;--- Mount Nth file in the directory

    push hl
    push de

    ld ix,DSK_REMOUNT_DIR
    call OEM_CALL_BANK_1
    or a
    jp nz,THROW_DISK_ERROR

    pop de
    ld a,e
    dec a
    push iy
    pop hl
    ld bc,14
    add hl,bc
    ld ix,HWF_FIND_NTH_FILE
    call OEM_CALL_BANK_1
    or a
    jr nz,_OEMC_USBMOUNT_DEFAULT_ERR

    push iy
    pop hl
    push hl
    pop de
    ld bc,14
    add hl,bc
    ld ix,BM_GENERATE_FILENAME
    call OEM_CALL_BANK_1

    jr _OEMC_USBMOUNT_BYNAME_GO

    ;--- Unmount currently mounted file

_OEMC_USBMOUNT_UNMOUNT:
    push hl

    ld ix,DSK_CLOSE_FILE
    call OEM_CALL_BANK_1

    jr _OEM_USBMOUNT_END

    ;--- Mount default file for directory

_OEMC_USBMOUNT_DEFAULT:
    push hl

    ld ix,DSK_REMOUNT_DIR
    call OEM_CALL_BANK_1
    or a
    jp nz,THROW_DISK_ERROR

    push iy
    pop hl
    ld ix,DSK_GET_DEFAULT
    call OEM_CALL_BANK_1
    or a
    jp z,_OEMC_USBMOUNT_BYNAME_GO

_OEMC_USBMOUNT_DEFAULT_ERR:
    dec a
    dec a
    jp z,THROW_FILE_NOT_FOUND
    jp THROW_DISK_ERROR

    ;--- Print currently mounted file

_OEMC_USBMOUNT_PRINT:
    ld a,b
    or a
    jp nz,THROW_SYNTAX_ERROR

    push hl

    call OEMC_ENSURE_STORAGE_DEVICE
    and 1
    jp z,THROW_FILE_NOT_FOUND

    push iy
    pop de
    ld ix,DSK_READ_CURFILE_FILE
    call OEM_CALL_BANK_1
    dec a
    jp z,THROW_DISK_ERROR
    dec a
    jp z,THROW_FILE_NOT_FOUND

    push iy
    pop hl
    call OEM_PRINT
    ld hl,OEM_S_CRLF
    call OEM_PRINT

    ld ix,DSK_REMOUNT
    call OEM_CALL_BANK_1

    pop hl
    ret

_OEM_USBMOUNT_END:
    pop hl
    inc hl
    ret


    ;--- CALL USBFDDMODE - Print the current USB FDD mode
    ;    CALL USBFDDMODE(0) - Set the default mode:
    ;                         decide if the disk is 1DD or 2DD depending on the media ID byte
    ;    CALL USBFDDMODE(1) - Assume all disks are 1DD
    ;    CALL USBFDDMODE(2) - Assume all disks are 2DD
OEMC_USBFDDMODE:
    pop hl

    dec hl
    ld ix,CHRGTR
    call OEM_CALBAS
    ;or a
    jr nz,_OEMC_USBFDDMODE_SET

    push hl
    ld ix,WK_GET_MISC_FLAGS
    call OEM_CALL_BANK_1
    rrca
    and 3
    add "0"
    call CHPUT
    or a
    pop hl
    ;inc hl
    ret

_OEMC_USBFDDMODE_SET:
    cp '('
    jp nz,THROW_SYNTAX_ERROR
    inc hl
    ld ix,GETBYT
    call OEM_CALBAS
    push af
    dec hl
    ld ix,CHRGTR
    call OEM_CALBAS
    cp ')'
    jp nz,THROW_SYNTAX_ERROR
    pop af
    rlca
    and 110b

    push hl
    push af
    ld ix,WK_GET_MISC_FLAGS
    call OEM_CALL_BANK_1
    and 1001b
    pop bc
    or b
    ld ix,WK_SET_MISC_FLAGS
    call OEM_CALL_BANK_1
    pop hl

    inc hl
    or a
    ret



    ;--- CALL USBCD - Print the current directory
    ;    CALL USBCD("dir/dir")  - Change to the specified relative directory
    ;    CALL USBCD("/dir/dir") - Change to the specified absolute directory

OEMC_USBCD:
    call OEMC_ENSURE_STORAGE_DEVICE

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


    ;--- CALL USBFILES - List files in current directory

OEMC_USBFILES:
    call OEMC_ENSURE_STORAGE_DEVICE

    push iy
    ld iy,-14-1
    add iy,sp
    ld sp,iy
    call _OEMC_USBFILES
    ld iy,14+1
    add iy,sp
    ld sp,iy
    pop iy

    jp OEM_END

_OEMC_USBFILES:

    ;Throw error if we have less than 1.5K of free space

    push hl
    ld hl,0
    add hl,sp
    ld de,(STREND)
    or a
    sbc hl,de
    ld a,h
    cp 6
    ld a,2
    pop de
    jp c,THROW_OUT_OF_MEMORY

    ;How many columns to show?

    ld a,(LINLEN)
    ld b,1
    cp 27
    jr c,_OEMC_USBFILES_SETCOLS
    inc b
    cp 40
    jr c,_OEMC_USBFILES_SETCOLS
    inc b
    cp 53
    jr c,_OEMC_USBFILES_SETCOLS
    inc b
    cp 66
    jr c,_OEMC_USBFILES_SETCOLS
    inc b
    cp 79
    jr c,_OEMC_USBFILES_SETCOLS
    inc b
_OEMC_USBFILES_SETCOLS:
    ld iyh,b

    ;How many files to list?

    ld bc,100   ;Work stack space
    or a
    sbc hl,bc
    push hl
    pop bc
    push de
    ld de,11
    ld ix,DIVIDE_16 ;Now BC = Files to enum
    call OEM_CALL_BANK_1
    pop de

    ;Get files

    push bc
    ld ix,DSK_REMOUNT_DIR
    call OEM_CALL_BANK_1
    pop bc

    ld hl,(STREND)
    ld ix,HWF_ENUM_FILES
    call OEM_CALL_BANK_1
    ld a,b
    or c
    jp z,THROW_FILE_NOT_FOUND

    ;Print files

    ld hl,(STREND)
    ld e,0
_OEMC_USBFILES_LOOP:
    ld a,e
    inc e
    cp iyh
    jr c,_OEMC_USBFILES_GO
    push hl
    ld hl,OEM_S_CRLF
    call OEM_PRINT
    pop hl
    ld e,1

_OEMC_USBFILES_GO:
    ld a,(hl)
    or a
    jr z,_OEMC_USBFILES_END

    push de
    ld ix,BM_PRINT_FILENAME
    call OEM_CALL_BANK_1
    pop de
_OEMC_USBFILES_PAD:
    ld a,c
    cp 13
    jr nc,_OEMC_USBFILES_LOOP
    ld a,' '
    call CHPUT
    inc c
    jr _OEMC_USBFILES_PAD

_OEMC_USBFILES_END:
    ld ix,DSK_REMOUNT
    call OEM_CALL_BANK_1
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

THROW_OUT_OF_MEMORY:
    ld e,7
    jr BASIC_ERR
THROW_DIR_EXISTS:
    ld e,73
    ld a,(0F313h)
    or a
    jr nz,BASIC_ERR
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