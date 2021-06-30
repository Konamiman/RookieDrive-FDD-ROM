; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the implementation of the INIHRD and INIENV
; driver routines.


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

INIHRD_IMPL:
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

INIENV_IMPL:

    if WAIT_KEY_ON_INIT = 1
    ld hl,INIHRD_NEXT
    push hl
    endif

    xor a
    call WK_SET_LAST_REL_DRIVE

    call VERBOSE_RESET
    ld b,30
DELAY_AFTER_PRINT:
    halt
    djnz DELAY_AFTER_PRINT
    call WK_GET_STORAGE_DEV_FLAGS
    ret z
    xor a
    jp DSK_DO_BOOT_PROC
