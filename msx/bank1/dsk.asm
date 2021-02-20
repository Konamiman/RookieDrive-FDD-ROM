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
;         Z if ok, NZ if error
;         Cy = 0 if root directory was open, 1 if DSK_MAIN_DIR_S was open

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
    ret nz

    ld hl,DSK_MAIN_DIR_S
    call HWF_OPEN_FILE_DIR
    jr nz,_DSK_OPEN_MAIN_REOPEN_ROOT
    jr c,_DSK_OPEN_MAIN_WAS_MSX

_DSK_OPEN_MAIN_REOPEN_ROOT:
    ld hl,DSK_ROOT_DIR_S
    call HWF_OPEN_FILE_DIR
_DSK_OPEN_MAIN_END:
    or a    ;If error, set NZ; if ok, set Z and NC
    ret

_DSK_OPEN_MAIN_WAS_MSX:
    xor a
    scf
    ret

DSK_ROOT_DIR_S:
    db "/",0

DSK_MAIN_DIR_S:
    db "MSX"
DSK_ZERO_S:
    db 0


; -----------------------------------------------------------------------------
; DSK_READ_CONFIG_FILE: Read config file in current directory
; -----------------------------------------------------------------------------
; Input:  HL = File name
;         DE = Destination address
;         B  = Max amount of bytes to read
; Output: A  = 0: Ok
;              1: Other error
;              2: File not found
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
    ret nz
    ld a,1
    ret nc

    push de
    push bc
    call HWF_OPEN_FILE_DIR
    pop bc
    pop de
    ret nz
    ld a,1
    ret c

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
;              1: Other error
;              2: File not found
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
;         B  = Amount of bytes to write, if 0 delete the file
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

    ld a,b
    or a
    jr nz,_DSK_WRITE_CONFIG_FILE_GO

    call HWF_DELETE_FILE
    xor a
    ret

_DSK_WRITE_CONFIG_FILE_GO:
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
;         B  = Amount of bytes to write
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_MAIN_CONFIG_FILE:
    call DSK_OPEN_MAIN_DIR
    or a
    ld a,1
    ret nz

    jp DSK_WRITE_CONFIG_FILE


; -----------------------------------------------------------------------------
; DSK_WRITE_CURDIR_FILE: Write CURDIR config file in main directory
; -----------------------------------------------------------------------------
; Input:  HL = Address of content to write, zero-terminated
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_CURDIR_FILE:
    push hl
    call BM_STRLEN
    pop de
    ld hl,DSK_CURDIR_S
    jp DSK_WRITE_MAIN_CONFIG_FILE


; -----------------------------------------------------------------------------
; DSK_CHANGE_DIR: Change the current directory
;                 (doesn't update config files or work area)
; -----------------------------------------------------------------------------
; Input:  HL = Directory path, "dir/dir2/dir3", no starting or ending "/"
;              (the root dir is represented as an empty string)
;         A  = 0 for relative to current, 1 for absolute
; Output: A  = 0: Ok
;              1: Other error
;              2: Directory not found
;              3: It's a file, not a directory

DSK_CHANGE_DIR:
    or a
    jr z,_DSK_CHANGE_DIR_REL

    push hl
    ld hl,DSK_ROOT_DIR_S
    call HWF_OPEN_FILE_DIR
    pop hl
    ret nz

    ld a,(hl)
    or a
    ret z   ;Empty string = root dir, so we're done
_DSK_CHANGE_DIR_REL:

_DSK_CHANGE_LOOP:
    call HWF_OPEN_FILE_DIR
    ret nz
    ld a,3
    ret nc

    ld a,(hl)
    inc hl
    or a
    jr nz,_DSK_CHANGE_LOOP

    xor a
    ret


; -----------------------------------------------------------------------------
; DSK_CHANGE_DIR_U: Change the current directory
;                   and update config files and work area
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
;              1: Other error
;              2: Directory not found
;              3: It's a file, not a directory
;              4: Path is too long

DSK_CHANGE_DIR_U:
    push iy
    ld iy,-65
    add iy,sp
    ld sp,iy
    call _DSK_CHANGE_DIR_U
    ld iy,65
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_CHANGE_DIR_U:
    push af
    push hl

    ;If setting absolute dir we can check its length now

    or a
    jr z,_DSK_CHANGE_DIR_U_LENGTH_OK
    push hl
    call BM_STRLEN
    pop hl
    ld a,b
    cp BM_MAX_DIR_NAME_LENGTH+1
    jr c,_DSK_CHANGE_DIR_U_LENGTH_OK
    pop hl
    pop af
    ld a,4
    ret
_DSK_CHANGE_DIR_U_LENGTH_OK:

    ;Set work area as "no file mounted"

    call WK_GET_STORAGE_DEV_FLAGS
    and 0FEh
    call WK_SET_STORAGE_DEV_FLAGS

    ;Get current dir from CURDIR, save in memory

    push iy
    pop de
    inc de
    ld hl,DSK_CURDIR_S
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    ld (iy),b

    ;If setting relative dir check length now

    pop hl
    pop af
    or a
    jr nz,_DSK_CHANGE_DIR_U_UPD_CURDIR
    push hl
    call BM_STRLEN
    ld a,b
    add (iy)
    inc a   ;Account for the extra "/" to add
    cp BM_MAX_DIR_NAME_LENGTH+1
    jr c,_DSK_CHANGE_DIR_U_LENGTH_OK_2
    pop hl
    ld a,4
    ret
_DSK_CHANGE_DIR_U_LENGTH_OK_2:

    ;Also if setting relative dir:
    ;append dir to the one we have in memory

    push iy
    pop hl
    inc hl  ;Skip length
    ld e,(iy)
    ld d,0
    add hl,de
    ld (hl),'/'
    inc hl
    ex de,hl

    pop hl
    push hl
    call BM_STRLEN
    pop hl
    ld c,b
    ld b,0
    inc bc  ;Count the terminator too
    ldir

    push iy
    pop hl
    inc hl

    ;Save new dir into CURDIR,
    ;input: HL = new absolute dir

_DSK_CHANGE_DIR_U_UPD_CURDIR:
    call DSK_SET_CURDIR

    ;Try the actual dir change, return if ok

    ld a,1
    call DSK_CHANGE_DIR
    ret z

    ;Rewrite CURDIR with its old value,
    ;and change to the old directory again

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

    ;--- Set the value of CURDIR from HL, preserves HL

DSK_SET_CURDIR:
    push hl
    call BM_STRLEN
    pop de
    push de
    ld hl,DSK_CURDIR_S
    call DSK_WRITE_MAIN_CONFIG_FILE
    pop hl
    ret


; -----------------------------------------------------------------------------
; DSK_MOUNT: Mount a file in the current directory
;            and update config file and work area;
;            in case of failure it restores the previously mounted file.
;
; This one is tricky as DSK_CHANGE_DIR_U, but even more because every time we
; want to mount a file (the requested one or the previous one) we need to ensure
; that the value of CURDIR is set as the current directory.
; -----------------------------------------------------------------------------
; Input:  HL = File path
;         A  = 0: Mount as read-only if read-only flag is set
;              1: Force mount as read and write
;              2: Force mount as read-only
; Output: A  = 0: Ok
;              1: Other error
;              2: File not found
;              3: It's a directory, not a file

DSK_MOUNT:
    push iy
    ld iy,-65-15-1    ;65 for dir name+0, 15 for file length+name+0, 1 extra for read-only mode
    add iy,sp
    ld sp,iy
    call _DSK_MOUNT
    ld iy,65+15+1
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_MOUNT:
    ld (iy+65+15),a
    push hl

    ;Set work area as "no file mounted" for now

    call WK_GET_STORAGE_DEV_FLAGS
    and 0FEh
    call WK_SET_STORAGE_DEV_FLAGS

    ;Get current dir from CURDIR, save in memory

    push iy
    pop de
    ld hl,DSK_CURDIR_S
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    xor a
    ld (de),a

    ;Get current file from CURFILE, save in memory

    push iy
    pop hl
    ld de,65+1
    add hl,de   ;HL = Buffer for file name from CURFILE
    push hl
    ex de,hl
    ld hl,DSK_CURFILE_S
    call DSK_READ_MAIN_CONFIG_FILE
    pop hl
    dec hl      ;HL = Buffer for length of file name
    ld (hl),b
    xor a
    ld (de),a

    ;Set CURFILE with the new file to be mounted

    pop hl
    push hl
    pop de
    push de
    call BM_STRLEN
    ld hl,DSK_CURFILE_S
    call DSK_WRITE_MAIN_CONFIG_FILE

    ;Set current directory from CURDIR again

    push iy
    pop hl
    ld a,1
    call DSK_CHANGE_DIR
    or a
    pop hl  ;Name of file to mount
    ret nz  ;Should never occur but just in case

    ;Try to actually mount the file, return if ok

    push hl
    call HWF_OPEN_FILE_DIR
    pop hl
    jr nz,_DSK_MOUNT_ERR
    jp nc,_DSK_MOUNT_SET_WORK
    ld a,3
_DSK_MOUNT_ERR:
    ld (iy+65+15),0 ;Remount old file in auto-readonly mode
    push af ;Save the error we'll return at the end

    ;Restore old contents of CURFILE

    push iy
    pop hl
    ld de,65
    add hl,de
    ld b,(hl)
    inc hl
    ex de,hl
    ld hl,DSK_CURFILE_S
    call DSK_WRITE_MAIN_CONFIG_FILE
    pop hl  ;Error from mounting the requested file
    or a
    ld a,h
    ret nz
    push hl

    ;Set current directory from CURDIR again

    push iy
    pop hl
    ld a,1
    call DSK_CHANGE_DIR
    jr nz,_DSK_MOUNT_ERR_END  ;Should never occur but just in case

    ;Mount file from CURFILE again if there was any

    push iy
    pop hl
    ld de,65+1
    add hl,de
    ld a,(hl)
    or a
    jr z,_DSK_MOUNT_ERR_END
    push hl
    call HWF_OPEN_FILE_DIR
    pop hl
    call z,_DSK_MOUNT_SET_WORK  ;Assume it was a file, not a dir
    
    ;Jump here on error from HWF_OPEN_FILE_DIR

_DSK_MOUNT_ERR_END:
    pop af
    ret

    ;Set disk mounted flag in work area
    ;HL = File name

_DSK_MOUNT_SET_WORK:
    push af
    ld a,(iy+65+15)
    cp 2
    jr z,_DSK_MOUNT_SET_WORK_DO
    cp 1
    ld a,0
    jr z,_DSK_MOUNT_SET_WORK_DO
    call HWF_GET_FILE_ATTR
    dec a
    jr z,_DSK_MOUNT_SET_WORK_DO ;Error, assume not read-only
    ld a,b    ;Attributes byte, read-only in bit 0
    rla ;Now read-only in bit 1
    and 2

_DSK_MOUNT_SET_WORK_DO:
    ld b,a
    call WK_GET_STORAGE_DEV_FLAGS
    or 1+4  ;Disk present+disk has changed
    or b  ;Read-only flag (maybe)
    call WK_SET_STORAGE_DEV_FLAGS
    pop af
    ret

DSK_CURFILE_S:
    db "CURFILE",0


; -----------------------------------------------------------------------------
; DSK_GET_CURDIR: Get (and enter) the current directory
;
; - If config file CURDIR exists and the directory it contains exists: return it
; - Otherwise, return the main directory
;
; Doesn't modify the contents of CURFILE.
; -----------------------------------------------------------------------------
; Input:  HL = Address of 65 byte buffer for directory name
; Output: A  = 0: Ok
;              1: Error
;         B  = Length of name (not including terminator), 0 on error
;         DE = Pointer to terminator

DSK_GET_CURDIR:
    ex de,hl
    ld hl,DSK_CURDIR_S
    push de
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    jr nz,_DSK_GET_CURDIR_NO_CONFIG
    ld (de),a

    pop hl
    push hl
    push bc
    ld a,1
    call DSK_CHANGE_DIR
    pop bc
    or a
    jr nz,_DSK_GET_CURDIR_NO_CONFIG

    inc sp
    inc sp
    ret

_DSK_GET_CURDIR_NO_CONFIG:
    call DSK_OPEN_MAIN_DIR
    ld a,1
    jr nz,_DSK_OPEN_MAIN_DIR_EMPTY
    ld a,0
    jr nc,_DSK_OPEN_MAIN_DIR_EMPTY

    pop de
    push de
    ld hl,DSK_MAIN_DIR_S
    ld bc,13
    ldir
    pop hl
    call BM_STRLEN
    ex de,hl
    xor a
    ret

_DSK_OPEN_MAIN_DIR_EMPTY:
    pop de
    ld b,0
    ret


; -----------------------------------------------------------------------------
; DSK_REMOUNT: Mount again the current file (per CURDIR and CURFILE)
; -----------------------------------------------------------------------------
; Input:  HL = Address of 65 byte buffer for directory name
; Output: A  = 0: Ok
;              1: Other error
;              2: No CURDIR file, or directory doesn't exist
;              3: No CURFILE file, or file doesn't exist

DSK_REMOUNT:
    push iy
    ld iy,-65-13
    add iy,sp
    ld sp,iy
    call _DSK_REMOUNT
    ld iy,65+13
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_REMOUNT:
    call WK_GET_STORAGE_DEV_FLAGS   ;No disk mounted for now
    and 0FEh
    call WK_SET_STORAGE_DEV_FLAGS

    push iy
    pop de
    ld hl,DSK_CURDIR_S
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    ret nz
    ld (de),a

    push iy
    pop hl
    ld bc,65
    add hl,bc
    ex de,hl
    ld hl,DSK_CURFILE_S
    ld b,12
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    jr z,_DSK_REMOUNT_OK
    cp 1
    ret z
    ld a,3
    ret
_DSK_REMOUNT_OK:
    ld (de),a

    push iy
    pop hl
    ld a,1
    call DSK_CHANGE_DIR
    cp 1
    ret z
    cp 2
    ret z
    cp 3
    ld a,1
    ret z  ;It's a file, not a dir

    push iy
    pop hl
    ld bc,65
    add hl,bc
    call HWF_OPEN_FILE_DIR
    jr z,_DSK_REMOUNT_OK_2
    cp 1
    ret z
    ld a,3
    ret

_DSK_REMOUNT_OK_2:
    ld a,1
    ret c   ;It's a dir, not a file

    call HWF_GET_FILE_ATTR
    dec a
    jr z,_DSK_REMOUNT_OK_3 ;Error, assume not read-only
    ld a,b    ;Attributes byte, read-only in bit 0
    rla ;Now read-only in bit 1
    and 2

_DSK_REMOUNT_OK_3:
    ld b,a
    call WK_GET_STORAGE_DEV_FLAGS
    or 1+4  ;Disk present+disk has changed
    or b  ;Read-only flag (maybe)
    call WK_SET_STORAGE_DEV_FLAGS

    xor a
    ret
