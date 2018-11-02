; This code needs to exist in both ROM banks 0 and 1, and at the same address.
;
; Labels are defined at the main file, not here, so that this file can be included twice.

;CALL_IX:
    jp (ix)


; Call routine in another bank
; Input: IX = Routine address, IYl = Bank number, all others: input for the routine

;CALL_BANK:
    push hl
    ld hl,(7FFFh) ;L=Current bank
    ex (sp),hl
    push af
    ld a,iyl
    if USE_ASCII8_ROM_MAPPER=1
    sla a
    ld (6000h),a
    inc a
    ld (6800h),a
    else
    ld (6000h),a
    endif
    pop af
    call CALL_IX
    ex (sp),hl  ;L=Previous bank
    push af
    ld a,l
    if USE_ASCII8_ROM_MAPPER=1
    sla a
    ld (6000h),a
    inc a
    ld (6800h),a
    else
    ld (6000h),a
    endif
    pop af
    pop hl
    ret


