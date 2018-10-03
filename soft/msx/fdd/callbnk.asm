; This code needs to exist in both ROM banks 0 and 1, and at the same address.
;
; Labels are defined at the main file, not here, so that this file can be included twice.

;CALL_IX:
    jp (ix)


; Call routine in bank 1
; Input: IX = Routine address, all others: input for the routine

;CALL_BANK_1:
    push af
    ld a,1
    ld (6000h),a
    pop af
    call CALL_IX
    push af
    xor a
    ld (6000h),a
    pop af
    ret
