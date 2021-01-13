DO_BOOT_MENU:
    ld a,40
    ld (LINL40),a
    call INITXT

    ld h,1
    ld l,2
    call POSIT
    call BM_DRAW_LINE
    ld h,1
    ld l,23
    call POSIT
    call BM_DRAW_LINE

    ld h,1
    ld l,1
    call POSIT
    ld a,"/"
    call CHPUT

    ld hl,BM_F1_HELP
    call BM_PRINT_STATUS

;--- Main loop

BOOT_MENU_LOOP:
    halt
    call BREAKX
    ret c

    call BM_F1_IS_PRESSED
    call z,BM_DO_HELP

    jr BOOT_MENU_LOOP

;--- Help loop

BM_DO_HELP:
    call BM_CLEAR_INFO_AREA

    ld h,1
    ld l,4
    call POSIT
    ld hl,BM_HELP_1
    call PRINT

    ld hl,BM_F1_NEXT
    call BM_PRINT_STATUS

_BM_HELP_LOOP1:
    ;halt
    call BM_F1_IS_PRESSED
    jr nz,_BM_HELP_LOOP1

    call BM_CLEAR_INFO_AREA

    ld h,1
    ld l,4
    call POSIT
    ld hl,BM_HELP_2
    call PRINT

    ld hl,BM_F1_END
    call BM_PRINT_STATUS

_BM_HELP_LOOP2:
    ;halt
    call BM_F1_IS_PRESSED
    jr nz,_BM_HELP_LOOP2

    call BM_CLEAR_INFO_AREA

    ld hl,BM_F1_HELP
    call BM_PRINT_STATUS

    ret

;--- Clear the central information area

BM_CLEAR_INFO_AREA:
    ld h,1
    ld l,3
    call POSIT
    ld b,20
_BM_CLEAR_INFO_AREA_LOOP:
    ld a,27
    call CHPUT
    ld a,'K'
    call CHPUT  ;Delete to end of line
    ld a,10
    call CHPUT
    djnz _BM_CLEAR_INFO_AREA_LOOP
    ret

;--- Print something in the lower status line

BM_PRINT_STATUS:
    push hl
    ld h,1
    ld l,24
    call POSIT
    ld a,27
    call CHPUT
    ld a,'K'
    call CHPUT  ;Delete to end of line
    pop hl
    jp PRINT

;--- Check if F1 is pressed

BM_F1_IS_PRESSED:
    ld de,2006h
    jp BM_KEY_CHECK

;--- Draw a horizontal line of 40 hyphens

BM_DRAW_LINE:
    ld b,40
_BM_DRAW_LINE_LOOP:
    ld a,"-"
    call CHPUT
    djnz _BM_DRAW_LINE_LOOP
    ret

;--- Check if a key is pressed
;Input:  D=column mask, E=row number
;Output: Z if pressed, NZ if not
BM_KEY_CHECK:
    ld b,d
    ld d,0
    ;ld hl,OLDKEY
    ;add hl,de
    ;ld a,(hl)
    ;cpl
    ;and b
    ;ld c,a
    ld hl,NEWKEY
    add hl,de
    ld a,(hl)
    and b
    ;or c
    ret nz

_BM_KEY_CHECK_WAIT_RELEASE:
    halt
    ld a,(hl)
    and b
    jr z,_BM_KEY_CHECK_WAIT_RELEASE
    xor a
    ret

;--- Strings

BM_F1_HELP:
    db "F1 = Help",0

BM_F1_NEXT:
    db "F1 = Next",0

BM_F1_END:
    db "F1 = End",0

BM_HELP_1:
    db "Cursors: select file or directory",13,10
    db 13,10
    db "SHIFT+Right/Left: Next/prev page",13,10
    db 13,10
    db "SHIFT+Up/Down: Up/down 10 pages",13,10
    db 13,10
    db "Enter (on file): Mount file and boot",13,10
    db 13,10
    db "Enter (on dir): Enter directory",13,10
    db 13,10
    db "SHIFT+Enter (on dir):",13,10
    db "  Mount first file on dir and boot",13,10
    db 13,10
    db "BS: Back to parent directory",13,10
    db 13,10
    db "F5: Reset device and start over",13,10
    db 13,10
    db "CTRL+STOP: Exit without any mounting"
    db 0

BM_HELP_2:
    db "After boot it is possible to switch",13,10
    db "to another disk image file from the",13,10
    db "same directory (up to 36 files).",13,10
    db 13,10
    db "On disk access press the key for the",13,10
    db "file (1-0, A-Z), or press CODE/KANA",13,10
    db "and when CAPS blinks press the key."
    db 0

_BM_VARS_BASE: equ 0E000h
