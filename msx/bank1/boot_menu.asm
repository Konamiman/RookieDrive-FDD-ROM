; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the code for the boot menu that displays
; a navigable list of disk image files (available only when a
; standard USB mass storage device is plugged in).

BM_MAX_DIR_NAME_LENGTH: equ 64

; -----------------------------------------------------------------------------
; Boot menu entry point
; 
; The starting point is CURDIR, or if it isn't set, the main directory.
;
; Input:  A  = Where is this called from:
;              0: Computer boot
;              1: CALL USBMENU/SUBRESET
; Output: A = 0 if a file was actually mounted
;             1 if ESC or CTRL+STOP was pressed
;             2 if not enough memory to start the menu
;             3 if no storage device is present
;             4 if error setting initial directory (not when F5-ing)
; -----------------------------------------------------------------------------

DO_BOOT_MENU:

    ;Return with error if no storage device was found

    push af
    call USB_CHECK_DEV_CHANGE
    pop hl

    call WK_GET_STORAGE_DEV_FLAGS
    ld a,3
    ret z

    ;Return with error if we have less than 1.5K of free space

    push hl
    ld hl,0
    add hl,sp
    ld de,(STREND)
    or a
    sbc hl,de
    ld a,h
    cp 6
    ld a,2
    pop de
    ret c

    ld bc,100+660+BM_VARS_LEN   ;Work stack space + space for one page of 0s + space for variables
    or a
    sbc hl,bc
    push hl
    pop bc
    push de
    ld de,11
    call DIVIDE_16
    pop de

    push iy
    ld iy,-BM_VARS_LEN
    add iy,sp
    ld sp,iy

    ld (iy+BM_MAX_FILES_TO_ENUM),c
    ld (iy+BM_MAX_FILES_TO_ENUM+1),b
    ld (iy+BM_WHERE_CALLED_FROM),d

    call BM_SCREEN_BAK
    ld a,40
    ld (LINL40),a
    call INITXT
    call ERAFNK

    call DO_BOOT_MENU_MAIN

    push af
    call BM_SCREEN_REST
    call KILBUF

    ld a,(iy+BM_WHERE_CALLED_FROM)
    or a
    jr z,_BM_NO_REMOUNT
    pop af
    push af
    cp 1
    call z,DSK_REMOUNT
_BM_NO_REMOUNT:
    pop af

    ld iy,BM_VARS_LEN
    add iy,sp
    ld sp,iy
    pop iy

    ret

DO_BOOT_MENU_MAIN:
    xor a
    ld (iy+BM_CURSOR_DELAY),a
    ld (iy+BM_NO_STOR_DEV),a

    ; Init screen mode, draw fixed elements

    call CLS

    ld h,1
    ld l,2
    call POSIT
    call BM_DRAW_LINE
    ld h,1
    ld l,23
    call POSIT
    call BM_DRAW_LINE

    ; Try opening the initial directory

    call BM_OPEN_INITIAL_DIR
    or a
    ld a,4
    ret nz

    call BM_PRINT_CUR_DIR
    call BM_ENUM_FILES


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
    ld l,(iy+BM_NUM_FILES)
    ld h,(iy+BM_NUM_FILES+1)
    ld a,h
    or l
    call nz,BM_PRINT_CURRENT_FILE_AS_SELECTED

;--- This is the actual start of the loop

_BM_MAIN_LOOP:
    halt
    call BREAKX
    ld a,1
    ret c

    ld de,0407h ;ESC pressed?
    call BM_KEY_CHECK
    jp z,BM_DO_ESC

    call BM_F5_IS_PRESSED
    jp z,BM_START_OVER

    ld a,(iy+BM_NO_STOR_DEV)
    inc a
    jr z,_BM_MAIN_LOOP

    call BM_ENTER_IS_PRESSED
    jp z,BM_DO_ENTER

    call BM_BS_IS_PRESSED
    jp z,BM_DO_BS

    call BM_F1_IS_PRESSED
    jp z,BM_DO_HELP

    call BM_F2_IS_PRESSED
    jp z,BM_DO_CONFIG

    call BM_CURSOR_IS_PRESSED
    or a
    jr z,_BM_MAIN_LOOP
    bit 7,a
    jp z,BM_UPDATE_CUR_FILE
    and 7Fh
    jp BM_UPDATE_PAGE

;--- Start over after F5 is pressed

BM_START_OVER:
    call BM_CLEAR_INFO_AREA
    xor a
    ld (iy+BM_CUR_DIR),a
    call BM_ADJUST_DIR_VARS
    call BM_PRINT_CUR_DIR
    ld hl,BM_RESETTING_DEVICE_S
    call BM_PRINT_STATUS

    ld hl,0
    call HWF_MOUNT_DISK
    jr nc,_BM_START_OVER_OK

    xor a
    ld (iy+BM_NUM_FILES),a
    ld (iy+BM_NUM_FILES+1),a
    call WK_SET_STORAGE_DEV_FLAGS
    inc a
    ld (iy+BM_CUR_PAGE),a
    ld (iy+BM_NUM_PAGES),a
    ld a,0FFh
    ld (iy+BM_NO_STOR_DEV),a
    ld hl,BM_NO_DEV_OR_NO_STOR_S
    call BM_PRINT_STATUS
    call CHGET
    jp _BM_MAIN_LOOP

_BM_START_OVER_OK:
    call DSK_INIT_WK_FOR_STORAGE_DEV
    ld a,1
    call DSK_DO_BOOT_PROC
    jp DO_BOOT_MENU_MAIN


; -----------------------------------------------------------------------------
; Key press handlers
;
; These are JP-ed in, so they must finish by JP-ing to
; either BM_ENTER_MAIN_LOOP or _BM_MAIN_LOOP.
; -----------------------------------------------------------------------------


;--- ESC key press handler

BM_DO_ESC:
    ld de,0106h ;SHIFT is pressed?
    call BM_KEY_CHECK_CORE
    ld a,1
    ret nz

    ld hl,BM_CHANGING_EXITING_S
    call BM_PRINT_STATUS
    call BM_GET_CUR_DIR_ADD
    ld a,1
    call DSK_CHANGE_DIR_U
    ld a,5
    ret


;--- ENTER key press handler

BM_DO_ENTER:
    ld de,0206h ;CTRL is pressed?
    call BM_KEY_CHECK_CORE
    ld (iy+BM_TEMP),a

    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)

    push hl
    call BM_GET_BUF_ADD
    ex de,hl
    pop hl
    push hl
    call BM_GENERATE_FILENAME
    pop ix
    bit 7,(ix+10)
    jp nz,BM_DO_ENTER_DIR

    ;* It's a file

BM_DO_ENTER_FILE:
    ld hl,BM_MOUNTING_BOOTING_S
BM_DO_ENTER_FILE_2:
    call BM_PRINT_STATUS
    call BM_CLEAR_INFO_AREA

    call BM_GET_CUR_DIR_ADD
    call DSK_WRITE_CURDIR_FILE
    or a
    ld hl,BM_ERROR_OPENING_FILE_S
    jr nz,_BM_DO_ENTER_OPEN_ERR
    
    call BM_GET_BUF_ADD
    xor a
    call DSK_MOUNT
    or a
    jr z,_BM_DO_ENTER_FILE_SUCCESS   ;Exit boot menu

_BM_DO_ENTER_OPEN_ERR:
    cp 2
    ld hl,BM_FILE_NOT_FOUND_S
    jr z,_BM_DO_ENTER_PRINT_ERR
    ld hl,BM_ERROR_OPENING_FILE_S   ;Other error or it's a dir
_BM_DO_ENTER_PRINT_ERR:
    call BM_PRINT_STATUS_WAIT_KEY

_BM_DO_ENTER_WAIT_RELEASE:  ;In case the "any key" pressed is enter
    call BM_ENTER_IS_PRESSED
    jr z,_BM_DO_ENTER_WAIT_RELEASE

    ld hl,BM_SCANNING_DIR_S
    call BM_PRINT_STATUS
    call BM_GET_CUR_DIR_ADD
    ld a,1
    call DSK_CHANGE_DIR_U
    call BM_ENUM_FILES
    jp BM_ENTER_MAIN_LOOP ; _BM_MAIN_LOOP

_BM_DO_ENTER_FILE_SUCCESS:
    call KILBUF

    ld a,(iy+BM_TEMP)   ;Was CTRL pressed?
    or a
    ld a,0
    ret nz  ;Exit menu

    ld hl,BM_RESETTING_S
    call BM_PRINT_STATUS

    call DSK_CREATE_TMP_BOOT_FILE
    or a
    ld iy,(EXPTBL-1)
    ld ix,0
    jp z,CALSLT

    ld hl,BM_ERR_CREATING_TEMP_FILE_S
    call BM_PRINT_STATUS_WAIT_KEY
    jp BM_ENTER_MAIN_LOOP

    ;* It's a directory

BM_DO_ENTER_DIR:
    call BM_GET_BUF_ADD
    ld c,"/"
    call BM_STRLEN_C
    ld (hl),0
    inc b   ;Count also the additional "/"
    ld a,(iy+BM_CUR_DIR_LENGTH)
    add b
    cp BM_MAX_DIR_NAME_LENGTH+1
    jp nc,_BM_MAIN_LOOP     ;Max dir length surpassed: can't change dir

    call BM_GET_BUF_ADD
    call HWF_OPEN_FILE_DIR
    jp nz,_BM_DO_ENTER_OPEN_ERR
    jp nc,_BM_DO_ENTER_OPEN_ERR

    ld a,(iy+BM_CUR_DIR_LEVEL)
    inc a
    ld (iy+BM_CUR_DIR_LEVEL),a

    ld a,(iy+BM_CUR_DIR_LENGTH)
    ld e,a
    ld d,0
    call BM_GET_CUR_DIR_ADD
    add hl,de

    ld a,(iy+BM_CUR_DIR_LEVEL)
    cp 1
    jr z,_BM_DO_ENTER_DIR_WAS_ROOT
    ld (hl),"/"
    inc hl
_BM_DO_ENTER_DIR_WAS_ROOT:

    ex de,hl
    call BM_GET_BUF_ADD
_BM_COPY_DIR_NAME_LOOP:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    or a
    jr nz,_BM_COPY_DIR_NAME_LOOP

    call BM_GET_CUR_DIR_ADD
    call BM_STRLEN
    ld a,b
    ld (iy+BM_CUR_DIR_LENGTH),a

    call BM_PRINT_CUR_DIR

    ld de,0106h ;SHIFT is pressed?
    call BM_KEY_CHECK_CORE
    jr z,_BM_DO_MOUNT_DEFAULT
    ld de,0206h ;CTRL is pressed?
    call BM_KEY_CHECK_CORE
    jr z,_BM_DO_MOUNT_DEFAULT

_BM_DO_ENTER_DIR_END:
    call BM_ENUM_FILES
    jp BM_ENTER_MAIN_LOOP

    ;* It's a directory and SHIFT was pressed

_BM_DO_MOUNT_DEFAULT:
    call BM_GET_BUF_ADD
    push hl
    call DSK_GET_DEFAULT
    pop hl

    or a
    ld hl,BM_MOUNTING_DEF_S
    jp z,BM_DO_ENTER_FILE_2
    cp 2
    jr z,_BM_DO_ENTER_DIR_END

    ld hl,BM_ERR_RETRIEVING_DEFAULT_S
    call BM_PRINT_STATUS_WAIT_KEY
    jr _BM_DO_ENTER_DIR_END


;--- Print the string HL in the status area and wait for a key press

BM_PRINT_STATUS_WAIT_KEY:
    call BM_PRINT_STATUS
    call KILBUF
    call CHGET
    push af
    call KILBUF
    pop af
    ret


;--- BS key press handler, go to parent directory
;
;    The CH376 doesn't support opening ".." so we'll have to
;    cd to root and then to each dir on the current path
;    stopping right before the last one :facepalm:

BM_DO_BS:
    ld a,(iy+BM_CUR_DIR_LEVEL)
    or a
    jp z,_BM_MAIN_LOOP  ;We are in the root dir already

    call BM_CLEAR_INFO_AREA
    ld hl,BM_ENTERING_DIR_S
    call BM_PRINT_STATUS

    call BM_GET_CUR_DIR_ADD
    push hl
    ld a,(iy+BM_CUR_DIR_LEVEL)
    dec a
    jr z,_BM_DO_BS_FOUND_SLASH  ;We are in level 1: just zero the current dir
    ld c,(iy+BM_CUR_DIR_LENGTH)
    ld b,0
    add hl,bc
_BM_DO_BS_FIND_SLASH_LOOP:
    dec hl
    ld a,(hl)
    cp "/"
    jr nz,_BM_DO_BS_FIND_SLASH_LOOP

_BM_DO_BS_FOUND_SLASH:
    ld (hl),0
    pop hl
    ld a,1
    call DSK_CHANGE_DIR
    or a
    jr z,_BM_DO_BS_END

_BM_DO_BS_OPEN_ERROR:
    xor a
    ld (iy+BM_CUR_DIR),a
    call BM_PRINT_CUR_DIR
    ld hl,BM_ERROR_OPENING_FILE_S
    call BM_PRINT_STATUS_WAIT_KEY
    xor a
    ld (iy+BM_NUM_FILES),a
    ld (iy+BM_NUM_FILES+1),a
    inc a
    ld (iy+BM_NUM_PAGES),a
    ld (iy+BM_CUR_PAGE),a
    ld (iy+BM_CUR_DIR_LENGTH),a
    jp BM_ENTER_MAIN_LOOP

_BM_DO_BS_END:
    ld a,(iy+BM_CUR_DIR_LEVEL)
    dec a
    ld (iy+BM_CUR_DIR_LEVEL),a
_BM_DO_BS_END_2:
    call BM_GET_CUR_DIR_ADD
    call BM_STRLEN
    ld a,b
    ld (iy+BM_CUR_DIR_LENGTH),a
    call BM_PRINT_CUR_DIR
    call BM_ENUM_FILES
    jp BM_ENTER_MAIN_LOOP


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


;--- Config loop, entered when F2 is pressed

BM_DO_CONFIG:
    call BM_CLEAR_INFO_AREA
    ld hl,BM_ZERO_S
    call BM_PRINT_STATUS

    ld h,1
    ld l,4
    call POSIT

    ;* Print the current boot directory

    ld hl,BM_CONFIG_BOOTDIR_S
    call PRINT

    call BM_GET_BUF_ADD
    push hl
    call DSK_GET_BOOTDIR
    pop hl
    or a
    jr z,BM_DO_CONFIG_2
    cp 1
    ld hl,BM_ERROR_S
    jr z,BM_DO_CONFIG_2
    ld hl,DSK_MAIN_DIR_S
BM_DO_CONFIG_2:
    call PRINT
    call BM_PRINT_CRLF

    ;* Print the name of the default file in current dir

    ld hl,BM_CONFIG_DEFFILE_S
    call PRINT

    call BM_RESTORE_CURDIR

    call BM_GET_BUF_ADD
    push hl
    call DSK_READ_DEFFILE_FILE
    pop hl
    or a
    jr z,BM_DO_CONFIG_3
    cp 1
    ld hl,BM_ERROR_S
    jr z,BM_DO_CONFIG_3
    ld hl,BM_UNSET_S
BM_DO_CONFIG_3:
    push af
    call PRINT
    call BM_PRINT_CRLF

    ;* Print the current boot mode

    ld hl,BM_CONFIG_BOOTMODE_S
    call PRINT
    call DSK_GET_BOOTMODE
    add "0"
    call CHPUT

    call BM_RESTORE_CURDIR

    ;* Print the boot mode change options

    ld hl,BM_CONFIG_TEXT_S
    call PRINT

    ;* Print "set (currently pointed file) as default" if it's indeed a file

    ;BM_TEMP usage:
    ;bit 0 set if there's a pointed file that can be set as default
    ;bit 1 set if there's a default file that can be unset
    ld (iy+BM_TEMP),0

    ld l,(iy+BM_NUM_FILES)
    ld h,(iy+BM_NUM_FILES+1)
    ld a,h
    or l
    jr z,BM_DO_CONFIG_4

    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)
    push hl
    pop ix
    ld a,(ix+10)
    and 80h     ;Is it a directory?
    jr nz,BM_DO_CONFIG_4

    set 0,(iy+BM_TEMP)
    ld hl,BM_CONFIG_SET_DEF_S
    call PRINT
    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)
    call BM_PRINT_FILENAME

    ld hl,BM_CONFIG_TEXT_2_S
    call PRINT

    ;* Print "unset default file" if one is set

BM_DO_CONFIG_4:
    pop af
    or a
    jr nz,BM_DO_CONFIG_ASK
    set 1,(iy+BM_TEMP)
    ld hl,BM_CONFIG_UNSET_DEF_S
    call PRINT

    ;* Print "Enable/disable CAPS lit on file access"

    ld hl,BM_CONFIG_TWOCRLF_S
    call PRINT
    call DSK_TEST_CAPS_LIT
    or a
    ld hl,BM_CONFIG_ENABLE_8_S
    jr z,BM_DO_CONFIG_5
    ld hl,BM_CONFIG_DISABLE_8_S
BM_DO_CONFIG_5:
    call PRINT
    ld hl,BM_CONFIG_CAPS_LIT_S
    call PRINT

    ;* All info printed, ask user what to do and do it

BM_DO_CONFIG_ASK:
    ld hl,BM_CONFIG_CHOOSE_S
    call BM_PRINT_STATUS_WAIT_KEY

    sub "0"
    or a
    jr z,BM_DO_CONFIG_RETURN

    cp 5
    jr c,BM_DO_CONFIG_BOOTMODE

    ;cp 5
    jr z,BM_DO_SET_BOOTDIR

    cp 6
    jr z,BM_DO_SET_DEFFILE

    cp 7
    jr z,BM_DO_UNSET_DEFFILE

    cp 8
    jr z,BM_DO_TOGGLE_CAPS_LIT

    jr BM_DO_CONFIG_ASK ;Invalid action selected: ask again

BM_DO_CONFIG_RETURN:
    call BM_RESTORE_CURDIR
    jp BM_ENTER_MAIN_LOOP

BM_DO_CONFIG_BOOTMODE:
    add "0"
    call DSK_WRITE_BOOTMODE_FILE
    jr BM_DO_CONFIG_AFTER_CHANGE

BM_DO_SET_BOOTDIR:
    call BM_GET_CUR_DIR_ADD
    call DSK_WRITE_BOOTDIR_FILE
    jr BM_DO_CONFIG_AFTER_CHANGE

BM_DO_SET_DEFFILE:
    bit 0,(iy+BM_TEMP)
    jr z,BM_DO_CONFIG_ASK

    call BM_GET_BUF_ADD
    push hl
    ex de,hl
    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)
    call BM_GENERATE_FILENAME
    pop hl
    call DSK_WRITE_DEFFILE_FILE
    jr BM_DO_CONFIG_AFTER_CHANGE

BM_DO_UNSET_DEFFILE:
    bit 1,(iy+BM_TEMP)
    jr z,BM_DO_CONFIG_ASK

    call BM_RESTORE_CURDIR
    ld hl,BM_ZERO_S
    call DSK_WRITE_DEFFILE_FILE
    jr BM_DO_CONFIG_AFTER_CHANGE

BM_DO_TOGGLE_CAPS_LIT:
    call DSK_TEST_CAPS_LIT
    xor 1
    call DSK_SET_OR_UNSET_CAPS_LIT
    or a
    jr nz,BM_DO_CONFIG_AFTER_CHANGE
    call DSK_UPDATE_CAPS_LIT_WK
    xor a
    ;jr BM_DO_CONFIG_AFTER_CHANGE

    ;* After doing an action, show error if needed, then start over

BM_DO_CONFIG_AFTER_CHANGE:
    or a
    jp z,BM_DO_CONFIG
    ld hl,BM_CONFIG_ERROR_APPLYING_S
    call BM_PRINT_STATUS_WAIT_KEY
    jp BM_DO_CONFIG


;--- Just that... print a CRLF sequence

BM_PRINT_CRLF:
    ld hl,CRLF_S
    jp PRINT


;--- Set again the directory in CURDIR

BM_RESTORE_CURDIR:
    call BM_GET_CUR_DIR_ADD
    ld a,1
    jp DSK_CHANGE_DIR 


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
    ld a,(iy+BM_CUR_COL)
    dec a
    cp 0FFh
    jr nz,_BM_UPDATE_CUR_COL_GO
    ld a,2
    jr _BM_UPDATE_CUR_COL_GO

_BM_FILE_RIGHT:
    ld a,(iy+BM_CUR_COL)
    inc a
    cp 3
    jr c,_BM_UPDATE_CUR_COL_GO
    xor a
    jr _BM_UPDATE_CUR_COL_GO

_BM_FILE_UP:
    ld a,(iy+BM_CUR_ROW)
    dec a
    cp 0FFh
    jr nz,_BM_UPDATE_CUR_ROW_GO
    ld a,19
    jr _BM_UPDATE_CUR_ROW_GO

_BM_FILE_DOWN:
    ld a,(iy+BM_CUR_ROW)
    inc a
    cp 20
    jr c,_BM_UPDATE_CUR_ROW_GO
    xor a
    jr _BM_UPDATE_CUR_ROW_GO

_BM_UPDATE_CUR_COL_GO:
    ld (iy+BM_CUR_COL),a
    push iy
    pop hl
    ld bc,BM_CUR_COL
    add hl,bc
    ld (iy+BM_TEMP),l
    ld (iy+BM_TEMP+1),h
    jr _BM_UPDATE_CUR_ROWCOL_GO

_BM_UPDATE_CUR_ROW_GO:
    ld (iy+BM_CUR_ROW),a
    push iy
    pop hl
    ld bc,BM_CUR_ROW
    add hl,bc
    ld (iy+BM_TEMP),l
    ld (iy+BM_TEMP+1),h

_BM_UPDATE_CUR_ROWCOL_GO:
    call BM_UPDATE_CUR_FILE_PNT
    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)
    ld a,(hl)
    or a
    jr nz,_BM_UPDATE_CUR_ROWCOL_GO_2
    ;We ended up pointing past the end of the list,
    ;so reset column/row to 0
    ld l,(iy+BM_TEMP)
    ld h,(iy+BM_TEMP+1)
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
    ld a,(iy+BM_NUM_PAGES)
    ld b,a
    ld a,(iy+BM_CUR_PAGE)
    cp b
    jp z,_BM_MAIN_LOOP

    inc a
    ld (iy+BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_NEXT_10_PAGES:
    ld a,(iy+BM_NUM_PAGES)
    ld b,a
    ld a,(iy+BM_CUR_PAGE)
    cp b
    jp nc,_BM_MAIN_LOOP
    inc b
    add 10
    cp b
    jr c,_BM_NEXT_10_PAGES_GO
    ld a,(iy+BM_NUM_PAGES)

_BM_NEXT_10_PAGES_GO:
    ld (iy+BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_PREV_PAGE:
    ld a,(iy+BM_CUR_PAGE)
    cp 1
    jp z,_BM_MAIN_LOOP

    dec a
    ld (iy+BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_PREV_10_PAGES:
    ld a,(iy+BM_CUR_PAGE)
    cp 1
    jp z,_BM_MAIN_LOOP
    sub 10
    jr z,_BM_PREV_10_PAGES_1
    jp p,_BM_PREV_10_PAGES_GO
_BM_PREV_10_PAGES_1:    
    ld a,1

_BM_PREV_10_PAGES_GO:
    ld (iy+BM_CUR_PAGE),a
    jp _BM_UPDATE_PAGE_END

_BM_UPDATE_PAGE_END:
    xor a
    ld (iy+BM_CUR_ROW),a
    ld (iy+BM_CUR_COL),a
    jp BM_ENTER_MAIN_LOOP


    ;--- Enumerate files and initialize paging

BM_ENUM_FILES:
    ld a,1
    ld (iy+BM_CUR_PAGE),a

    call BM_CLEAR_INFO_AREA
    ld hl,BM_SCANNING_DIR_S
    call BM_PRINT_STATUS

    ld hl,(STREND)
    ld c,(iy+BM_MAX_FILES_TO_ENUM)
    ld b,(iy+BM_MAX_FILES_TO_ENUM+1)
    call HWF_ENUM_FILES
    ld (iy+BM_NUM_FILES),c
    ld (iy+BM_NUM_FILES+1),b
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
    ld (iy+BM_NUM_PAGES),a

    xor a
    ld (iy+BM_CUR_ROW),a
    ld (iy+BM_CUR_COL),a
    ret


; -----------------------------------------------------------------------------
; Screen printing routines
; -----------------------------------------------------------------------------


;--- Print the filenames for the current page

BM_PRINT_FILENAMES_PAGE:
    ld l,(iy+BM_NUM_FILES)
    ld h,(iy+BM_NUM_FILES+1)
    ld a,h
    or l
    jp nz,_BM_PRINT_FILENAMES_PAGE_GO

    ld h,3
    ld l,12
    call POSIT
    ld hl,BM_NO_FILES_S
    jp PRINT

_BM_PRINT_FILENAMES_PAGE_GO:
    ld a,(iy+BM_CUR_PAGE)
    ld b,a
    ld hl,(STREND)
    ld de,11*60
    or a
    sbc hl,de
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

    ld a,(iy+BM_CUR_PAGE)
    call BM_PRINT_BYTE
    ld hl,BM_SPACE_AND_BAR
    call PRINT
    ld a,(iy+BM_NUM_PAGES)
    jp BM_PRINT_BYTE

BM_PRINT_BYTE:
    call BM_GET_BUF_ADD
    push hl
    pop ix
    call BYTE2ASC
    ld (ix),0
    call BM_GET_BUF_ADD
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
    ld a,(iy+BM_CUR_COL)
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
    ld a,(iy+BM_CUR_ROW)
    add 3
    ld l,a
    jp POSIT


;--- Print the current filename at the current position

BM_PRINT_CURRENT_FILE:
    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)
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
    call BM_GET_BUF_ADD
    ex de,hl
    ld l,(iy+BM_CUR_FILE_PNT)
    ld h,(iy+BM_CUR_FILE_PNT+1)
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

    call BM_GET_BUF_ADD  ;Pointer to current char
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


;--- Print the current directory in the top row

BM_PRINT_CUR_DIR:
    ld h,1
    ld l,1
    call POSIT
    ld a,"/"
    call CHPUT

    ld a,(iy+BM_CUR_DIR_LENGTH)
    cp 40
    jr c,_BM_PRINT_CUR_DIR_DIRECT

    ld hl,BM_DOTS_BAR_S
    call PRINT

    ; Skip leading slash in the last directory part, then print it
    call BM_GET_LAST_DIR_PNT
    jr _BM_PRINT_CUR_DIR_TRUNC

    ;call BM_GET_LAST_DIR_PNT
    ;call PRINT
    ;jr _BM_PRINT_CUR_DIR_END

_BM_PRINT_CUR_DIR_DIRECT:
    call BM_GET_CUR_DIR_ADD
    ;call PRINT

  ; Skip any leading '/'
_BM_SKIP_LEADING_SLASH:
    ld a,(hl)
    cp "/"
    jr nz,_BM_PRINT_CUR_DIR_PRINT
    inc hl
    jr _BM_SKIP_LEADING_SLASH

_BM_PRINT_CUR_DIR_PRINT:
    ld a,(hl)
    or a
    jr z,_BM_PRINT_CUR_DIR_END  ; If empty, done (just "/")

    ; Print whatever is left
    call PRINT
    jr _BM_PRINT_CUR_DIR_END

_BM_PRINT_CUR_DIR_TRUNC:
    ; By default, BM_GET_LAST_DIR_PNT leaves HL pointing 
    ; at the final name in the path, but let's skip slashes just in case

_BM_SKIP_LEADING_SLASH_2:
    ld a,(hl)
    cp "/"
    jr nz,_BM_PRINT_CUR_DIR_TRUNC_PRINT
    inc hl
    jr _BM_SKIP_LEADING_SLASH_2

_BM_PRINT_CUR_DIR_TRUNC_PRINT:
    ld a,(hl)
    or a
    jr z,_BM_PRINT_CUR_DIR_END  ; If empty, done (just "/.../")
    call PRINT

_BM_PRINT_CUR_DIR_END:
    ld a,27
    call CHPUT
    ld a,'K'
    jp CHPUT  ;Delete to end of line

;--- Get pointer to the last part of the current directory name
;    (assuming current dir is not root)

BM_GET_LAST_DIR_PNT:
    call BM_GET_CUR_DIR_ADD
    ld e,(iy+BM_CUR_DIR_LENGTH)
    ld d,0
    add hl,de
_BM_GET_LAST_DIR_PNT_LOOP:
    dec hl
    ld a,(hl)
    cp "/"
    jr nz,_BM_GET_LAST_DIR_PNT_LOOP

    inc hl
    ret


; -----------------------------------------------------------------------------
; Keyboard scanning routines
; -----------------------------------------------------------------------------

;--- Check if a key is pressed
;    Input:  D = Keyboard matrix column mask, desired key set to 1
;            E = Keyboard matrix row number
;    Output: Z if key is pressed, NZ if not

BM_KEY_CHECK:
    call BM_KEY_CHECK_CORE
    ret nz

_BM_KEY_CHECK_WAIT_RELEASE:
    halt
    ld a,(hl)
    and b
    jr z,_BM_KEY_CHECK_WAIT_RELEASE
    xor a
    ret

    ;This version doesn't wait for key release

BM_KEY_CHECK_CORE:
    ld b,d
    ld d,0
    ld hl,NEWKEY
    add hl,de
    ld a,(hl)
    and b
    ret


;--- Check if F1 is pressed
;    Output: Z if pressed, NZ if not

BM_F1_IS_PRESSED:
    ld de,2006h
    jp BM_KEY_CHECK


;--- Check if F2 is pressed
;    Output: Z if pressed, NZ if not

BM_F2_IS_PRESSED:
    ld de,4006h
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


;--- Check if BS is pressed
;    Output: Z if pressed, NZ if not

BM_BS_IS_PRESSED:
    ld de,2007h
    jp BM_KEY_CHECK
    ret nz

_BM_BS_IS_PRESSED_WAIT_RELEASE:
    ld de,2007h
    call BM_KEY_CHECK
    jr z,_BM_BS_IS_PRESSED_WAIT_RELEASE
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
    jr nc,_BM_CURSOR_IS_PRESSED_GO
    rlca
    ld b,3
    jr nc,_BM_CURSOR_IS_PRESSED_GO
    rlca
    ld b,1
    jr nc,_BM_CURSOR_IS_PRESSED_GO
    rlca
    ld b,4
    jr nc,_BM_CURSOR_IS_PRESSED_GO

    xor a
    ld (iy+BM_CURSOR_DELAY),a
    ret

_BM_CURSOR_IS_PRESSED_GO:
    ;* Not previously pressed: return key, init delay counter

    ld a,(iy+BM_CURSOR_DELAY)
    or a
    jr nz,_BM_CURSOR_IS_PRESSED_GO_2

    inc a
    ld (iy+BM_CURSOR_DELAY),a
    jr _BM_CURSOR_IS_PRESSED_END
_BM_CURSOR_IS_PRESSED_GO_2:

    ;* Bit 7 is set: we are already repeating

    bit 7,a
    jr z,_BM_CURSOR_IS_PRESSED_GO_3

    cp 3+128    ;3 cycles passed since last repeat?
    jr c,_BM_CURSOR_IS_PRESSED_INC_DELAY

    ld a,128
    ld (iy+BM_CURSOR_DELAY),a
    jr _BM_CURSOR_IS_PRESSED_END
_BM_CURSOR_IS_PRESSED_GO_3:

    ;* Bit 7 is reset: we are waiting for the first repetition

    cp 40   ;40 cycles passed since pressing?
    jr c,_BM_CURSOR_IS_PRESSED_INC_DELAY

    set 7,a
    ld (iy+BM_CURSOR_DELAY),a
    xor a
    ret

_BM_CURSOR_IS_PRESSED_INC_DELAY:
    inc a
    ld (iy+BM_CURSOR_DELAY),a
    xor a
    ret

    ;* Check for SHIFT and return, input: B = Pressed key

_BM_CURSOR_IS_PRESSED_END:
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
;    Base for filenames (STREND) + ((BM_CUR_PAGE-1)*60)*11

BM_UPDATE_CUR_PAGE_PNT:
    ld l,(iy+BM_CUR_PAGE)
    ld h,0
    dec l
    call BM_MULT_60
    call BM_MULT_11
    ld de,(STREND)
    add hl,de
    ld (iy+BM_CUR_PAGE_PNT),l
    ld (iy+BM_CUR_PAGE_PNT+1),h
    ret


;--- Update BM_CUR_FILE_PNT as:
;    BM_CUR_PAGE_PNT + ((BM_CUR_COL*20) + BM_CUR_ROW)*11

BM_UPDATE_CUR_FILE_PNT:
    ld l,(iy+BM_CUR_COL)
    ld h,0
    call BM_MULT_20
    ld e,(iy+BM_CUR_ROW)
    ld d,0
    add hl,de
    call BM_MULT_11
    ld e,(iy+BM_CUR_PAGE_PNT)
    ld d,(iy+BM_CUR_PAGE_PNT+1)
    add hl,de
    ld (iy+BM_CUR_FILE_PNT),l
    ld (iy+BM_CUR_FILE_PNT+1),h
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


;--- Calculate length of zero-terminated string
;    Input:  HL = String
;    Output: B  = Length
;            HL points to the zero

BM_STRLEN:
    ld c,0
BM_STRLEN_C:
    ld b,0
_BM_STRLEN_LOOP:
    ld a,(hl)
    cp c
    ret z
    inc hl
    inc b
    jr _BM_STRLEN_LOOP


;--- Backup current screen mode

BM_SCREEN_BAK:
    ld a,(SCRMOD)
    ld (iy+BM_SCRMOD_BAK),a
    ld a,(LINLEN)
    ld (iy+BM_LINLEN_BAK),a
    ld a,(CNSDFG)
    ld (iy+BM_FNK_BAK),a
    ret


;--- Restore previous screen mode

BM_SCREEN_REST:
    ld a,(iy+BM_SCRMOD_BAK)
    dec a
    jr z,_BM_SCREEN_REST_W32

    ; Restore SCREEN 0

_BM_SCREEN_REST_W40:
    ld a,(iy+BM_LINLEN_BAK)
    ld (LINL40),a
    call INITXT
    jr _BM_SCREEN_REST_OK

    ; Restore SCREEN 1

_BM_SCREEN_REST_W32:
    ld a,(iy+BM_LINLEN_BAK)
    ld (LINL32),a
    call INIT32

    ; Restore function keys

_BM_SCREEN_REST_OK:
    ld a,(iy+BM_FNK_BAK)
    or a
    call nz,DSPFNK

    ret


;--- Get the address of BM_BUF in HL

BM_GET_BUF_ADD:
    push bc
    push iy
    pop hl
    ld bc,BM_BUF
    add hl,bc
    pop bc
    ret


;--- Get the address of BM_CUR_DIR in HL

BM_GET_CUR_DIR_ADD:
    push bc
    push iy
    pop hl
    ld bc,BM_CUR_DIR
    add hl,bc
    pop bc
    ret


;--- Adjust variables after BM_CUR_DIR has changed

BM_ADJUST_DIR_VARS:
    call BM_GET_CUR_DIR_ADD
    push hl
    call BM_STRLEN
    pop hl
    ld (iy+BM_CUR_DIR_LENGTH),b

    ld b,0
    ld a,(hl)
    or a
    jr z,_BM_CALC_DIR_LEVEL_END
    inc b   ;Non-empty dir: start at level 1, each "/" increases level
_BM_CALC_DIR_LEVEL:
    ld a,(hl)
    inc hl
    or a
    jr z,_BM_CALC_DIR_LEVEL_END
    cp "/"
    jr nz,_BM_CALC_DIR_LEVEL
    inc b
    jr _BM_CALC_DIR_LEVEL
_BM_CALC_DIR_LEVEL_END:
    ld (iy+BM_CUR_DIR_LEVEL),b

    ret


;--- Try opening the initial directory
;    Output: A = 0 if ok, 1 if error

BM_OPEN_INITIAL_DIR:
    if USE_FAKE_STORAGE_DEVICE = 0

    call BM_GET_CUR_DIR_ADD
    call DSK_GET_CURDIR
    or a
    jr nz,_BM_MAIN_GETDIR_ERR
    call BM_ADJUST_DIR_VARS
    xor a
    ret

_BM_MAIN_GETDIR_ERR
    ld hl,BM_ERROR_INITIAL_S
    call BM_PRINT_STATUS_WAIT_KEY
    ld a,1
    ret

    else

    xor a
    ret

    endif

; -----------------------------------------------------------------------------
; Text strings
; -----------------------------------------------------------------------------

;--- Strings

BM_F1_HELP:
    db "F1 = Help, F2 = Config",0

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
    db "/DSK",0

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

BM_ERROR_INITIAL_S:
    db "Error entering initial dir! Press any key",0

BM_MOUNTING_BOOTING_S:
    db "Mounting file...",0

BM_ENTERING_DIR_S:
    db "Entering directory...",0

BM_CHANGING_EXITING_S:
    db "Changing current dir and exiting...",0

BM_MOUNTING_DEF_S:
    db "Mounting default file for dir...",0

BM_ERR_RETRIEVING_DEFAULT_S:
    db "Error retrieving default file for dir!",0

BM_ERR_CREATING_TEMP_FILE_S:
    db "Error creating temp file! Press any key",0

BM_RESETTING_S:
    db "Resetting computer...",0

BM_DOTS_BAR_S:
    db ".../",0

BM_DOTDOT_S:
    db "..",0

BM_HELP_1:
    db " Cursors: select file or directory",13,10
    db 13,10
    db " SHIFT+Right/Left: Next/prev page",13,10
    db 13,10
    db " SHIFT+Up/Down: Up/down 10 pages",13,10
    db 13,10
    db " Enter (on file): Mount file and exit",13,10
    db 13,10
    db " Enter (on dir): Enter directory",13,10
    db 13,10
    db " SHIFT+Enter (on dir):",13,10
    db "   Mount default file on dir and exit",13,10
    db 13,10
    db " CTRL+Enter: Mount and reset",13,10
    db 13,10
    db " BS: Back to parent directory",13,10
    db 13,10
    db " F5: Reset device and start over",13,10
    db 13,10

    db 0

BM_HELP_2:
    db " ESC: Exit without mounting",13,10
    db 13,10
    db " SHIFT+ESC: Set current dir and",13,10
    db "   exit without mounting",13,10
    db 13,10
    db " TAB (while booting):",13,10
    db "   temporarily force boot mode 1",13,10
    db 13,10
    db " CALL USBHELP / _USBHELP (in BASIC):",13,10
    db "   show list of available CALL commands",13,10
    db 13,10
    db " After boot it is possible to switch",13,10
    db " to another disk image file from the",13,10
    db " same directory (up to 35 files).",13,10
    db 13,10
    db " On disk access press the key for the",13,10
    db " file (1-9, A-Z), or press CODE/KANA",13,10
    db " and when CAPS lits press the key."
    db 0

BM_CONFIG_BOOTDIR_S:
    db "Boot dir: /",0
BM_CONFIG_DEFFILE_S:
    db "Default file in this dir: ",0
BM_CONFIG_BOOTMODE_S:
    db "Boot mode: ",0
BM_CONFIG_TEXT_S:
    db ", to change press:",13,10
    db "  1: Show menu",13,10
    db "  2: Don't show menu, don't mount",13,10
    db "  3: Mount default file in boot dir",13,10
    db "  4: Mount last mounted file",13,10
    db 13,10
    db "5: Set current dir as boot dir",13,10
    db 13,10
    db 0
BM_CONFIG_SET_DEF_S:
    db "6: Set ",0
BM_CONFIG_TEXT_2_S:
    db " as default file",13,10
    db "   in this dir"
BM_CONFIG_TWOCRLF_S:
    db 13,10
    db 13,10
    db 0
BM_CONFIG_UNSET_DEF_S:
    db "7: Unset explicit default file",13,10
    db "   in this dir",0
BM_CONFIG_ENABLE_8_S:
    db "8: Enable",0
BM_CONFIG_DISABLE_8_S:    
    db "8: Disable",0
BM_CONFIG_CAPS_LIT_S:
    db " CAPS lit on file access",0
BM_CONFIG_CHOOSE_S:
    db "Choose an option, or 0 to exit: ",0

BM_CONFIG_ERROR_APPLYING_S:
    db "Error applying change - Press key ",0

BM_ERROR_S: db "(error)",0

BM_UNSET_S: db "(not set)"

BM_ZERO_S: db 0


; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------

BM_VARS_START: equ 0

BM_NUM_PAGES: equ BM_VARS_START
BM_CUR_PAGE:  equ BM_NUM_PAGES+1
BM_NUM_FILES: equ BM_CUR_PAGE+1
BM_CUR_PAGE_PNT: equ BM_NUM_FILES+2   ;Pointer to 1st filename in current page
BM_CUR_FILE_PNT: equ BM_CUR_PAGE_PNT+2   ;Pointer to current filename
BM_CUR_ROW: equ BM_CUR_FILE_PNT+2   ;Current logical row, 0-19
BM_CUR_COL: equ BM_CUR_ROW+1   ;Current logical column, 0-2
BM_CURSOR_DELAY: equ BM_CUR_COL+1    ;Counter to control control key repetition delays
BM_NO_STOR_DEV: equ BM_CURSOR_DELAY+1 ;FFh if F5 was pressed and no storage device was found
BM_CUR_DIR_LEVEL: equ BM_NO_STOR_DEV+1  ;Current direcrory level, 0 is root
BM_CUR_DIR: equ BM_CUR_DIR_LEVEL+1  ;Current directory, up to BM_MAX_DIR_NAME_LENGTH chars + 0
BM_CUR_DIR_LENGTH: equ BM_CUR_DIR+BM_MAX_DIR_NAME_LENGTH+1
BM_MAX_FILES_TO_ENUM: equ BM_CUR_DIR_LENGTH+1
BM_SCRMOD_BAK: equ BM_MAX_FILES_TO_ENUM+2
BM_LINLEN_BAK: equ BM_SCRMOD_BAK+1
BM_FNK_BAK: equ BM_LINLEN_BAK+1
BM_TEMP: equ BM_FNK_BAK+1
BM_WHERE_CALLED_FROM: equ BM_TEMP+2
BM_BUF: equ BM_WHERE_CALLED_FROM+1

BM_VARS_END: equ BM_BUF+64
BM_VARS_LEN: equ BM_VARS_END-BM_VARS_START