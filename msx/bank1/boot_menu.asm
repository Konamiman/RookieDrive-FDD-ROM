DO_BOOT_MENU:
    ld a,40
    ld (LINL40),a
    call INITXT

    ld h,1
    ld l,2
    call POSIT
    call _BM_DRAW_LINE
    ld h,1
    ld l,23
    call POSIT
    call _BM_DRAW_LINE

    ld h,1
    ld l,1
    call POSIT
    ld a,"/"
    call CHPUT

    ld h,1
    ld l,24
    call POSIT
    ld hl,_BM_F1_HELP
    call PRINT

_BOOT_MENU_LOOP:
    halt
    call BREAKX
    ret c
    jr _BOOT_MENU_LOOP

_BM_DRAW_LINE:
    ld b,40
_BM_DRAW_LINE_LOOP:
    ld a,"-"
    call CHPUT
    djnz _BM_DRAW_LINE_LOOP
    ret

_BM_F1_HELP:
    db "F1 = Help",0