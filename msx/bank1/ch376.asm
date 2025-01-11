; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains all the code that depends on the CH376.
; To adapt the ROM to use a different USB host controller you need to:
;
; 1. Create a new source file.

; 2. Copy the HW_IMPL_* constants and set their values as appropriate,
;    depending on which routines you are implementing.
;
; 3. Implement all the HW_* routines in the new file,
;    except those for which you have set HW_IMPL_* to 0.
;
; 4. Include the new file in rookiefdd.asm, replacing the file labeled as
;    "USB host hardware dependant code".
;
; All the code in this file is stateless: work area is not used,
; all the required information is passed in registers or buffers.


; -----------------------------------------------------------------------------
; Optional routine implementation flags
; -----------------------------------------------------------------------------
;
; The CH376 has built-in shortcuts for some common USB operations,
; and this BIOS take advantage of this.
; If you are adapting this BIOS to a different USB host hardware,
; you can implement the same routines if the hardware provides the same
; shortcuts, or leave the constants to 0 if not.
;
; HW_IMPL_<routine> needs to be 1 if HW_<routine> is implemented.

HW_IMPL_GET_DEV_DESCR: equ 1
HW_IMPL_GET_CONFIG_DESCR: equ 1
HW_IMPL_SET_CONFIG: equ 1
HW_IMPL_SET_ADDRESS: equ 1
HW_IMPL_CONFIGURE_NAK_RETRY: equ 1


; -----------------------------------------------------------------------------
; Constant definitions
; -----------------------------------------------------------------------------

;--- CH376 port to Z80 ports mapping

    if USE_ALTERNATIVE_PORTS
CH_DATA_PORT: equ 22h
CH_COMMAND_PORT: equ 23h    
    else
CH_DATA_PORT: equ 20h
CH_COMMAND_PORT: equ 21h
    endif

;--- Commands

CH_CMD_GET_IC_VER: equ 01h
CH_CMD_RESET_ALL: equ 05h
CH_CMD_CHECK_EXIST: equ 06h
CH_CMD_READ_VAR8: equ 0Ah
CH_CMD_SET_RETRY: equ 0Bh
CH_CMD_WRITE_VAR8: equ 0Bh
CH_CMD_READ_VAR32: equ 0Ch
CH_CMD_WRITE_VAR32: equ 0Dh
CH_CMD_DELAY_100US: equ 0Fh
CH_CMD_SET_USB_ADDR: equ 13h
CH_CMD_SET_USB_MODE: equ 15h
CH_CMD_TEST_CONNECT: equ 16h
CH_CMD_ABORT_NAK: equ 17h
CH_CMD_GET_STATUS: equ 22h
CH_CMD_RD_USB_DATA0: equ 27h
CH_CMD_WR_HOST_DATA: equ 2Ch
CH_CMD_WR_REQ_DATA: equ 2Dh
CH_CMD_SET_FILE_NAME: equ 2Fh
CH_CMD_DISK_CONNECT: equ 30h
CH_CMD_DISK_MOUNT: equ 31h
CH_CMD_FILE_OPEN: equ 32h
CH_CMD_FILE_ENUM_GO: equ 33h
CH_CMD_FILE_CREATE: equ 34h
CH_CMD_FILE_ERASE: equ 35h
CH_CMD_FILE_CLOSE: equ 36h
CH_CMD_DIR_INFO_READ: equ 37h
CH_CMD_BYTE_LOCATE: equ 39h
CH_CMD_BYTE_READ: equ 3Ah
CH_CMD_BYTE_RD_GO: equ 3Bh
CH_CMD_BYTE_WRITE: equ 3Ch
CH_CMD_BYTE_WRITE_GO: equ 3Dh
CH_CMD_DIR_CREATE: equ 40h
CH_CMD_SET_ADDRESS: equ 45h
CH_CMD_GET_DESCR: equ 46h
CH_CMD_SET_CONFIG: equ 49h
CH_CMD_ISSUE_TKN_X: equ 4Eh

;--- PIDs

CH_PID_SETUP: equ 0Dh
CH_PID_IN: equ 09h
CH_PID_OUT: equ 01h

;--- Status codes

CH_ST_INT_SUCCESS: equ 14h
CH_ST_INT_CONNECT: equ 15h
CH_ST_INT_DISCONNECT: equ 16h
CH_ST_INT_BUF_OVER: equ 17h
CH_ST_INT_DISK_READ: equ 1Dh
CH_ST_INT_DISK_WRITE: equ 1Eh
CH_ST_INT_DISK_ERR: equ 1Fh
CH_ST_RET_SUCCESS: equ 51h
CH_ST_RET_ABORT: equ 5Fh


; -----------------------------------------------------------------------------
; Mandatory routines
; -----------------------------------------------------------------------------   

; -----------------------------------------------------------------------------
; HW_TEST: Check if the USB host controller hardware is operational
; -----------------------------------------------------------------------------
; Output: Cy = 0 if hardware is operational, 1 if it's not

HW_TEST:
    if USE_FAKE_STORAGE_DEVICE
    or a
    ret
    endif

    if USE_ROM_AS_DISK
    or a
    ret
    endif

    ld a,34h
    call _HW_TEST_DO
    scf
    ret nz

    ld a,89h
    call _HW_TEST_DO
    scf
    ret nz

    or a
    ret

_HW_TEST_DO:
    ld b,a
    ld a,CH_CMD_CHECK_EXIST
    out (CH_COMMAND_PORT),a
    ld a,b
    xor 0FFh
    out (CH_DATA_PORT),a
    in a,(CH_DATA_PORT)
    cp b
    ret


; -----------------------------------------------------------------------------
; HW_RESET: Reset the USB controller hardware
;
; If a device is connected performs a bus reset that leaves the device
; in the "Default" state.
; -----------------------------------------------------------------------------
; Input:  -
; Output: A = 1 if a USB device is connected
;             -1 if no USB device is connected
;         Cy = 1 if reset failed

HW_RESET:

    ;Clear the CH376 data buffer in case a reset was made
    ;while it was in the middle of a data transfer operation
    ld b,64
_HW_RESET_CLEAR_DATA_BUF:
    in a,(CH_DATA_PORT)
    djnz _HW_RESET_CLEAR_DATA_BUF

    ld a,CH_CMD_RESET_ALL
    out (CH_COMMAND_PORT),a

    if USING_ARDUINO_BOARD
    ld bc,1000
_HW_RESET_WAIT:
    dec bc
    ld a,b
    or c
    jr nz,_HW_RESET_WAIT
    else
    ld bc,350
    call CH_DELAY
    endif

    call CH_DO_SET_NOSOF_MODE
    ret c

    ld a,CH_CMD_TEST_CONNECT
    out (CH_COMMAND_PORT),a
_CH_WAIT_TEST_CONNECT:
    in a,(CH_DATA_PORT)
    or a
    jr z,_CH_WAIT_TEST_CONNECT
    cp CH_ST_INT_DISCONNECT
    ld a,-1
    ret z

    jp HW_BUS_RESET


; -----------------------------------------------------------------------------
; HW_DEV_CHANGE: Check for changes in the device connection
;
; The returned status is relative to the last time that the routine
; was called.
;
; If a device has been connected it performs a bus reset that leaves the device
; in the "Default" state.
; -----------------------------------------------------------------------------
; Input:  -
; Output: A = 1 if a USB device has been connected
;             0 if no change has been detected
;             -1 if the USB device has been disconnected
;         Cy = 1 if bus reset failed

HW_DEV_CHANGE:
    call CH_CHECK_INT_IS_ACTIVE
    ld a,0
    ret nz
    
    call CH_GET_STATUS
    cp CH_ST_INT_CONNECT
    jp z,HW_BUS_RESET
    cp CH_ST_INT_DISCONNECT
    jp z,CH_DO_SET_NOSOF_MODE

    xor a
    ret


; -----------------------------------------------------------------------------
; HW_CONTROL_TRANSFER: Perform a USB control transfer on endpoint 0
;
; The size and direction of the transfer are taken from the contents
; of the setup packet.
; -----------------------------------------------------------------------------
; Input:  HL = Address of a 8 byte buffer with the setup packet
;         DE = Address of the input or output data buffer
;         A  = Device address
;         B  = Maximum packet size for endpoint 0
; Output: A  = USB error code
;         BC = Amount of data actually transferred (if IN transfer and no error)

HW_CONTROL_TRANSFER:
    call CH_SET_TARGET_DEVICE_ADDRESS

    push hl
    push bc
    push de

    ld b,8
    call CH_WRITE_DATA  ;Write SETUP data packet    

    xor a
    ld e,0
    ld b,CH_PID_SETUP
    call CH_ISSUE_TOKEN

    call CH_WAIT_INT_AND_GET_RESULT
    pop hl  ;HL = Data address (was DE)
    pop de  ;D  = Endpoint size (was B)
    pop ix  ;IX = Address of setup packet (was HL)
    or a
    ld bc,0
    ret nz  ;DONE if error

    ld c,(ix+6)
    ld b,(ix+7) ;BC = Data length
    ld a,b
    or c
    jr z,_CH_CONTROL_STATUS_IN_TRANSFER
    ld e,0      ;E  = Endpoint number
    scf         ;Use toggle = 1
    bit 7,(ix)
    jr z,_CH_CONTROL_OUT_TRANSFER

_CH_CONTROL_IN_TRANSFER:
    call CH_DATA_IN_TRANSFER
    or a
    ret nz

    push bc

    ld b,0
    call CH_WRITE_DATA
    ld e,0
    ld b,CH_PID_OUT
    ld a,40h    ;Toggle bit = 1
    call CH_ISSUE_TOKEN
    call CH_WAIT_INT_AND_GET_RESULT

    pop bc
    ret

_CH_CONTROL_OUT_TRANSFER:
    call CH_DATA_OUT_TRANSFER
    or a
    ret nz

_CH_CONTROL_STATUS_IN_TRANSFER:
    push bc

    ld e,0
    ld b,CH_PID_IN
    ld a,80h    ;Toggle bit = 1
    call CH_ISSUE_TOKEN
    ld hl,0
    call CH_READ_DATA
    call CH_WAIT_INT_AND_GET_RESULT

    pop bc
    ret


; -----------------------------------------------------------------------------
; HW_DATA_IN_TRANSFER: Perform a USB data IN transfer
; -----------------------------------------------------------------------------
; Input:  HL = Address of a buffer for the received data
;         BC = Data length
;         A  = Device address
;         D  = Maximum packet size for the endpoint
;         E  = Endpoint number
;         Cy = Current state of the toggle bit
; Output: A  = USB error code
;         BC = Amount of data actually received (only if no error)
;         Cy = New state of the toggle bit (even on error)

HW_DATA_IN_TRANSFER:
    call CH_SET_TARGET_DEVICE_ADDRESS

; This entry point is used when target device address is already set
CH_DATA_IN_TRANSFER:
    ld a,0
    rra     ;Toggle to bit 7 of A
    ld ix,0 ;IX = Received so far count
    push de
    pop iy  ;IY = EP size + EP number

_CH_DATA_IN_LOOP:
    push af ;Toggle in bit 7
    push bc ;Remaining length

    ld e,iyl
    ld b,CH_PID_IN
    call CH_ISSUE_TOKEN

    call CH_WAIT_INT_AND_GET_RESULT
    or a
    jr nz,_CH_DATA_IN_ERR   ;DONE if error

    call CH_READ_DATA
    ld c,b
    ld b,0
    add ix,bc   ;Update received so far count
_CH_DATA_IN_NO_MORE_DATA:

    pop de
    pop af
    xor 80h     ;Update toggle
    push af
    push de

    ld a,c
    or a
    jr z,_CH_DATA_IN_DONE    ;DONE if no data received

    ex (sp),hl  ;Now HL = Remaining data length
    or a
    sbc hl,bc   ;Now HL = Updated remaning data length
    ld a,h
    or l
    ex (sp),hl  ;Remaining data length is back on the stack
    jr z,_CH_DATA_IN_DONE    ;DONE if no data remaining

    ld a,c
    cp iyh
    jr c,_CH_DATA_IN_DONE    ;DONE if transferred less than the EP size

    pop bc
    pop af  ;We need this to pass the next toggle to CH_ISSUE_TOKEN

    jr _CH_DATA_IN_LOOP

;Input: A=Error code (if ERR), in stack: remaining length, new toggle
_CH_DATA_IN_DONE:
    xor a
_CH_DATA_IN_ERR:
    ld d,a
    pop bc
    pop af
    rla ;Toggle back to Cy
    ld a,d
    push ix
    pop bc
    ret


; -----------------------------------------------------------------------------
; HW_DATA_OUT_TRANSFER: Perform a USB data OUT transfer
; -----------------------------------------------------------------------------
; Input:  HL = Address of a buffer for the data to be sent
;         BC = Data length
;         A  = Device address
;         D  = Maximum packet size for the endpoint
;         E  = Endpoint number
;         Cy = Current state of the toggle bit
; Output: A  = USB error code
;         Cy = New state of the toggle bit (even on error)

HW_DATA_OUT_TRANSFER:
    call CH_SET_TARGET_DEVICE_ADDRESS

; This entry point is used when target device address is already set
CH_DATA_OUT_TRANSFER:
    ld a,0
    rra     ;Toggle to bit 6 of A
    rra
    push de
    pop iy  ;IY = EP size + EP number

_CH_DATA_OUT_LOOP:
    push af ;Toggle in bit 6
    push bc ;Remaining length

    ld a,b 
    or a
    ld a,iyh
    jr nz,_CH_DATA_OUT_DO
    ld a,c
    cp iyh
    jr c,_CH_DATA_OUT_DO
    ld a,iyh

_CH_DATA_OUT_DO:
    ;Here, A = Length of the next transfer: min(remaining length, EP size)

    ex (sp),hl
    ld e,a
    ld d,0
    or a
    sbc hl,de
    ex (sp),hl     ;Updated remaining data length to the stack

    ld b,a
    call CH_WRITE_DATA

    pop bc
    pop af  ;Retrieve toggle
    push af
    push bc

    ld e,iyl
    ld b,CH_PID_OUT
    call CH_ISSUE_TOKEN

    call CH_WAIT_INT_AND_GET_RESULT
    or a
    jr nz,_CH_DATA_OUT_DONE   ;DONE if error

    pop bc
    pop af
    xor 40h     ;Update toggle
    push af

    ld a,b
    or c
    jr z,_CH_DATA_OUT_DONE_2  ;DONE if no more data to transfer

    pop af  ;We need this to pass the next toggle to CH_ISSUE_TOKEN

    jr _CH_DATA_OUT_LOOP

;Input: A=Error code, in stack: remaining length, new toggle
_CH_DATA_OUT_DONE:
    pop bc
_CH_DATA_OUT_DONE_2:
    ld d,a
    pop af
    rla ;Toggle back to Cy
    rla
    ld a,d
    ret


; -----------------------------------------------------------------------------
; HW_BUS_RESET: Performs a USB bus reset.
;
; This needs to run when a device connection is detected.
; -----------------------------------------------------------------------------
; Output: A  = 1
;         Cy = 1 on error

HW_BUS_RESET:
    ld a,7
    call CH_SET_USB_MODE
    ld a,1
    ret c

    if USING_ARDUINO_BOARD = 0
    ld bc,150
    call CH_DELAY
    endif

    ld a,6
    call CH_SET_USB_MODE

    ld a,1
    ret c

    xor a
    inc a
    ret

    ;Input: BC = Delay duration in units of 0.1ms
CH_DELAY:
    ld a,CH_CMD_DELAY_100US
    out (CH_COMMAND_PORT),a
_CH_DELAY_LOOP:
    in a,(CH_DATA_PORT)
    or a
    jr z,_CH_DELAY_LOOP 
    dec bc
    ld a,b
    or c
    jr nz,CH_DELAY
    ret


; -----------------------------------------------------------------------------
; File management routines
; -----------------------------------------------------------------------------    

; -----------------------------------------------------------------------------
; HWF_MOUNT_DISK: Mounts a storage device if present.
;
; On success it also opens the root directory
; -----------------------------------------------------------------------------
; Input:  HL = address for the name of the device found
; Output: Cy = 0: ok
;              1: error, no device present or it's not a storage device

HWF_MOUNT_DISK:
    if USE_FAKE_STORAGE_DEVICE

    ex de,hl
    ld hl,FAKE_DEV_NAME
    ld bc,24
    ldir
    xor a
    ld (de),a
    ret

FAKE_DEV_NAME:
    db "TheStorageThing     0.05"

    endif

    ld a,CH_CMD_DISK_CONNECT
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT
    cp USB_ERR_OK
    scf
    ret nz

    ld a,6
    call CH_SET_USB_MODE

    ld a,CH_CMD_DISK_MOUNT
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT
    cp USB_ERR_OK
    scf
    ret nz

    push hl
    call CH_READ_DATA
    pop hl
    ld d,h
    ld e,l
    ld bc,8
    add hl,bc
    ld bc,36-8
    ldir
    xor a
    ld (de),a

    ret


; -----------------------------------------------------------------------------
; HWF_OPEN_FILE_DIR: Open a file or enter a directory from the current one
; -----------------------------------------------------------------------------
; Input:  HL = Address of file or directory name, relative to current
; Output: A  = 0: ok, file or directory open
;              1: generic error (e.g. no device found)
;              2: file or directory not found
;              
;         Cy = 0: file open (if no error)
;              1: directory open (if no error)
;         Z if ok, NZ if error
;         HL = Pointer to terminator of file or directory name

HWF_OPEN_FILE_DIR:
    if USE_FAKE_STORAGE_DEVICE

    xor a
    ret

    endif

    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    call CH_WRITE_STRING

    push hl
    ld a,CH_CMD_FILE_OPEN
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT
    pop hl

    ld b,a
    cp USB_ERR_OK
    ld a,0
    scf
    ccf
    ret z   ;NC, Z

    ld a,b
    cp USB_ERR_OPEN_DIR
    ld a,0
    scf
    ret z   ;C, Z

    ld a,b
    cp USB_ERR_MISS_FILE
    ld a,2
    jr z,_HWF_OPEN_FILE_DIR_END
    dec a

_HWF_OPEN_FILE_DIR_END:
    or a    ;Force NZ
    ret


; -----------------------------------------------------------------------------
; HWF_CREATE_FILE: Create a new file in current directory, overwrite if exists
; -----------------------------------------------------------------------------
; Input:  HL = Address of file or directory name, relative to current
; Output: A  = 0: ok, file open
;              1: error (might be that a directory with the same name exists)

HWF_CREATE_FILE:
    if 0

    push hl
    call HWF_CLOSE_FILE
    pop hl

    push hl
    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    call CH_WRITE_STRING
    ld a,CH_CMD_FILE_ERASE
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT
    pop hl
    
    endif

    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    call CH_WRITE_STRING

    ld a,CH_CMD_FILE_CREATE
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT

    cp USB_ERR_OK
    ld a,0
    ret z
    inc a
    ret


; -----------------------------------------------------------------------------
; HWF_CREATE_DIR: Create a new directory in current directory, open if exists
; -----------------------------------------------------------------------------
; Input:  HL = Address of file or directory name, relative to current
; Output: A  = 0: ok, file open
;              1: error (might be that a file with the same name exists)

HWF_CREATE_DIR:
    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    call CH_WRITE_STRING

    ld a,CH_CMD_DIR_CREATE
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT

    cp USB_ERR_OK
    ld a,0
    ret z
    inc a
    ret


; -----------------------------------------------------------------------------
; HWF_CLOSE_FILE: Close open file or directory, update size in dir entry
; -----------------------------------------------------------------------------

HWF_CLOSE_FILE:
    ld a,CH_CMD_FILE_CLOSE
    out (CH_COMMAND_PORT),a
    ld a,1
    out (CH_DATA_PORT),a
    jp CH_WAIT_INT_AND_GET_RESULT


; -----------------------------------------------------------------------------
; HWF_DELETE_FILE: Delete file or directory
; -----------------------------------------------------------------------------
; Input:  HL = File or directory name
; Output: A  = 0: Ok
;              1: Error

HWF_DELETE_FILE:
    ;Very important: close any open file first, or it will be deleted!
    push hl
    call HWF_CLOSE_FILE
    pop hl

    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    call CH_WRITE_STRING

    ld a,CH_CMD_FILE_ERASE
    out (CH_COMMAND_PORT),a
    call CH_WAIT_INT_AND_GET_RESULT
    or a
    ret z
    ld a,1
    ret


; -----------------------------------------------------------------------------
; HWF_ENUM_FILES: Enumerate files and directories in the current directory
;
; Files/directories whose first character is "_" will be skipped.
;
; The name of each files/directory will be put at the specified address,
; sequentially and with no separators, as a fixed 11 bytes string in the
; same format as in the directory entry (e.g. "FILE    EXT"); after the last
; entry a 0 byte will be placed.
; -----------------------------------------------------------------------------
; Input:  HL = Address of buffer to get file info into
;         BC = Maximum number of files/directories to enumerate
; Output: HL = Pointer to the 0 byte at the end of the list
;         BC = Number of filenames found

HWF_ENUM_FILES:
    if USE_FAKE_STORAGE_DEVICE

    push bc
    call _HWF_ENUM_FILES
    pop bc
    ret

_HWF_ENUM_FILES:
    ld de,0
    push hl
    pop ix
_HWF_ENUM_FILES_LOOP:
    push bc
    push de

    push ix
    pop de

    ld hl,FILE_S
    ld bc,3
    ldir

    pop hl
    push hl
    call Num2Hex
    
    ld a,' '
    ld (de),a
    inc de

    ld hl,EXT_S
    ld bc,3
    ldir

    push de
    pop ix

    pop de
    inc de

    ld a,e
    and 15
    jr nz,_HWF_ENUM_FILES_NODIR
    ld (ix-4),' '
    ld (ix-3),' '
    ld (ix-2),' '
    ld (ix-1),128+32    ;Space with bit 7 set
_HWF_ENUM_FILES_NODIR:

    pop bc
    dec bc
    ld a,b
    or c
    jr nz,_HWF_ENUM_FILES_LOOP

    xor a
    ld (ix),a
    push ix
    pop hl
    ret

FILE_S: db "FIL"
EXT_S: db "EXT"

;Input: HL = number to convert
;       DE = location of ASCII string
Num2Hex:
	ld	a,h
	call	Num1
	ld	a,h
	call	Num2
	ld	a,l
	call	Num1
	ld	a,l
	jr	Num2

Num1:
	rra
	rra
	rra
	rra
Num2:
	or	0F0h
	daa
	add	a,0A0h
	adc	a,040h

	ld	(de),a
	inc	de
	ret

    endif

    push iy
    ld iy,0
    call _HWF_ENUM_FILES_CORE
    pop iy
    ret


; -----------------------------------------------------------------------------
; HWF_FIND_NTH_FILE: Find the Nth file in the current directory
;
; Files whose first character is "_" will be skipped.
;
; The name of the files will be put at the specified address,
; sequentially and with no separators, as a fixed 11 bytes string in the
; same format as in the directory entry (e.g. "FILE    EXT").
; -----------------------------------------------------------------------------
; Input:  HL = Address of buffer to get file info into
;         A  = Index of file to find (first is 0)
; Output: A  = 0: Ok
;              1: Generic error
;              2: File not found
;         HL = Pointer after the filename

HWF_FIND_NTH_FILE:
    push iy
    ld iy,1
    ld c,a
    ld b,0
    inc bc
    call _HWF_ENUM_FILES_CORE
    pop iy
    or a
    ret z
    cp USB_ERR_MISS_FILE
    ld a,2
    ret z
    dec a
    ret

_HWF_ENUM_FILES_CORE:
    if USE_FAKE_STORAGE_DEVICE = 0

    ld a,CH_CMD_SET_FILE_NAME
    out (CH_COMMAND_PORT),a
    ld a,'*'
    out (CH_DATA_PORT),a
    xor a
    out (CH_DATA_PORT),a

    ld de,0     ;Number of files found
    ld a,CH_CMD_FILE_OPEN
    out (CH_COMMAND_PORT),a
_HWF_ENUM_FILES_LOOP:
    push hl
    push de
    push bc
    call CH_WAIT_INT_AND_GET_RESULT
    pop bc
    pop de
    pop hl
    cp CH_ST_INT_DISK_READ
    jr nz,_HWF_ENUM_FILES_END

    push bc
    push hl
    push de
    call CH_READ_DATA
    pop de
    pop hl
    pop bc

    ld a,(hl)
    cp "_"
    jr z,_HWF_ENUM_DIR_NEXT
    cp "."  ;Skip "." and ".." entries
    jr z,_HWF_ENUM_DIR_NEXT

    push bc
    ld bc,11
    add hl,bc ;Point to file attributes byte
    pop bc

    ld a,(hl)
    and 1110b   ;"Hidden", "System" or "Volume" attribute set?
    jr nz,_HWF_ENUM_SKIP
    ld a,iyl
    or a
    jr z,_HWF_ENUM_USE
    bit 4,(hl)  ;"Directory" attribute set?
    jr z,_HWF_ENUM_DIR_OK

_HWF_ENUM_SKIP:
    push bc
    ld bc,-11
    add hl,bc
    pop bc
    jr _HWF_ENUM_DIR_NEXT

_HWF_ENUM_USE:
    bit 4,(hl)  ;"Directory" attribute set?
    jr z,_HWF_ENUM_DIR_OK
    dec hl
    set 7,(hl)
    inc hl
_HWF_ENUM_DIR_OK:

    inc de

    dec bc
    ld a,b
    or c
    jr z,_HWF_ENUM_FILES_END

    ld a,iyl
    or a
    jr nz,_HWF_ENUM_SKIP

_HWF_ENUM_DIR_NEXT:
    ld a,CH_CMD_FILE_ENUM_GO
    out (CH_COMMAND_PORT),a
    jp _HWF_ENUM_FILES_LOOP

_HWF_ENUM_FILES_END:
    push af
    ld a,iyl
    or a
    jr nz,_HWF_ENUM_FILES_END_2
    ld (hl),0
_HWF_ENUM_FILES_END_2:
    pop af    
    push de
    pop bc
    ret

    endif


; -----------------------------------------------------------------------------
; HWF_SEEK_FILE: Move the pointer of the currently mounted file
; -----------------------------------------------------------------------------
; Input:  HL:DE = New pointer
; Output: A = 0: Ok
;             1: End of file
;             2: Other error

HWF_SEEK_FILE:
    if USE_FAKE_STORAGE_DEVICE
    xor a
    ret
    endif

    ld a,CH_CMD_BYTE_LOCATE
    out (CH_COMMAND_PORT),a
    ld a,e
    out (CH_DATA_PORT),a
    ld a,d
    out (CH_DATA_PORT),a
    ld a,l
    out (CH_DATA_PORT),a
    ld a,h
    out (CH_DATA_PORT),a

    call CH_WAIT_INT_AND_GET_RESULT
    or a
    ld a,2
    ret nz

    ld a,CH_CMD_RD_USB_DATA0
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    cp 4
    ld a,2
    ret nz

    ;Read the current pointer, if it's FFFFFFFFh return end of file error
    ld b,4
    ld c,0FFh
_HWF_SEEK_FILE_CUR_POINTER:
    in a,(CH_DATA_PORT)
    and c
    ld c,a
    djnz _HWF_SEEK_FILE_CUR_POINTER

    ld a,c
    inc a
    ld a,1
    ret z
    dec a
    ret


; -----------------------------------------------------------------------------
; HWF_READ_FILE: Read the currently mounted file
; -----------------------------------------------------------------------------
; Input:  BC = How many bytes to read
;         HL = Destination address
; Output: A  = 0: Ok
;              1: Error
;         BC = How many bytes actually read
;         HL = Address after last byte read

HWF_READ_FILE:
    if USE_FAKE_STORAGE_DEVICE
    ld a,1
    ld bc,2048
    ret
    endif

    push hl
    push hl
    ld a,CH_CMD_BYTE_READ
    out (CH_COMMAND_PORT),a
    ld a,c
    out (CH_DATA_PORT),a
    ld a,b
    out (CH_DATA_PORT),a

_HWF_READ_FILE_LOOP:
    call CH_WAIT_INT_AND_GET_RESULT
    or a
    jr z,_HWF_READ_FILE_END
    cp CH_ST_INT_DISK_READ
    ld a,1
    jr nz,_HWF_READ_FILE_END

    pop hl
    call CH_READ_DATA
    push hl

    ld a,CH_CMD_BYTE_RD_GO
    out (CH_COMMAND_PORT),a

    jr _HWF_READ_FILE_LOOP

_HWF_READ_FILE_END:
    pop hl  ;Address after the last byte retrieved
    pop de  ;Initial dest address
    push hl
    or a
    sbc hl,de
    push hl
    pop bc
    pop hl
    ret


; -----------------------------------------------------------------------------
; HWF_WRITE_FILE: Write to the currently mounted file
; -----------------------------------------------------------------------------
; Input:  BC = How many bytes to write
;         HL = Source address
; Output: A  = 0: Ok
;              1: Error
;         BC = How many bytes actually read
;         HL = Address after last byte written

HWF_WRITE_FILE:
    if USE_FAKE_STORAGE_DEVICE
    ld a,1
    ld bc,2048
    ret
    endif

    push hl
    push hl
    ld a,CH_CMD_BYTE_WRITE
    out (CH_COMMAND_PORT),a
    ld a,c
    out (CH_DATA_PORT),a
    ld a,b
    out (CH_DATA_PORT),a

_HWF_WRITE_FILE_LOOP:
    call CH_WAIT_INT_AND_GET_RESULT
    or a
    jr z,_HWF_WRITE_FILE_END
    cp CH_ST_INT_DISK_WRITE
    ld a,1
    jr nz,_HWF_WRITE_FILE_END

    ld a,CH_CMD_WR_REQ_DATA
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    ld b,a

    pop hl
    ld c,CH_DATA_PORT
    otir
    push hl

    ld a,CH_CMD_BYTE_WRITE_GO
    out (CH_COMMAND_PORT),a

    jr _HWF_WRITE_FILE_LOOP

_HWF_WRITE_FILE_END:
    push af
    ld a,CH_CMD_BYTE_WRITE
    out (CH_COMMAND_PORT),a
    xor a
    out (CH_DATA_PORT),a
    out (CH_DATA_PORT),a
    pop af

    pop hl  ;Address after the last byte written
    pop de  ;Initial src address
    push hl
    or a
    sbc hl,de
    push hl
    pop bc
    pop hl
    ret


; -----------------------------------------------------------------------------
; HWF_GET_FILE_ATTR: Get attributes byte of currently mounted file
; -----------------------------------------------------------------------------
; Output: A  = 0: Ok
;              1: Error
;         B  = Attributes byte if ok

HWF_GET_FILE_ATTR:
    ld a,CH_CMD_DIR_INFO_READ
    out (CH_COMMAND_PORT),a
    ld a,0FFh
    out (CH_DATA_PORT),a
    push hl
    push bc
    call CH_WAIT_INT_AND_GET_RESULT
    pop bc
    pop hl
    cp USB_ERR_OK
    ld a,1
    ret nz

    ld a,CH_CMD_RD_USB_DATA0
    out (CH_COMMAND_PORT),a
    ld c,CH_DATA_PORT
    ld b,11+1   ;Discard bytes counter and filename
    call _CH_READ_DISCARD_DATA_LOOP
    in a,(c)    ;Attributes byte
    ld e,a
    ld b,20     ;Discard the rest of the directory info
    call _CH_READ_DISCARD_DATA_LOOP
    xor a
    ld b,e
    ret


; -----------------------------------------------------------------------------
; Optional shortcut routines
; -----------------------------------------------------------------------------    

; -----------------------------------------------------------------------------
; HW_GET_DEV_DESCR and HW_GET_CONFIG_DESCR
;
; Exectute the standard GET_DESCRIPTOR USB request
; to obtain the device descriptor or the configuration descriptor.
; -----------------------------------------------------------------------------
; Input:  DE = Address where the descriptor is to be read
;         A  = Device address
; Output: A  = USB error code

    if HW_IMPL_GET_DEV_DESCR = 1
    
HW_GET_DEV_DESCR:
    ld b,1
    jr CH_GET_DESCR

    endif

    if HW_IMPL_GET_CONFIG_DESCR = 1

HW_GET_CONFIG_DESCR:
    ld b,2
    jr CH_GET_DESCR

    endif

    if HW_IMPL_GET_DEV_DESCR = 1 or HW_IMPL_GET_CONFIG_DESCR = 1

CH_GET_DESCR:
    push bc
    call CH_SET_TARGET_DEVICE_ADDRESS
    
    ld a,CH_CMD_GET_DESCR
    out (CH_COMMAND_PORT),a
    pop af
    out (CH_DATA_PORT),a

    push de
    call CH_WAIT_INT_AND_GET_RESULT
    pop hl
    or a
    ret nz

    call CH_READ_DATA
    ld b,0
    xor a
    ret

    endif


; -----------------------------------------------------------------------------
; HW_SET_CONFIG
;
; Exectute the standard SET_CONFIGURATION USB request.
; -----------------------------------------------------------------------------
; Input: A = Device address
;        B = Configuration number to assign

    if HW_IMPL_SET_CONFIG = 1

    ;In: A=Address, B=Config number
HW_SET_CONFIG:
    call CH_SET_TARGET_DEVICE_ADDRESS
    ld a,CH_CMD_SET_CONFIG
    out (CH_COMMAND_PORT),a
    ld a,b
    out (CH_DATA_PORT),a

    call CH_WAIT_INT_AND_GET_RESULT
    ret

    endif


; -----------------------------------------------------------------------------
; HW_SET_ADDRESS
;
; Exectute the standard SET_ADDRESS USB request.
; -----------------------------------------------------------------------------
; Input: A = Adress to assign

    if HW_IMPL_SET_ADDRESS = 1

HW_SET_ADDRESS:
    push af
    xor a
    call CH_SET_TARGET_DEVICE_ADDRESS
    ld a,CH_CMD_SET_ADDRESS
    out (CH_COMMAND_PORT),a
    pop af
    out (CH_DATA_PORT),a

    call CH_WAIT_INT_AND_GET_RESULT
    ret

    endif    


; -----------------------------------------------------------------------------
; HW_CONFIGURE_NAK_RETRY
; -----------------------------------------------------------------------------
; Input: Cy = 0 to retry for a limited time when the device returns NAK
;               (this is the default)
;             1 to retry indefinitely (or for a long time) 
;               when the device returns NAK 

HW_CONFIGURE_NAK_RETRY:
    ld a,0FFh
    jr nc,_HW_CONFIGURE_NAK_RETRY_2
    ld a,0BFh
_HW_CONFIGURE_NAK_RETRY_2:
    push af
    ld a,CH_CMD_SET_RETRY
    out (CH_COMMAND_PORT),a
    ld a,25h    ;Fixed value, required by CH376
    out (CH_DATA_PORT),a

    ;Bits 7 and 6:
    ;  0x: Don't retry NAKs
    ;  10: Retry NAKs indefinitely (default)
    ;  11: Retry NAKs for 3s
    ;Bits 5-0: Number of retries after device timeout
    ;Default after reset and SET_USB_MODE is 8Fh
    pop af
    out (CH_DATA_PORT),a
    ret


; -----------------------------------------------------------------------------
; Auxiliary "private" routines
; -----------------------------------------------------------------------------

; --------------------------------------
; CH_CHECK_INT_IS_ACTIVE
;
; Check the status of the INT pin of the CH376
;
; Output: Z if active, NZ if not active

CH_CHECK_INT_IS_ACTIVE:
    in a,(CH_COMMAND_PORT)
    and 80h
    ret


CH_WAIT_WHILE_BUSY:
    push af
_CH_WAIT_WHILE_BUSY_LOOP:
    in a,(CH_COMMAND_PORT)
    and 10000b
    jr nz,_CH_WAIT_WHILE_BUSY_LOOP
    pop af
    ret


; --------------------------------------
; CH_WAIT_INT_AND_GET_RESULT
;
; Wait for INT to get active, execute GET_STATUS, 
; and return the matching USB error code
;
; Output: A = Result of GET_STATUS (an USB error code)

CH_WAIT_INT_AND_GET_RESULT:
    if IMPLEMENT_PANIC_BUTTON
    call PANIC_KEYS_PRESSED
    ld a,USB_ERR_PANIC_BUTTON_PRESSED
    ret z
    endif

    call CH_CHECK_INT_IS_ACTIVE
    jr nz,CH_WAIT_INT_AND_GET_RESULT    ;TODO: Perhaps add a timeout check here?

    call CH_GET_STATUS
    cp USB_FILERR_MIN
    jr c,_CH_WAIT_INT_AND_GET_RESULT_2
    cp USB_FILERR_MAX+1
    jr nc,_CH_WAIT_INT_AND_GET_RESULT_2
    ret

_CH_WAIT_INT_AND_GET_RESULT_2:

    cp CH_ST_RET_SUCCESS
    ld b,USB_ERR_OK
    jr z,_CH_LD_A_B_RET
    cp CH_ST_INT_SUCCESS
    jr z,_CH_LD_A_B_RET
    cp CH_ST_INT_DISK_READ
    ret z
    cp CH_ST_INT_DISK_WRITE
    ret z
    cp CH_ST_INT_DISCONNECT
    jr z,_CH_NO_DEV_ERR
    cp CH_ST_INT_BUF_OVER
    ld b,USB_ERR_DATA_ERROR
    jr z,_CH_LD_A_B_RET

    and 2Fh

    cp 2Ah
    ld b,USB_ERR_NAK
    jr z,_CH_LD_A_B_RET
    cp 2Eh
    ld b,USB_ERR_STALL
    jr z,_CH_LD_A_B_RET

    and 23h

    cp 20h
    ld b,USB_ERR_TIMEOUT
    jr z,_CH_LD_A_B_RET

    ld b,USB_ERR_UNEXPECTED_STATUS_FROM_HOST

_CH_LD_A_B_RET:
    ld a,b
    ret

_CH_NO_DEV_ERR:
    call CH_DO_SET_NOSOF_MODE
    ld a,USB_ERR_NO_DEVICE
    ret


    if IMPLEMENT_PANIC_BUTTON

    ;Return Z=1 if CAPS+ESC is pressed
PANIC_KEYS_PRESSED:
    ld a,6
    call DO_SNSMAT
    and 1000b
    ld b,a
    ld a,7
    call DO_SNSMAT
    and 100b
    or b
    ret

    endif


; --------------------------------------
; CH_GET_STATUS
;
; Output: A = Status code

CH_GET_STATUS:
    ld a,CH_CMD_GET_STATUS
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    ret


; --------------------------------------
; CH_SET_NOSOF_MODE: Sets USB host mode without SOF
;
; This needs to run when a device disconnection is detected
;
; Output: A  = -1
;         Cy = 1 on error

CH_DO_SET_NOSOF_MODE:
    ld a,5
    call CH_SET_USB_MODE

    ld a,-1
    ret


; --------------------------------------
; CH_SET_USB_MODE
;
; Input: A = new USB mode:
;            5: Host, no SOF
;            6: Host, generate SOF
;            7: Host, generate SOF + bus reset
; Output: Cy = 1 on error

CH_SET_USB_MODE:
    ld b,a
    ld a,CH_CMD_SET_USB_MODE
    out (CH_COMMAND_PORT),a
    ld a,b
    out (CH_DATA_PORT),a

    ld bc,1000
_CH_WAIT_USB_MODE:
    in a,(CH_DATA_PORT)
    cp CH_ST_RET_SUCCESS
    jp z,CH_CONFIGURE_RETRIES
    dec bc
    ld a,b
    or c
    jr nz,_CH_WAIT_USB_MODE
    scf
    ret


CH_CONFIGURE_RETRIES:
    or a
    call HW_CONFIGURE_NAK_RETRY
    or a
    ret


; --------------------------------------
; CH_SET_TARGET_DEVICE_ADDRESS
;
; Set target USB device address for operation
;
; Input: A = Device address

CH_SET_TARGET_DEVICE_ADDRESS:
    push af
    ld a,CH_CMD_SET_USB_ADDR
    out (CH_COMMAND_PORT),a
    pop af
    out (CH_DATA_PORT),a
    ret


; --------------------------------------
; CH_ISSUE_TOKEN
;
; Send a token to the current target USB device
;
; Input: E = Endpoint number
;        B = PID, one of CH_PID_*
;        A = Toggle bit in bit 7 (for IN transfer)
;            Toggle bit in bit 6 (for OUT transfer)

CH_ISSUE_TOKEN:
    ld d,a
    ld a,CH_CMD_ISSUE_TKN_X
    out (CH_COMMAND_PORT),a
    ld a,d
    out (CH_DATA_PORT),a    ;Toggles
    ld a,e
    rla
    rla
    rla
    rla
    and 0F0h
    or b
    out (CH_DATA_PORT),a    ;Endpoint | PID
    ret


; --------------------------------------
; CH_READ_DATA
;
; Read data from the CH data buffer
;
; Input:  HL = Destination address for the data
; Output: B  = Amount of data received (0-64)
;         HL = HL + B

CH_READ_DATA:
    ld a,CH_CMD_RD_USB_DATA0
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    ld c,a
    or a
    ret z   ;No data to transfer at all
    ld b,a

    ld d,a
    ld c,CH_DATA_PORT

    ld a,h
    or l
    jr z,_CH_READ_DISCARD_DATA_LOOP

    ld b,d
    inir
    ld b,d
    ret

_CH_READ_DISCARD_DATA_LOOP:
    in a,(c)
    djnz _CH_READ_DISCARD_DATA_LOOP
    ld b,d
    ret


; --------------------------------------
; CH_WRITE_DATA
;
; Write data to the CH data buffer
;
; Input:  HL = Source address of the data
;         B  = Length of the data
; Output: HL = HL + B

CH_WRITE_DATA:
    ld a,CH_CMD_WR_HOST_DATA
    out (CH_COMMAND_PORT),a
    ld c,CH_DATA_PORT
    ld a,b  
    out (c),a
    or a
    ret z

    otir
    ret


; --------------------------------------
; CH_WRITE_STRING
;
; Write a zero or "/" terminated string
; to the CH data buffer (if the terminator
; is "/" a zero is written)
;
; Input:  HL = Source address of the string
; Output: HL = Points to the terminator

CH_WRITE_STRING:
    ld c,CH_DATA_PORT
    ld a,(hl)
    out (c),a   ;We accept "/" only as the first char

_CH_WRITE_STRING_LOOP:
    or a
    ret z
    inc hl
    ld a,(hl)
    cp "/"
    jr z,_CH_WRITE_STRING_BAR
    out (c),a
    jr _CH_WRITE_STRING_LOOP

_CH_WRITE_STRING_BAR:
    xor a
    out (c),a
    ret
