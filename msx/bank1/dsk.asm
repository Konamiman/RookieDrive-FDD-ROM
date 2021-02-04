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
;         B  = Amount of bytes read if no error
;         DE = Pointer after last byte read

DSK_READ_MAIN_CONFIG_FILE:
    call DSK_OPEN_MAIN_DIR
    or a
    ld a,1
    ret nz

    jp DSK_READ_CONFIG_FILE


; -----------------------------------------------------------------------------
; DSK_WRITE_CONFIG_FILE: Write config file in current directory
; -----------------------------------------------------------------------------
; Input:  HL = File name
;         DE = Source address
;         B  = Amount of bytes to read
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