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
; Output:	Cy=0 if USB hardware is operational, 1 if not
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

INIHRD_IMPL:
    call INITXT
    ld hl,ROOKIE_S
    call PRINT

    call HW_TEST
    ret nc

    ld hl,NOHARD_S
    call PRINT
    ld b,60
    call DELAY_B

    scf
    ret


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

    if WAIT_KEY_ON_INIT
    ld hl,INIHRD_NEXT
    push hl
    endif

    xor a
    call WK_SET_LAST_REL_DRIVE

    if USE_ROM_AS_DISK = 0
    call VERBOSE_RESET
    endif
    
    ei
    ld b,30
    call DELAY_B
    call WK_GET_STORAGE_DEV_FLAGS
    ret z
    xor a
    jp DSK_DO_BOOT_PROC

DELAY_B:
    halt
    djnz DELAY_B
    ret
