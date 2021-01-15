BM_FILES_BASE: equ 8000h

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

    ld h,2
    ld l,1
    call POSIT
    ld a,"/"
    call CHPUT

    ld hl,BM_SCANNING_DIR_S
    call BM_PRINT_STATUS

    ld hl,BM_FILES_BASE
    ld bc,1300
    call HWF_ENUM_FILES

    ld a,1
    ld (BM_CUR_PAGE),a

    ld (BM_NUM_FILES),bc
    push bc
    pop hl
    ld b,0
_BM_CALC_NUM_PAGES:
    ld a,h
    or a
    jr nz,_BM_CALC_NUM_PAGES_ADD
    ld a,l
    or a
    jr z,_BM_CALC_NUM_PAGES_END
    cp 60
    jr nc,_BM_CALC_NUM_PAGES_ADD

    inc b
    jr _BM_CALC_NUM_PAGES_END

_BM_CALC_NUM_PAGES_ADD:
    inc b
    ld de,60
    or a
    sbc hl,de
    jr _BM_CALC_NUM_PAGES

_BM_CALC_NUM_PAGES_END:
    ld a,b
    or a
    jr nz,_BM_CALC_NUM_PAGES_END_2
    inc a
_BM_CALC_NUM_PAGES_END_2:
    ld (BM_NUM_PAGES),a

BM_ENTER_MAIN_LOOP:
    call BM_CLEAR_INFO_AREA
    call BM_PRINT_MAIN_STATUS

    call BM_PRINT_FILENAMES_PAGE

;--- Main loop

BOOT_MENU_LOOP:
    halt
    call BREAKX
    ret c

    call BM_F1_IS_PRESSED
    jp z,BM_DO_HELP

    call BM_CURSOR_IS_PRESSED
    bit 7,a
    jp nz,BM_UPDATE_PAGE

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

    jp BM_ENTER_MAIN_LOOP

;--- Update current page on cursor press
;    Input: A = pressed cursor key

BM_UPDATE_PAGE:
    and 7Fh
    dec a
    jr z,_BM_NEXT_10_PAGES
    dec a
    jr z,_BM_NEXT_PAGE
    dec a
    jr z,_BM_PREV_10_PAGES
    dec a
    jr z,_BM_PREV_PAGE
    jp BOOT_MENU_LOOP

_BM_NEXT_PAGE:
    ld a,(BM_NUM_PAGES)
    ld b,a
    ld a,(BM_CUR_PAGE)
    cp b
    jp z,BOOT_MENU_LOOP

    inc a
    ld (BM_CUR_PAGE),a
    jp BM_ENTER_MAIN_LOOP

_BM_NEXT_10_PAGES:
    ld a,(BM_NUM_PAGES)
    ld b,a
    ld a,(BM_CUR_PAGE)
    cp b
    jp nc,BOOT_MENU_LOOP
    inc b
    add 10
    cp b
    jr c,_BM_NEXT_10_PAGES_GO
    ld a,(BM_NUM_PAGES)

_BM_NEXT_10_PAGES_GO:
    ld (BM_CUR_PAGE),a
    jp BM_ENTER_MAIN_LOOP

_BM_PREV_PAGE:
    ld a,(BM_CUR_PAGE)
    cp 1
    jp z,BOOT_MENU_LOOP

    dec a
    ld (BM_CUR_PAGE),a
    jp BM_ENTER_MAIN_LOOP

_BM_PREV_10_PAGES:
    ld a,(BM_CUR_PAGE)
    cp 1
    jp z,BOOT_MENU_LOOP
    sub 10
    jr z,_BM_PREV_10_PAGES_1
    jp p,_BM_PREV_10_PAGES_GO
_BM_PREV_10_PAGES_1:    
    ld a,1

_BM_PREV_10_PAGES_GO:
    ld (BM_CUR_PAGE),a
    jp BM_ENTER_MAIN_LOOP

;--- Print a screen full of filenames
;    Input: A = Page number

BM_PRINT_FILENAMES_PAGE:
    ld hl,(BM_NUM_FILES)
    ld a,h
    or l
    jp nz,_BM_PRINT_FILENAMES_PAGE_GO

    ld h,3
    ld l,12
    call POSIT
    ld hl,BM_NO_FILES_S
    jp PRINT

_BM_PRINT_FILENAMES_PAGE_GO:
    ld a,(BM_CUR_PAGE)
    ld b,a
    ld hl,BM_FILES_BASE-11*60
    ld de,11*60
_BM_PRINT_FILENAMES_CALC:
    add hl,de
    djnz _BM_PRINT_FILENAMES_CALC

    call BM_CLEAR_INFO_AREA

    ld b,2  ;X coordinate
_BM_PRINT_FILENAMES_COLUMN:
    ld c,3  ;Y coordinate

    push hl
    ld h,b
    ld l,c
    call POSIT
    pop hl

_BM_PRINT_FILENAMES_COLUMN_LOOP:
    ld a,(hl)
    or a
    ret z   ;End of the files list reached

    push bc
    call BM_PRINT_FILENAME
    pop bc
    inc c
    ld a,c
    cp 23
    jr nc,_BM_PRINT_FILENAMES_COLUMN_END

    push hl
    ld h,b
    ld l,c
    call POSIT
    pop hl

    jr _BM_PRINT_FILENAMES_COLUMN_LOOP

_BM_PRINT_FILENAMES_COLUMN_END:
    ld a,b
    add 13
    ld b,a
    cp 37
    jr c,_BM_PRINT_FILENAMES_COLUMN

    ret


;--- Print a fixed 11 chars file name in the current position
;    Input:  HL = Filename
;    Output: HL = Past the filename

BM_PRINT_FILENAME:
    ld b,8
_BM_PRINT_FILENAME_MAIN:
    ld a,(hl)
    inc hl
    cp ' '
    call nz,CHPUT
    djnz _BM_PRINT_FILENAME_MAIN

    ld a,(hl)
    cp ' '
    ld b,3
    jr z,_BM_PRINT_FILENAME_EXT
    ld a,'.'
    call CHPUT
_BM_PRINT_FILENAME_EXT:
    ld a,(hl)
    inc hl
    and 7Fh
    cp ' '
    call nz,CHPUT
    djnz _BM_PRINT_FILENAME_EXT

    dec hl
    ld a,(hl)
    inc hl
    and 80h
    ret z
    ld a,'/'
    jp CHPUT


;--- Clear the central information area

BM_CLEAR_INFO_AREA:
    push hl
    ld h,1
    ld l,3
    call POSIT
    pop hl
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
    ld h,2
    ld l,24
    call POSIT
    ld a,27
    call CHPUT
    ld a,'K'
    call CHPUT  ;Delete to end of line
    pop hl
    jp PRINT

;--- Print the main lower status line

BM_PRINT_MAIN_STATUS:
    ld hl,BM_F1_HELP
    call BM_PRINT_STATUS

BM_PRINT_PAGE_NUM:
    ld h,28
    ld l,24
    call POSIT
    ld hl,BM_PAGE_S
    call PRINT

    ld a,(BM_CUR_PAGE)
    call BM_PRINT_BYTE
    ld hl,BM_SPACE_AND_BAR
    call PRINT
    ld a,(BM_NUM_PAGES)
    jp BM_PRINT_BYTE

BM_PRINT_BYTE:
    ld ix,BM_BUF
    call BYTE2ASC
    ld (ix),0
    ld hl,BM_BUF
    jp PRINT

;--- Check if F1 is pressed

BM_F1_IS_PRESSED:
    ld de,2006h
    jp BM_KEY_CHECK

;--- Check if a cursor key is pressed
;    Output: A=0: no
;              1,2,3,4: up,right,down,left
;            Bit 7 set if SHIFT is pressed too

BM_CURSOR_IS_PRESSED:
    ld hl,NEWKEY
    ld de,8
    add hl,de
    ld a,(hl)

    rlca
    ld b,2
    jr nc,_BM_CURSOR_IS_PRESSED_END
    rlca
    ld b,3
    jr nc,_BM_CURSOR_IS_PRESSED_END
    rlca
    ld b,1
    jr nc,_BM_CURSOR_IS_PRESSED_END
    rlca
    ld b,4
    jr nc,_BM_CURSOR_IS_PRESSED_END

    xor a
    ret

_BM_CURSOR_IS_PRESSED_END:
    dec hl
    dec hl  ;Row 6
    ld a,(hl)
    cpl
    rrca
    and 80h
    or b
    push af
    inc hl
    inc hl

_BM_CURSOR_WAIT_RELEASE:
    halt
    ld a,(hl)
    cpl
    and 11110000b
    jr z,_BM_CURSOR_WAIT_RELEASE

    pop af
    ret


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
    ld hl,NEWKEY
    add hl,de
    ld a,(hl)
    and b
    ret nz

_BM_KEY_CHECK_WAIT_RELEASE:
    halt
    ld a,(hl)
    and b
    jr z,_BM_KEY_CHECK_WAIT_RELEASE
    xor a
    ret

;--- Convert a 1-byte number to an unterminated ASCII string
;    Input:  A  = Number to convert
;            IX = Destination address for the string
;    Output: IX points after the string
;    Modifies: AF, C

BYTE2ASC:  cp  10
  jr  c,B2A_1D
  cp  100
  jr  c,B2A_2D
  cp  200
  jr  c,B2A_1XX
  jr  B2A_2XX

  ; One digit

B2A_1D:  add  "0"
  ld  (ix),a
  inc  ix
  ret

  ; Two digits

B2A_2D:  ld  c,"0"
B2A_2D2:  inc  c
  sub  10
  cp  10
  jr  nc,B2A_2D2

  ld  (ix),c
  inc  ix
  jr  B2A_1D

  ; Between 100 and 199

B2A_1XX:  ld  (ix),"1"
  sub  100
B2A_XXX:  inc  ix
  cp  10
  jr  nc,B2A_2D  ;If 1XY with X>0
  ld  (ix),"0"  ;If 10Y
  inc  ix
  jr  B2A_1D

  ;--- Between 200 and 255

B2A_2XX:  ld  (ix),"2"
  sub  200
  jr  B2A_XXX

;--- Strings

BM_F1_HELP:
    db "F1 = Help",0

BM_F1_NEXT:
    db "F1 = Next",0

BM_F1_END:
    db "F1 = End",0

BM_PAGE_S:
    db "Page ",0

BM_SPACE_AND_BAR:
    db " / ",0

BM_NO_FILES_S:
    db "No files found in current directory!",0

BM_SCANNING_DIR_S:
    db "Scanning directory...",0

BM_HELP_1:
    db " Cursors: select file or directory",13,10
    db 13,10
    db " SHIFT+Right/Left: Next/prev page",13,10
    db 13,10
    db " SHIFT+Up/Down: Up/down 10 pages",13,10
    db 13,10
    db " Enter (on file): Mount file and boot",13,10
    db 13,10
    db " Enter (on dir): Enter directory",13,10
    db 13,10
    db " SHIFT+Enter (on dir):",13,10
    db "   Mount first file on dir and boot",13,10
    db 13,10
    db " BS: Back to parent directory",13,10
    db 13,10
    db " F5: Reset device and start over",13,10
    db 13,10
    db " CTRL+STOP: Exit without any mounting"
    db 0

BM_HELP_2:
    db " After boot it is possible to switch",13,10
    db " to another disk image file from the",13,10
    db " same directory (up to 36 files).",13,10
    db 13,10
    db " On disk access press the key for the",13,10
    db " file (1-0, A-Z), or press CODE/KANA",13,10
    db " and when CAPS blinks press the key."
    db 0

    ;--- Variable definition

_BM_VARS_BASE: equ 0E000h

BM_NUM_PAGES: equ _BM_VARS_BASE
BM_CUR_PAGE:  equ BM_NUM_PAGES+1
BM_NUM_FILES: equ BM_CUR_PAGE+1
BM_BUF: equ BM_NUM_FILES+2
