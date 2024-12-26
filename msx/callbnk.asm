; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the code to call a routine in another ROM bank.
; This code needs to exist in both ROM banks 0 and 1, and at the same address.
;
; Labels are defined at the main file, not here, so that this file can be included twice.

; crisag - Key Changes:
; - Bank switching now uses Konami SCC mapper addresses:
;   5000h-57FFh for 4000h-5FFFh region
;   7000h-77FFh for 6000h-7FFFh region
; - Fixed banks 0 (0000h-3FFFh) and 2 (8000h-FFFFh) are assumed.
; - Ensures correct switching before and after the routine call.

;CALL_IX:
    jp (ix)


; Call a routine in another bank
; Input:  IX = Routine address
;         IYl = Bank number
;         All others registers = input for the routine
; Output: All registers = output from the routine

;CALL_BANK:
    push hl     ; Save HL (used to track the current bank)
    ld hl,(7FFFh)   ; Load the current bank number into HL (L=Current bank)
    ex (sp),hl  ; Swap HL with the top of the stack (store previous bank)
    push af     ; Save AF (to preserve flags)

    ; Switch to the target bank
    ld a,iyl    ; Load the target bank number into A
    if USE_ALTERNATIVE_PORTS=1
    or 80h
    endif
    if USE_ASCII8_ROM_MAPPER=1
    sla a
    ld (ROM_BANK_SWITCH),a
    inc a
    ld (6800h),a
    else
    ld (ROM_BANK_SWITCH),a
    endif
    pop af
    call CALL_IX
    ex (sp),hl  ;L=Previous bank
    push af
    ld a,l
    if USE_ALTERNATIVE_PORTS=1
    or 80h
    endif
    if USE_ASCII8_ROM_MAPPER=1
    sla a
    ld (ROM_BANK_SWITCH),a
    inc a
    ld (6800h),a
    else
    ld (ROM_BANK_SWITCH),a
    endif
    pop af
    pop hl
    ret


