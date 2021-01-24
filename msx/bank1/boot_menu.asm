; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the code for the boot menu that displays
; a navigable list of disk image files (available only when a
; standard USB mass storage device is plugged in).

BM_FILES_BASE: equ 8010h


; -----------------------------------------------------------------------------
; Boot menu entry point
; -----------------------------------------------------------------------------

DO_BOOT_MENU:

    xor a
    ld (BM_CURSOR_LAST),a
    ld (BM_NO_STOR_DEV),a

    ; Try opening DSK directory on the device

    if USE_FAKE_STORAGE_DEVICE = 0
    ld hl,BM_ROOT_DIR_S
    call HWF_OPEN_FILE_DIR
    dec a
    ret nz

    ld hl,BM_DSK_S
    call HWF_OPEN_FILE_DIR
    dec a
    ret nz
    endif

    ; Init screen mode, draw fixed elements

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

    ; Enumerate files, initialize paging

    ld a,1
    ld (BM_CUR_PAGE),a

    ld hl,BM_SCANNING_DIR_S
    call BM_PRINT_STATUS

    ld hl,BM_FILES_BASE
    ld bc,1290
    call HWF_ENUM_FILES
    ld (BM_NUM_FILES),bc
    push bc

    push hl ;Fill one extra page of 0s.
    pop de  ;This will be used to detect non-existing
    inc de  ;file positions in the last page.
    ld (hl),0
    ld bc,59*11-1
    ldir

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

    xor a
    ld (BM_CUR_ROW),a
    ld (BM_CUR_COL),a


; -----------------------------------------------------------------------------
; Main key scanning loop
; -----------------------------------------------------------------------------


;--- This entry point redraws the screen

BM_ENTER_MAIN_LOOP:
    call BM_CLEAR_INFO_AREA
    call BM_PRINT_MAIN_STATUS

    call BM_PRINT_FILENAMES_PAGE
    call BM_UPDATE_CUR_PAGE_PNT
    call BM_UPDATE_CUR_FILE_PNT
    call BM_POSIT_CUR_FILE
    call BM_PRINT_CURRENT_FILE_AS_SELECTED

;--- This is the actual start of the loop

_BM_MAIN_LOOP:
    halt
    call BREAKX
    ret c

    call BM_F5_IS_PRESSED
    jp z,BM_START_OVER

    ld a,(BM_NO_STOR_DEV)
    inc a
    jr z,_BM_MAIN_LOOP

    call BM_ENTER_IS_PRESSED
    jp z,BM_DO_ENTER

    call BM_F1_IS_PRESSED
    jp z,BM_DO_HELP

    call BM_CURSOR_IS_PRESSED
    or a
    jr z,_BM_MAIN_LOOP
    bit 7,a
    jp z,BM_UPDATE_CUR_FILE
    and 7Fh
    jp BM_UPDATE_PAGE

;--- Start over after F5 is pressed

BM_START_OVER:
    xor a
    ld (BM_NUM_FILES),a
    ld (BM_NUM_FILES+1),a
    inc a
    ld (BM_CUR_PAGE),a
    ld (BM_NUM_PAGES),a

    call BM_CLEAR_INFO_AREA
    ld hl,BM_RESETTING_DEVICE_S
    call BM_PRINT_STATUS

    call HWF_MOUNT_DISK
    jp nc,DO_BOOT_MENU

    ld a,0FFh
    ld (BM_NO_STOR_DEV),a
    ld hl,BM_NO_DEV_OR_NO_STOR_S
    call BM_PRINT_STATUS
    
    jp _BM_MAIN_LOOP


; -----------------------------------------------------------------------------
; Key press handlers
;
; These are JP-ed in, so they must finish by JP-ing to
; either BM_ENTER_MAIN_LOOP or _BM_MAIN_LOOP.
; -----------------------------------------------------------------------------


;--- ENTER key press handler

BM_DO_ENTER:
    ld hl,(BM_CUR_FILE_PNT)

    push hl
    pop ix
    bit 7,(ix+10)
    jp nz,_BM_MAIN_LOOP ;For now entering directories is not supported

    ld de,BM_BUF
    call BM_GENERATE_FILENAME
    ld hl,BM_BUF
    
    call HWF_OPEN_FILE_DIR
    or a
    jr z,_BM_DO_ENTER_FILE_IS_OPEN

    dec a
    jp z,_BM_MAIN_LOOP  ;TODO: handle entering directory

    dec a
    ld hl,BM_FILE_NOT_FOUND_S
    jr z,_BM_DO_ENTER_PRINT_ERR
    
    ld hl,BM_ERROR_OPENING_FILE_S
_BM_DO_ENTER_PRINT_ERR:
    call BM_PRINT_STATUS_WAIT_KEY
    call BM_PRINT_MAIN_STATUS

_BM_DO_ENTER_WAIT_RELEASE:  ;In case the "any key" pressed is enter
    call BM_ENTER_IS_PRESSED
    jr z,_BM_DO_ENTER_WAIT_RELEASE
    jp _BM_MAIN_LOOP

_BM_DO_ENTER_FILE_IS_OPEN:
    call WK_GET_STORAGE_DEV_FLAGS
    or 1    ;There's a file open
    call WK_SET_STORAGE_DEV_FLAGS
    ret ;Continue computer boot process

;--- Print the string HL in the status area and wait for a key press

BM_PRINT_STATUS_WAIT_KEY:
    call BM_PRINT_STATUS
    call KILBUF
    call CHGET  ;TODO: This displays cursor, somehow hide
    jp KILBUF


;--- Help loop, entered when F1 is pressed

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
    halt
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
    halt
    call BM_F1_IS_PRESSED
    jr nz,_BM_HELP_LOOP2

    jp BM_ENTER_MAIN_LOOP


;--- Update currently pointed file on cursor press
;    Input: A = pressed cursor key

BM_UPDATE_CUR_FILE:
    push af
    call BM_POSIT_CUR_FILE
    call BM_PRINT_CURRENT_FILE
    pop af
    
    dec a
    jr z,_BM_FILE_UP
    dec a
    jr z,_BM_FILE_RIGHT
    dec a
    jr z,_BM_FILE_DOWN

_BM_FILE_LEFT:
    ld a,(BM_CUR_COL)
    dec a
    cp 0FFh
    jr nz,_BM_UPDATE_CUR_COL_GO
    ld a,2
    jr _BM_UPDATE_CUR_COL_GO

_BM_FILE_RIGHT:
    ld a,(BM_CUR_COL)
    inc a
    cp 3
    jr c,_BM_UPDATE_CUR_COL_GO
    xor a
    jr _BM_UPDATE_CUR_COL_GO

_BM_FILE_UP:
    ld a,(BM_CUR_ROW)
    dec a
    cp 0FFh
    jr nz,_BM_UPDATE_CUR_ROW_GO
    ld a,19
    jr _BM_UPDATE_CUR_ROW_GO

_BM_FILE_DOWN:
    ld a,(BM_CUR_ROW)
    inc a
    cp 20
    jr c,_BM_UPDATE_CUR_ROW_GO
    xor a
    jr _BM_UPDATE_CUR_ROW_GO

_BM_UPDATE_CUR_COL_GO:
    ld (BM_CUR_COL),a
    ld hl,BM_CUR_COL
    ld (BM_BUF),hl
    jr _BM_UPDATE_CUR_ROWCOL_GO

_BM_UPDATE_CUR_ROW_GO:
    ld (BM_CUR_ROW),a
    ld hl,BM_CUR_ROW
    ld (BM_BUF),hl

_BM_UPDATE_CUR_ROWCOL_GO:
    call BM_UPDATE_CUR_FILE_PNT
    ld hl,(BM_CUR_FILE_PNT)
    ld a,(hl)
    or a
    jr nz,_BM_UPDATE_CUR_ROWCOL_GO_2
    ;We ended up pointing past the end of the list,
    ;so reset column/row to 0
    ld hl,(BM_BUF)
    ld (hl),0
    call BM_UPDATE_CUR_FILE_PNT

_BM_UPDATE_CUR_ROWCOL_GO_2:
    call BM_POSIT_CUR_FILE
    call BM_PRINT_CURRENT_FILE_AS_SELECTED
    jp _BM_MAIN_LOOP


;--- Update current page on cursor+SHIFT press
;    Input: A = pressed cursor key

BM_UPDATE_PAGE:
    dec a
    jr z,_BM_NEXT_10_PAGES
    dec a
    jr z,_BM_NEXT_PAGE
    dec a
    jr z,_BM_PREV_10_PAGES
    dec a
    jr z,_BM_PREV_PAGE
    jp _BM_MAIN_LOOP

_BM_NEXT_PAGE:
    ld a,(BM_NUM_PAGES)
    ld b,a
    ld a,(BM_CUR_PAGE)
    cp b
    jp z,_BM_MAIN_LOOP

    inc a
    ld (BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_NEXT_10_PAGES:
    ld a,(BM_NUM_PAGES)
    ld b,a
    ld a,(BM_CUR_PAGE)
    cp b
    jp nc,_BM_MAIN_LOOP
    inc b
    add 10
    cp b
    jr c,_BM_NEXT_10_PAGES_GO
    ld a,(BM_NUM_PAGES)

_BM_NEXT_10_PAGES_GO:
    ld (BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_PREV_PAGE:
    ld a,(BM_CUR_PAGE)
    cp 1
    jp z,_BM_MAIN_LOOP

    dec a
    ld (BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_PREV_10_PAGES:
    ld a,(BM_CUR_PAGE)
    cp 1
    jp z,_BM_MAIN_LOOP
    sub 10
    jr z,_BM_PREV_10_PAGES_1
    jp p,_BM_PREV_10_PAGES_GO
_BM_PREV_10_PAGES_1:    
    ld a,1

_BM_PREV_10_PAGES_GO:
    ld (BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_UPDATE_PAGE_END:
    xor a
    ld (BM_CUR_ROW),a
    ld (BM_CUR_COL),a
    jp BM_ENTER_MAIN_LOOP

; -----------------------------------------------------------------------------
; Screen printing routines
; -----------------------------------------------------------------------------


;--- Print the filenames for the current page

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


;--- Generate a formatted file name from one in dir entry format
;    Input:  HL = Pointer to filename in directory entry format
;                 (11 chars, name and extension padded with spaces)
;            DE = Destination buffer for the formatted file name
;    Output: HL = Points past the filename
;            DE = Points to the termination 0
;            C  = Length of the formatted file name

BM_GENERATE_FILENAME:
    ld ix,_BM_DO_LD_DE
    ld c,0
    call _BM_PRINTPUT_FILENAME
    xor a
    ld (de),a
    ret


;--- Print a formatted file name in the current position
;    Input:  HL = Pointer to filename in directory entry format
;                 (11 chars, name and extension padded with spaces)
;    Output: HL = Points past the filename
;            C  = Length of the printed file name

BM_PRINT_FILENAME:
    ld ix,_BM_DO_CHPUT


_BM_PRINTPUT_FILENAME:
    ld b,8
    ld c,0
_BM_PRINT_FILENAME_MAIN:
    ld a,(hl)
    inc hl
    cp ' '
    call nz,CALL_IX
    djnz _BM_PRINT_FILENAME_MAIN

    ld a,(hl)
    cp ' '
    ld b,3
    jr z,_BM_PRINT_FILENAME_EXT
    ld a,'.'
    call CALL_IX
_BM_PRINT_FILENAME_EXT:
    ld a,(hl)
    inc hl
    and 7Fh
    cp ' '
    call nz,CALL_IX
    djnz _BM_PRINT_FILENAME_EXT

    dec hl
    ld a,(hl)
    inc hl
    and 80h
    ret z
    ld a,'/'
    jp CALL_IX

_BM_DO_CHPUT:
    inc c
    jp CHPUT

_BM_DO_LD_DE:
    ld (de),a
    inc de
    inc c
    ret


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
;    Input: HL = Pointer to string to print

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
;    ("F1=HELP" and current page number)

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


;--- Draw a horizontal line of 40 hyphens in the current cursor location

BM_DRAW_LINE:
    ld b,40
_BM_DRAW_LINE_LOOP:
    ld a,"-"
    call CHPUT
    djnz _BM_DRAW_LINE_LOOP
    ret


;--- Position the cursor for the current file:
;    col = (BM_CUR_COL*13)+2
;    row = BM_CUR_ROW+3

BM_POSIT_CUR_FILE:
    ld a,(BM_CUR_COL)
    ld b,a
    sla a
    sla a
    sla a   ;*8
    add b
    add b
    add b
    add b
    add b   ;*13
    inc a
    inc a
    ld h,a
    ld a,(BM_CUR_ROW)
    add 3
    ld l,a
    jp POSIT


;--- Print the current filename at the current position

BM_PRINT_CURRENT_FILE:
    ld hl,(BM_CUR_FILE_PNT)
    call BM_PRINT_FILENAME
    ld b,' '
_BM_PRINT_CURRENT_FILE_PAD:
    ld a,c
    cp 12
    ret nc
    ld a,b
    call CHPUT
    inc c
    jr _BM_PRINT_CURRENT_FILE_PAD


;--- Print the current filename at the current position, as selected

    ;Generate the formatted file name in BM_BUF, padded with spaces

BM_PRINT_CURRENT_FILE_AS_SELECTED:
    ld hl,(BM_CUR_FILE_PNT)
    ld de,BM_BUF
    call BM_GENERATE_FILENAME

_BM_GEN_CURRENT_FILE_PAD:
    ld a,c
    cp 12
    jr nc,_BM_GEN_CURRENT_FILE_OK
    ld a,' '
    ld (de),a
    inc de
    inc c
    jr _BM_GEN_CURRENT_FILE_PAD
_BM_GEN_CURRENT_FILE_OK:

    ;Redefine chars 128-139 as the inverted chars of the filename

    ld hl,(TXTCGP)
    ld de,128*8
    add hl,de
    call SETWRT

    ld a,(VDP_DW)
    ld c,a      ;VDP write port

    ld hl,BM_BUF ;Pointer to current char
    ld b,12     ;How many chars left to invert
_BM_INVERT_CHARS_LOOP:
    push hl
    push bc
    ld e,(hl)
    ld d,0
    sla e
    rl d
    sla e
    rl d
    sla e
    rl d    ;DE = Current char *8
    ld hl,(CGTABL)
    add hl,de   ;HL = Pointer to start of char definition

    ld b,8
_BM_INVERT_ONE_CHAR_LOOP
    ld a,(hl)
    cpl
    out (c),a
    inc hl
    djnz _BM_INVERT_ONE_CHAR_LOOP

    pop bc
    pop hl
    inc hl
    djnz _BM_INVERT_CHARS_LOOP

    ;Print the inverted filename

    call BM_POSIT_CUR_FILE
    ld a,128
_BM_PRINT_INVERTED_LOOP:
    call CHPUT
    inc a
    cp 128+12
    jr c,_BM_PRINT_INVERTED_LOOP

    ret


; -----------------------------------------------------------------------------
; Keyboard scanning routines
; -----------------------------------------------------------------------------

;--- Check if a key is pressed
;    Input:  D = Keyboard matrix column mask, desired key set to 1
;            E = Keyboard matrix row number
;    Output: Z if key is pressed, NZ if not

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


;--- Check if F1 is pressed
;    Output: Z if pressed, NZ if not

BM_F1_IS_PRESSED:
    ld de,2006h
    jp BM_KEY_CHECK


;--- Check if F5 is pressed
;    Output: Z if pressed, NZ if not

BM_F5_IS_PRESSED:
    ld de,0207h
    jp BM_KEY_CHECK


;--- Check if ENTER is pressed
;    Output: Z if pressed, NZ if not

BM_ENTER_IS_PRESSED:
    ld de,8007h
    jp BM_KEY_CHECK
    ret nz

_BM_ENTER_IS_PRESSED_WAIT_RELEASE:
    ld de,8007h
    call BM_KEY_CHECK
    jr z,_BM_ENTER_IS_PRESSED_WAIT_RELEASE
    xor a
    ret


;--- Check if a cursor key is pressed
;    Output: A=0: no cursor key is pressed
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
    ld (BM_CURSOR_LAST),a
    ret

_BM_CURSOR_IS_PRESSED_END:
    ld a,(BM_CURSOR_LAST)
    or a
    ld a,0
    ret nz  ;Still pressed since last time

    inc a
    ld (BM_CURSOR_LAST),a

    dec hl
    dec hl  ;Row 6 (for SHIFT)
    ld a,(hl)
    cpl
    rrca
    and 80h
    or b
    ret


; -----------------------------------------------------------------------------
; Utility routines
; -----------------------------------------------------------------------------


;--- Update BM_CUR_PAGE_PNT as:
;    BM_FILES_BASE + ((BM_CUR_PAGE-1)*60)*11

BM_UPDATE_CUR_PAGE_PNT:
    ld hl,(BM_CUR_PAGE)
    ld h,0
    dec l
    call BM_MULT_60
    call BM_MULT_11
    ld de,BM_FILES_BASE
    add hl,de
    ld (BM_CUR_PAGE_PNT),hl
    ret


;--- Update BM_CUR_FILE_PNT as:
;    BM_CUR_PAGE_PNT + ((BM_CUR_COL*20) + BM_CUR_ROW)*11

BM_UPDATE_CUR_FILE_PNT:
    ld hl,(BM_CUR_COL)
    ld h,0
    call BM_MULT_20
    ld de,(BM_CUR_ROW)
    ld d,0
    add hl,de
    call BM_MULT_11
    ld de,(BM_CUR_PAGE_PNT)
    add hl,de
    ld (BM_CUR_FILE_PNT),hl
    ret


;--- Multiply HL by 11

BM_MULT_11:
    push hl
    pop de
    sla l
    rl h    ;*2
    sla l
    rl h    ;*4
    sla l
    rl h    ;*8
    add hl,de   ;*9
    add hl,de   ;*10
    add hl,de   ;*11
    ret


;--- Multiply HL by 20

BM_MULT_20:
    push hl
    pop de
    sla l
    rl h    ;*2
    sla l
    rl h    ;*4
    sla l
    rl h    ;*8
    sla l
    rl h    ;*16
    add hl,de   ;*17
    add hl,de   ;*18
    add hl,de   ;*19
    add hl,de   ;*20
    ret


;--- Multiply HL by 60

BM_MULT_60:
    push hl
    pop de
    sla l
    rl h    ;*2
    sla l
    rl h    ;*4
    sla l
    rl h    ;*8
    sla l
    rl h    ;*16
    sla l
    rl h    ;*32
    ld b,60-32
_BM_MULT_60_LOOP:
    add hl,de
    djnz _BM_MULT_60_LOOP
    ret

; -----------------------------------------------------------------------------
; Text strings
; -----------------------------------------------------------------------------

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

BM_ROOT_DIR_S:
    db "/",0

BM_DSK_S:
    db "DSK",0

BM_NO_FILES_S:
    db "No files found in current directory!",0

BM_SCANNING_DIR_S:
    db "Scanning directory...",0

BM_RESETTING_DEVICE_S:
    db "Resetting device...",0

BM_NO_DEV_OR_NO_STOR_S:
    db "No storage device found! F5 to retry",0

BM_FILE_NOT_FOUND_S:
    db "File/dir not found! Press any key",0

BM_ERROR_OPENING_FILE_S:
    db "Error opening file/dir! Press any key",0

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


; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------

_BM_VARS_BASE: equ 0E000h

BM_NUM_PAGES: equ _BM_VARS_BASE
BM_CUR_PAGE:  equ BM_NUM_PAGES+1
BM_NUM_FILES: equ BM_CUR_PAGE+1
BM_BUF: equ BM_NUM_FILES+2
BM_CUR_PAGE_PNT: equ BM_BUF+13   ;Pointer to 1st filename in current page
BM_CUR_FILE_PNT: equ BM_CUR_PAGE_PNT+2   ;Pointer to current filename
BM_CUR_ROW: equ BM_CUR_FILE_PNT+2   ;Current logical row, 0-19
BM_CUR_COL: equ BM_CUR_ROW+1   ;Current logical column, 0-2
BM_CURSOR_LAST: equ BM_CUR_COL+1    ;Result of last call to BM_CURSOR_IS_PRESSED
BM_NO_STOR_DEV: equ BM_CURSOR_LAST+1 ;FFh if F5 was pressed and no storage device was found
