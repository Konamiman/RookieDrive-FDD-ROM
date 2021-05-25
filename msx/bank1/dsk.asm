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
;
; The file is read until B bytes have been read, the end of the file
; is reached, or a CR or LF character is found, whatever happens firts
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
    push hl
    call HWF_READ_FILE
    ex de,hl
    pop hl
    ld b,0
    or a
    ret nz

    ;Search for CR or LF

    ld a,c
    or a
    jr z,_DSK_READ_CONFIG_FILE_END

    ld b,c
    ld c,0
_DSK_READ_CONFIG_FILE_LOOP:
    ld a,(hl)
    cp 13
    jr z,_DSK_READ_CONFIG_FILE_END
    cp 10
    jr z,_DSK_READ_CONFIG_FILE_END
    inc hl
    inc c
    djnz _DSK_READ_CONFIG_FILE_LOOP

_DSK_READ_CONFIG_FILE_END:
    ex de,hl
    xor a
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
; DSK_WRITE_BOOTDIR_FILE: Write BOOTDIR config file in main directory
; -----------------------------------------------------------------------------
; Input:  HL = Address of content to write, zero-terminated
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_BOOTDIR_FILE:
    push hl
    call BM_STRLEN
    pop de
    ld hl,DSK_BOOTDIR_S
    jp DSK_WRITE_MAIN_CONFIG_FILE


; -----------------------------------------------------------------------------
; DSK_WRITE_BOOTMODE_FILE: Write BOOTMODE config file in main directory
; -----------------------------------------------------------------------------
; Input:  A  = Value to write
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_BOOTMODE_FILE:
    push af
    ld hl,1
    add hl,sp
    ex de,hl
    ld b,1
    ld hl,DSK_BOOTMODE_S
    call DSK_WRITE_MAIN_CONFIG_FILE
    pop hl
    ret


; -----------------------------------------------------------------------------
; DSK_WRITE_DEFFILE_FILE: Write DEFFILE config file in current directory
; -----------------------------------------------------------------------------
; Input:  HL = Address of content to write, zero-terminated
; Output: A  = 0: Ok
;              1: Error

DSK_WRITE_DEFFILE_FILE:
    push hl
    call BM_STRLEN
    pop de
    ld hl,DSK_DEFFILE_S
    jp DSK_WRITE_CONFIG_FILE


; -----------------------------------------------------------------------------
; DSK_READ_DEFFILE_FILE: Read DEFFILE config file from current directory
; -----------------------------------------------------------------------------
; Input:  HL = Address where to read the file
; Output: A  = 0: Ok
;              1: Other error
;              2: File not found

DSK_READ_DEFFILE_FILE:
    ex de,hl
    ld hl,DSK_DEFFILE_S
    ld b,12
    call DSK_READ_CONFIG_FILE
    or a
    ret nz
    ld (de),a
    ret
    

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
    ld a,(iy)
    ld e,a
    ld d,0
    or a
    jr z,_DSK_CHANGE_DIR_U_APPEND_OK ;It's root dir
    add hl,de
    ld (hl),'/'
    inc hl
_DSK_CHANGE_DIR_U_APPEND_OK: 
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
    call _DSK_SET_CURDIR

    ;Try the actual dir change, return if ok

    ld a,1
    push hl
    call DSK_CHANGE_DIR
    pop hl
    jr z,_DSK_SET_CURDIR_OK

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

_DSK_SET_CURDIR:
    push hl
    call BM_STRLEN
    pop de
    push de
    ld hl,DSK_CURDIR_S
    call DSK_WRITE_MAIN_CONFIG_FILE
    pop hl
    ret

    ;--- Dir change ok: delete CURFILE since nothing is mounted now,
    ;    and set dir again.

_DSK_SET_CURDIR_OK:
    push hl
    ld hl,DSK_CURDIR_S
    ld de,DSK_ZERO_S
    call DSK_WRITE_MAIN_CONFIG_FILE
    pop hl
    jp _DSK_SET_CURDIR


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
    ld b,13
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


; -----------------------------------------------------------------------------
; DSK_GET_DEFAULT: Get the name of the default file in current directory
; -----------------------------------------------------------------------------
; Input:  HL = Address of 13 byte buffer for file name
; Output: A  = 0: Ok
;              1: Other error
;              2: File not found (directory is empty)

DSK_GET_DEFAULT:
    push iy
    ld iy,-32
    add iy,sp
    ld sp,iy
    call _DSK_GET_DEFAULT
    ld iy,32
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_GET_DEFAULT:

    ;* First check if a DEFAULT.DSK file exists

    push hl
    call DSK_DEFAULT_EXISTS
    pop hl
    cp 1
    ret z

    or a
    jr nz,_DSK_GET_DEFAULT_NODEF

    ; DEFAULT.DSK exists, copy to destination for now

    push hl
    ex de,hl
    ld hl,DSK_DEFAULT_S
    ld bc,12
    ldir
    pop hl
    jr _DSK_GET_DEFAULT_2

    ; DEFAULT.DSK doesn't exist, see if any suitable file exists at all

_DSK_GET_DEFAULT_NODEF:
    push hl
    push iy
    pop hl
    xor a
    call HWF_FIND_NTH_FILE
    pop hl
    or a
    ret nz

    push hl
    ex de,hl
    push iy
    pop hl
    call BM_GENERATE_FILENAME
    ld (hl),0
    pop hl

    ;* Now we have either DEFAULT.DSK or the name of the first existing file
    ;  copied to the destination address. See if there's a suitable DEFFILE file
    ;  and if so extract and use its contents, if not just return.
    ;  No errors will be returned past this point.

_DSK_GET_DEFAULT_2:
    push hl
    push iy
    pop de
    ld hl,DSK_DEFFILE_S
    ld b,12
    call DSK_READ_CONFIG_FILE
    pop hl
    or a
    ld a,0
    ret nz
    ld (de),a
    ld a,b
    or a
    ret z

    ; We got a file name from DEFFILE, so copy its contents
    ; to the output buffer.

    ex de,hl
    push iy
    pop hl
    ld bc,13
    ldir

    xor a
    ret

DSK_DEFFILE_S:
    db "DEFFILE",0


; -----------------------------------------------------------------------------
; DSK_DEFAULT_EXISTS: Does the DEFAULT.DSK file exist in current directory?
;
; We need to do the search in a weird way because there's no way to initiate
; a file search without specifying 
; -----------------------------------------------------------------------------
; Input:  IY = Address of 32 byte buffer for directory entry
; Output: A  = 0: Ok
;              1: Other error
;              2: File doesn't exist

DSK_DEFAULT_EXISTS:
    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    ld hl,DSK_DEFAST_S
    call CH_WRITE_STRING
    ld a,CH_CMD_FILE_OPEN
    out (CH_COMMAND_PORT),a

_DSK_DEFAULT_EXISTS_LOOP:
    call CH_WAIT_INT_AND_GET_RESULT
    ld b,a
    cp USB_ERR_MISS_FILE
    ld a,2
    ret z
    ld a,b
    cp CH_ST_INT_DISK_READ
    ld a,1
    ret nz

    push iy
    pop hl
    call CH_READ_DATA
    ld a,b
    cp 32
    ld a,1
    ret nz

    ld a,(iy+10)
    cp "K"
    jr nz,_DSK_DEFAULT_EXISTS_NEXT

    ld a,(iy+11)
    and 11010b  ;Directory, hidden or volume?
    ld a,2
    ret nz

    xor a
    ret

_DSK_DEFAULT_EXISTS_NEXT:
    ld a,CH_CMD_FILE_ENUM_GO
    out (CH_COMMAND_PORT),a
    jr _DSK_DEFAULT_EXISTS_LOOP

DSK_DEFAST_S:
    db "DEFAULT.DS*",0
DSK_DEFAULT_S:
    db "DEFAULT.DSK",0


; -----------------------------------------------------------------------------
; DSK_GET_BOOTDIR: Get the boot directory
;
; Hidden files and files starting with "_" don't count.
; -----------------------------------------------------------------------------
; Input:  HL = Address of 64 byte buffer for the directory
; Output: A  = 0: Ok
;              1: Other error
;              2: File doesn't exist

DSK_GET_BOOTDIR:
    ld (hl),0
    ex de,hl
    ld hl,DSK_BOOTDIR_S
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    ret nz
    ld (de),a
    ret

DSK_BOOTDIR_S:
    db "BOOTDIR",0


; -----------------------------------------------------------------------------
; DSK_CHANGE_BOOTDIR: Change to the boot directory or the main directory
; -----------------------------------------------------------------------------
; Output: A  = 0: Ok
;              1: Error

DSK_CHANGE_BOOTDIR:
    push iy
    ld iy,-64
    add iy,sp
    ld sp,iy
    call _DSK_CHANGE_BOOTDIR
    ld iy,64
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_CHANGE_BOOTDIR:
    push iy
    pop hl
    call DSK_GET_BOOTDIR
    or a
    jp nz,_DSK_CHANGE_BOOTDIR_ERR

    push iy
    pop hl
    ld a,1
    call DSK_CHANGE_DIR_U  
    or a
    ret z

    ; BOOTDIR doesn't exist or can't change to the dir it points to,
    ; so fallback to setting the main dir

_DSK_CHANGE_BOOTDIR_ERR:
    ld hl,DSK_MAIN_DIR_S
    ld a,1
    call DSK_CHANGE_DIR_U
    or a
    ret z

    ld hl,DSK_ROOT_DIR_S
    jp DSK_CHANGE_DIR_U


; -----------------------------------------------------------------------------
; DSK_GET_BOOTMODE: Get current boot mode
; -----------------------------------------------------------------------------
; Output: A  = Boot mode (1 to 4)

DSK_GET_BOOTMODE:
    push iy
    ld iy,-1
    add iy,sp
    ld sp,iy
    call _DSK_GET_BOOTMODE
    ld iy,1
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_GET_BOOTMODE:
    ld hl,DSK_BOOTMODE_S
    push iy
    pop de
    ld b,1
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    ld a,1
    ret nz
    
    ld a,b
    or a
    ld a,1
    ret z

    ;Return value read minus "0" if it's "1" to "4", return 1 otherwise

    ld a,(iy)
    sub "0"
    ld b,a
    or a
    ld a,1
    ret z
    ld a,b
    cp 5
    ret c
    ld a,1
    ret

DSK_BOOTMODE_S:
    db "BOOTMODE",0


; -----------------------------------------------------------------------------
; DSK_DO_BOOT_PROC: Do the boot procedure
; -----------------------------------------------------------------------------
; Output: A  = 0: Do the computer boot procedure
;                 (on boot mode 1 jump to boot menu)
;              1: Do the device change boot procedure (always return)

DSK_DO_BOOT_PROC:
    push iy
    ld iy,-13
    add iy,sp
    ld sp,iy
    call _DSK_DO_BOOT_PROC
    ld iy,13
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_DO_BOOT_PROC:
    ld (iy),a

    or a
    jr nz,_DSK_DO_BOOT_PROC_2

    ;When booting computer:
    ;If TAB is pressed, force boot mode 1

    ld de,7
    ld hl,NEWKEY
    add hl,de
    ld a,(hl)
    and 8
    jr z,_DSK_DO_BOOT_1
_DSK_DO_BOOT_PROC_2:

    call WK_GET_STORAGE_DEV_FLAGS   ;No disk mounted for now
    and 0FEh
    call WK_SET_STORAGE_DEV_FLAGS

    ld a,(iy)
    or a
    jr nz,_DSK_DO_BOOT_PROC_3

    call DSK_TEST_DEL_TMP_BOOT_FILE
    or a
    jp z,_DSK_DO_BOOT_4

_DSK_DO_BOOT_PROC_3:
    call DSK_GET_BOOTMODE

    dec a
    jr z,_DSK_DO_BOOT_1
    dec a
    jr z,_DSK_DO_BOOT_2
    dec a
    jr z,_DSK_DO_BOOT_3
    jr _DSK_DO_BOOT_4


    ;* Boot mode 1: 
    ;  - Set boot dir
    ;  - If doing computer boot, show boot menu

_DSK_DO_BOOT_1:
    call DSK_CHANGE_BOOTDIR
    or a
    ret nz

    ld a,(iy)
    or a
    ret nz

    xor a
    jp DO_BOOT_MENU


    ;* Boot mode 2: 
    ;  - Set boot dir and return

_DSK_DO_BOOT_2:
    jp DSK_CHANGE_BOOTDIR


    ;* Boot mode 3:
    ;  - Set boot dir
    ;  - Mount default file

_DSK_DO_BOOT_3:
    call DSK_CHANGE_BOOTDIR
    or a
    ret nz

    push iy
    pop hl
    inc hl
    inc hl
    push hl
    call DSK_GET_DEFAULT
    pop hl
    or a
    ret nz

    ;We need to set the dir again after DSK_GET_DEFAULT
    ;since it will have read a config file.
    push hl
    call DSK_CHANGE_BOOTDIR
    pop hl
    or a
    ret nz

    xor a
    jp DSK_MOUNT


    ; * Boot mode 4:
    ; - Remount per CURDIR and CURFILE
    ; - On error, fallback to mode 3

_DSK_DO_BOOT_4:
    call DSK_REMOUNT
    or a
    ret z
    jr _DSK_DO_BOOT_3


; -----------------------------------------------------------------------------
; DSK_READ_CURDIR_FILE: Read the CURDIR config file in main directory
; -----------------------------------------------------------------------------
; Input:  DE = Destination address
; Output: A  = 0: Ok
;              1: Other error
;              2: File not found
;         B  = Amount of bytes read if no error, 0 on error
;         DE = Pointer to the zero terminator

DSK_READ_CURDIR_FILE:
    ld hl,DSK_CURDIR_S
    ld b,64
    jr _DSK_READ_FILE


; -----------------------------------------------------------------------------
; DSK_READ_CURFILE_FILE: Read the CURFILE config file in main directory
; -----------------------------------------------------------------------------
; Input:  DE = Destination address
; Output: A  = 0: Ok
;              1: Other error
;              2: File not found
;         B  = Amount of bytes read if no error, 0 on error
;         DE = Pointer to the zero terminator

DSK_READ_CURFILE_FILE:
    ld hl,DSK_CURFILE_S
    ld b,12
_DSK_READ_FILE:
    call DSK_READ_MAIN_CONFIG_FILE
    push af
    xor a
    ld (de),a
    pop af
    ret


; -----------------------------------------------------------------------------
; DSK_CLOSE_FILE: Close the current file, delete CURFILE, and update work area
; -----------------------------------------------------------------------------

DSK_CLOSE_FILE:
    call HWF_CLOSE_FILE
    ld hl,DSK_CURFILE_S
    ld b,0
    call DSK_WRITE_MAIN_CONFIG_FILE
    call WK_GET_STORAGE_DEV_FLAGS
    and 0FEh
    call WK_SET_STORAGE_DEV_FLAGS
    ret


DSK_REMOUNT_DIR:
    push iy
    ld iy,-65
    add iy,sp
    ld sp,iy
    call _DSK_REMOUNT_DIR
    ld iy,65
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_REMOUNT_DIR:
    push iy
    pop de
    ld hl,DSK_CURDIR_S
    ld b,64
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    jp nz,DSK_OPEN_MAIN_DIR
    ld (de),a

    push iy
    pop hl
    ld a,1
    call DSK_CHANGE_DIR
    or a
    ret z
    jp DSK_OPEN_MAIN_DIR


; -----------------------------------------------------------------------------
; DSK_CREATE_TMP_BOOT_FILE: Create the temporary boot file
; -----------------------------------------------------------------------------
; Input:  -
; Output: A  = 0: Ok
;              1: Error

DSK_CREATE_TMP_BOOT_FILE:
    ld hl,DSK_TMP4_S
    ld de,DSK_1_S
    ld b,1
    jp DSK_WRITE_MAIN_CONFIG_FILE

DSK_TMP4_S:
    db "TMP4",0
DSK_1_S:
    db "1"


; -----------------------------------------------------------------------------
; DSK_TEST_DEL_TMP_BOOT_FILE: Checks if the temporary boot file exists,
;                             and deletes it
; -----------------------------------------------------------------------------
; Input:  -
; Output: A  = 0: Ok, file existed
;              1: Error
;              2: Ok, file didn't exist

DSK_TEST_DEL_TMP_BOOT_FILE:
    push iy
    ld iy,-1
    add iy,sp
    ld sp,iy
    call _DSK_TEST_DEL_TMP_BOOT_FILE
    ld iy,1
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_TEST_DEL_TMP_BOOT_FILE:
    ld hl,DSK_TMP4_S
    push iy
    pop de
    ld b,1
    call DSK_READ_MAIN_CONFIG_FILE

    or a    ;Not found or other error?
    ret nz

    ld hl,DSK_TMP4_S
    ld b,0
    call DSK_WRITE_MAIN_CONFIG_FILE
    xor a
    ret


; -----------------------------------------------------------------------------
; DSK_SET_OR_UNSET_CAPS_LIT: Set or unset the CAPS lit on file access setting,
;                            creating or deleting the NOCAPS config file
; -----------------------------------------------------------------------------
; Input: A = 0 to unset, A = 1 to set
; Output: 0 = Ok, 1 = Error

DSK_SET_OR_UNSET_CAPS_LIT:
    xor 1
    ld b,a
    ld hl,DSK_NOCAPS_S
    ld de,DSK_1_S
    jp DSK_WRITE_MAIN_CONFIG_FILE

DSK_NOCAPS_S:
    db "NOCAPS",0


; -----------------------------------------------------------------------------
; DSK_TEST_CAPS_LIT: Check the CAPS lit on file access setting
;                    by tryig to read the NOCAPS config file
; -----------------------------------------------------------------------------
; Input: -
; Output: A = 0 if unset, 1 if set or error

DSK_TEST_CAPS_LIT:
    push iy
    ld iy,-1
    add iy,sp
    ld sp,iy
    call _DSK_TEST_CAPS_LIT
    ld iy,1
    add iy,sp
    ld sp,iy
    pop iy
    ret

_DSK_TEST_CAPS_LIT:
    ld hl,DSK_NOCAPS_S
    push iy
    pop de
    ld b,1
    call DSK_READ_MAIN_CONFIG_FILE
    or a
    ret z
    ld a,1
    ret


; -----------------------------------------------------------------------------
; DSK_UPDATE_CAPS_LIT_WK: Update work area flag for the CAPS lit on file
;                         access setting depending on the NOCAPS file existence
; -----------------------------------------------------------------------------

DSK_UPDATE_CAPS_LIT_WK:
    push bc
    call DSK_TEST_CAPS_LIT
    rla
    rla
    rla
    and 00001000b
    ld b,a
    call WK_GET_STORAGE_DEV_FLAGS
    and 11110111b
    or b
    call WK_SET_STORAGE_DEV_FLAGS
    pop bc
    ret


; -----------------------------------------------------------------------------
; DSK_TEST_CAPS_LIT_WK: Check if CAPS lite on file access is set
;                       by reading work area
; -----------------------------------------------------------------------------
; Input: -
; Output: Z if unset, NZ if set

DSK_TEST_CAPS_LIT_WK:
    call WK_GET_STORAGE_DEV_FLAGS
    and 00001000b
    ret


; -----------------------------------------------------------------------------
; DSK_INIT_WK_FOR_STORAGE_DEV: Initialize work area for a storage device
; -----------------------------------------------------------------------------

DSK_INIT_WK_FOR_STORAGE_DEV:
    call WK_INIT_FOR_STORAGE_DEV
    call DSK_UPDATE_CAPS_LIT_WK
    ret
