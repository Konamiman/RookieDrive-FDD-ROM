; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file defines a ROM header for bank 1, it simply jumps to the initialization
; routine for bank 0. This header is needed to ensure that the ROM will boot properly
; even if for some reason the computer resets while executing code in bank 1.

    db "AB"
    dw BANK1_INIT
    ds 12

BANK1_INIT:
    ld hl,BANK1_INIT_DO
    ld de,0C000h
    ld bc,BANK1_INIT_DO_END - BANK1_INIT_DO
    ldir
    jp 0C000h

BANK1_INIT_DO:
    xor a
    ld (ROM_BANK_SWITCH),a
    ld hl,(4002h)
    jp (hl)
BANK1_INIT_DO_END:
