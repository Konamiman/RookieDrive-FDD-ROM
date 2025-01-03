; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the choice string for the FORMAT command.
; It needs to be in a separate file because FORMAT lives in ROM bank 1,
; but this string needs to be in bank 0.

CHOICE_S:
    db "1 - 360K, full format",13,10
    db "2 - 360K, quick format",13,10
    db "3 - 720K, full format",13,10
    db "4 - 720K, quick format",13,10
    db "5 - 1.44M, full format",13,10
    db "6 - 1.44M, quick format",13,10
    db 0
