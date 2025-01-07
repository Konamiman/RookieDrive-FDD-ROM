; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the code to call a routine in another ROM bank.
; This code needs to exist in both ROM banks 0 and 1, and at the same address.
;
; Labels are defined at the main file, not here, so that this file can be included twice.

;CALL_IX:
    jp (ix)


; Call a routine in another bank
; Input:  IX = Routine address
;         IYl = Bank number
;         All others registers = input for the routine
; Output: All registers = output from the routine

;CALL_BANK:
    push hl
    ld hl,(7FFFh) ;L=Current bank
    ex (sp),hl
    push af
    ld a,iyl
    if USE_ALTERNATIVE_PORTS
    or 80h
    endif
    if USE_ASCII8_ROM_MAPPER
    sla a
    ld (ROM_BANK_SWITCH),a
    inc a
    ld (6800h),a
    else
    ld (ROM_BANK_SWITCH),a
    endif
    if USE_KONAMISCC_ROM_MAPPER
    sla a
    ld (ROM_BANK_SWITCH),a
    inc a
    ld (7000h),a
    endif
    pop af
    call CALL_IX
    ex (sp),hl  ;L=Previous bank
    push af
    ld a,l
    if USE_ALTERNATIVE_PORTS
    or 80h
    endif
    if USE_ASCII8_ROM_MAPPER
    sla a
    ld (ROM_BANK_SWITCH),a
    inc a
    ld (6800h),a
    else
    ld (ROM_BANK_SWITCH),a
    endif
    if USE_KONAMISCC_ROM_MAPPER
    sla a
    ld (ROM_BANK_SWITCH),a
    inc a
    ld (7000h),a
    endif
    pop af
    pop hl
    ret


