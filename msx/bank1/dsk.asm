; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the code for high-level management
; of disk image files, including creating and accessing
; configuration files when needed.


; -----------------------------------------------------------------------------
; DSK_OPEN_MAIN_DIR: Open the main directory
; -----------------------------------------------------------------------------
; Output: A = 0: Ok
;             1: Error

DSK_OPEN_MAIN_DIR:
    push hl
    push de
    push bc
    call _DSK_OPEN_MAIN_DIR
    pop bc
    pop de
    pop hl
    ret
_DSK_OPEN_MAIN_DIR:
    ld hl,DSK_ROOT_DIR_S
    call HWF_OPEN_FILE_DIR
    cp 1
    ld a,1
    ret nz

    ld hl,DSK_MAIN_DIR_S
    call HWF_OPEN_FILE_DIR
    ld b,a
    cp 3
    ld a,1
    ret z
    ld a,b
    dec a
    ret z

    ld hl,DSK_ROOT_DIR_S
    call HWF_OPEN_FILE_DIR
    dec a
    ret z
    ld a,1
    ret

DSK_ROOT_DIR_S:
    db "/",0

DSK_MAIN_DIR_S:
    db "MSX",0


; -----------------------------------------------------------------------------
; DSK_READ_CONFIG_FILE: Read config file in current directory
; -----------------------------------------------------------------------------
; Input:  HL = File name
;         DE = Destination address
;         B  = Max amount of bytes to read
; Output: A  = 0: Ok
;              1: File not found
;              2: Other error
;         B  = Amount of bytes read if no error
;         DE = Pointer after last byte read

DSK_READ_CONFIG_FILE:
    push hl
    push de
    push bc
    ld hl,DSK_CONFIG_DIR_S
    call HWF_OPEN_FILE_DIR
    pop bc
    pop de
    pop hl
    ld c,a
    cp 2
    ld a,1
    ret z
    ld a,c
    dec a
    ld a,2
    ret nz

    push de
    push bc
    call HWF_OPEN_FILE_DIR
    pop bc
    pop de
    ld c,a
    cp 2
    ld a,1
    ret z
    ld a,c
    or a
    ld a,2
    ret nz

    ex de,hl
    ld c,b
    ld b,0
    call HWF_READ_FILE
    ex de,hl
    ld b,0
    or a
    ret nz
    ld b,c
    ret

DSK_CONFIG_DIR_S:
    db "_USB",0


; -----------------------------------------------------------------------------
; DSK_READ_MAIN_CONFIG_FILE: Read config file in main directory
; -----------------------------------------------------------------------------
; Input:  HL = File name
;         DE = Destination address
;         B  = Max amount of bytes to read
; Output: A  = 0: Ok
;              1: File not found
;              2: Other error
;         B  = Amount of bytes read if no error, 0 on error
;         DE = Pointer after last byte read

DSK_READ_MAIN_CONFIG_FILE:
    call DSK_OPEN_MAIN_DIR
    or a
    ld a,1
    ld c,b
    ld b,0
    ret nz
    ld b,c

    call DSK_READ_CONFIG_FILE
    or a
    ret z
    ld b,0
    ret


; -----------------------------------------------------------------------------
; DSK_WRITE_CONFIG_FILE: Write config file in current directory
; -----------------------------------------------------------------------------
; Input:  HL = File name
;         DE = Source address
;         B  = Amount of bytes to write
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_CONFIG_FILE:
    push hl
    push de
    push bc
    ld hl,DSK_CONFIG_DIR_S
    call HWF_CREATE_DIR
    pop bc
    pop de
    pop hl
    or a
    ret nz

    push de
    push bc
    call HWF_CREATE_FILE
    pop bc
    pop hl
    or a
    ret nz

    ld c,b
    ld b,0
    call HWF_WRITE_FILE

    push af
    call HWF_CLOSE_FILE
    pop af
    ret


; -----------------------------------------------------------------------------
; DSK_WRITE_MAIN_CONFIG_FILE: Write config file in main directory
; -----------------------------------------------------------------------------
; Input:  HL = File name
;         DE = Source address
;         B  = Amount of bytes to read
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_MAIN_CONFIG_FILE:
    call DSK_OPEN_MAIN_DIR
    or a
    ld a,1
    ret nz

    jp DSK_WRITE_CONFIG_FILE


; -----------------------------------------------------------------------------
; DSK_CHANGE_DIR: Change the current directory
;                 (doesn't update config files)
; -----------------------------------------------------------------------------
; Input:  HL = Directory path, "dir/dir2/dir3", no starting or ending "/"
;         A  = 0 for relative to current, 1 for absolute
; Output: A  = 0: Ok
;              1: Directory not found
;              2: Other error

DSK_CHANGE_DIR:
    or a
    jr z,_DSK_CHANGE_DIR_REL

    push hl
    ld hl,DSK_ROOT_DIR_S
    call HWF_OPEN_FILE_DIR
    pop hl
    cp 1
    ld a,2
    ret nz
_DSK_CHANGE_DIR_REL:

_DSK_CHANGE_LOOP:
    call HWF_OPEN_FILE_DIR
    ld b,a
    or a
    ld a,2
    ret z
    ld a,b
    dec a
    ret nz

    ld a,(hl)
    inc hl
    or a
    jr nz,_DSK_CHANGE_LOOP

    xor a
    ret


; -----------------------------------------------------------------------------
; DSK_CHANGE_DIR_U: Change the current directoryand update config files
;
; This one is tricky. We can't update CURDIR until after we are sure that
; the directory change has been sucessful, but if we update a config file
; after setting our directory then it won't be set anymore! Also if we fail
; we should restore the previous directory.
;
; Thus we do it like this:
;
; 1. Read current content of CURDIR, save in memory
; 2. Set CURDIR contents to the directory we want to change to
; 3. Try to change to the directory, if successful, we're all set
; 4. On error changing the directory, set CURDIR to its previous contents
;    and change to it again
; -----------------------------------------------------------------------------
; Input:  HL = Directory path, "dir/dir2/dir3", no starting or ending "/"
;         A  = 0 for relative to current, 1 for absolute
; Output: A  = 0: Ok
;              1: Directory not found
;              2: Other error

DSK_CHANGE_DIR_U:
    ld iy,-65
    add iy,sp
    ld sp,iy
    call _DSK_CHANGE_DIR_U
    ld iy,65
    add iy,sp
    ld sp,iy
    ret

_DSK_CHANGE_DIR_U:
    push af
    push hl

    push iy
    pop de
    inc de
    ld hl,DSK_CURDIR_S
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    call CHPUT
    ld (iy),b

    pop hl
    push hl
    call BM_STRLEN
    pop de
    push de
    ld hl,DSK_CURDIR_S
    call DSK_WRITE_MAIN_CONFIG_FILE

    pop hl
    pop af
    call DSK_CHANGE_DIR
    or a
    ret z

    ld c,a
    ld a,(iy)
    or a
    ld a,c
    ret z

    push iy
    pop de
    inc de
    ld b,(iy)
    ld hl,DSK_CURDIR_S
    push af
    push de
    call DSK_WRITE_MAIN_CONFIG_FILE
    pop hl
    ld a,1
    call DSK_CHANGE_DIR
    pop af

    ret

DSK_CURDIR_S:
    db "CURDIR",0

