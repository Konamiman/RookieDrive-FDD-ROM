; This file contains all the code that depends on the CH376.
;
; To adapt the ROM to use a different USB host controller:
;
; - Create a new source file
; - Copy all the USB_ERR_* constants to the new file
; - Implement all the HW_* routines in the new file
; - Include the new file in rookiefdd.asm, under "USB host controller hardware dependant code"


USB_ERR_OK: equ 0
USB_ERR_NAK: equ 1
USB_ERR_STALL: equ 2
USB_ERR_TIMEOUT: equ 3
USB_ERR_DATA_ERROR: equ 4
USB_ERR_NO_DEVICE: equ 5
USB_ERR_OTHER: equ 9

;--- Routine implementation constants
;    HW_IMPL_(routine) needs to be 1 if HW_(routine) is implemented

HW_IMPL_GET_DEV_DESCR: equ 1
HW_IMPL_GET_CONFIG_DESCR: equ 1
HW_IMPL_SET_CONFIG: equ 1
HW_IMPL_SET_ADDRESS: equ 1

;--- CH376 port to Z80 ports mapping

CH_DATA_PORT: equ 20h
CH_COMMAND_PORT: equ 21h

;--- Commands

CH_CMD_RESET_ALL: equ 05h
CH_CMD_CHECK_EXIST: equ 06h
CH_CMD_DELAY_100US: equ 0Fh
CH_CMD_SET_USB_ADDR: equ 13h
CH_CMD_SET_USB_MODE: equ 15h
CH_CMD_TEST_CONNECT: equ 16h
CH_CMD_GET_STATUS: equ 22h
CH_CMD_RD_USB_DATA0: equ 27h
CH_CMD_WR_HOST_DATA: equ 2Ch
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
CH_ST_RET_SUCCESS: equ 51h
CH_ST_RET_ABORT: equ 5Fh


; -----------------------------------------------------------------------------
; HW_TEST: Check if the USB host controller hardware is operational
; -----------------------------------------------------------------------------
; Output: Cy = 0 is hardware is operational, 1 if it's not

HW_TEST:
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
    ld a,CH_CMD_RESET_ALL
    out (CH_COMMAND_PORT),a

    ld bc,1000
_HW_RESET_WAIT:     ;Wait for reset to complete, theorically 35ms
    dec bc
    ld a,b
    or c
    jr nz,_HW_RESET_WAIT

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

    jp CH_DO_BUS_RESET


; -----------------------------------------------------------------------------
; HW_DEV_CHANGE: Check for changes in the device connection
;
; The returned status is relative to the last time that the routine
; was called.
;
; If a device has been connected performs a bus reset that leaves the device
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
    jp z,CH_DO_BUS_RESET
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
; Output: A  = Error code (one of USB_ERR_*)
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
; Output: A  = Error code (one of USB_ERR_*)
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

    if 0
    ex (sp),hl
    ld a,h
    or l
    ld c,0
    jr z,_CH_DATA_IN_NO_MORE_DATA
    ex (sp),hl
    endif

    call CH_READ_DATA
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
; Output: A  = Error code (one of USB_ERR_*)
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

    pop de
    pop af
    xor 40h     ;Update toggle
    push af

    ld a,d
    or e
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


; =============================================================================
; Auxiliary routines
; =============================================================================

; --------------------------------------
; CH_CHECK_INT_IS_ACTIVE
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
; Wait for INT to get active, execute GET_STATUS, and return the matching USB_ERR_*
;
; Output: A = Result of GET_STATUS (one of USB_ERR_*)

CH_WAIT_INT_AND_GET_RESULT:
    call CH_CHECK_INT_IS_ACTIVE
    jr nz,CH_WAIT_INT_AND_GET_RESULT    ;TODO: Perhaps add a timeout check here?

    call CH_GET_STATUS

    cp CH_ST_RET_SUCCESS
    ld b,USB_ERR_OK
    jr z,_CH_LD_A_B_RET
    cp CH_ST_INT_SUCCESS
    jr z,_CH_LD_A_B_RET
    cp CH_ST_INT_DISCONNECT
    jr z,_CH_NO_DEV_ERR
    cp CH_ST_INT_BUF_OVER
    ld b,USB_ERR_DATA_ERROR
    jr z,_CH_LD_A_B_RET

    and 2Fh

    cp 2Ah
    ld b,USB_ERR_NAK    ;Should never occur as the CH376 retries NAKs forever
    jr z,_CH_LD_A_B_RET
    cp 2Eh
    ld b,USB_ERR_STALL
    jr z,_CH_LD_A_B_RET

    and 23h

    cp 20h
    ld b,USB_ERR_TIMEOUT
    jr z,_CH_LD_A_B_RET

    ld b,USB_ERR_OTHER

_CH_LD_A_B_RET:
    ld a,b
    ret

_CH_NO_DEV_ERR:
    call CH_DO_SET_NOSOF_MODE
    ld a,USB_ERR_NO_DEVICE
    ret


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
; CH_DO_BUS_RESET: Performs a USB bus reset, then sets USB host mode with SOF
;
; This needs to run when a device connection is detected
;
; Output: A  = 1
;         Cy = 1 on error

CH_DO_BUS_RESET:
    ld a,7
    call CH_SET_USB_MODE
    ld a,1
    ret c

    ld a,6
    call CH_SET_USB_MODE

    ld a,1
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

    ld b,255
_CH_WAIT_USB_MODE:
    in a,(CH_DATA_PORT)
    cp CH_ST_RET_SUCCESS
    ret z
    djnz _CH_WAIT_USB_MODE
    scf
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
; Output: C  = Amount of data received (0-64)
;         HL = HL + C

CH_READ_DATA:
    ld a,CH_CMD_RD_USB_DATA0
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    ld c,a
    or a
    ret z   ;No data to transfer at all
    ld b,a

    ld a,h
    or l
    jr z,_CH_READ_DISCARD_DATA_LOOP

_CH_READ_DATA_LOOP:
    in a,(CH_DATA_PORT)
    ld (hl),a
    inc hl
    djnz _CH_READ_DATA_LOOP
    ret

_CH_READ_DISCARD_DATA_LOOP:
    in a,(CH_DATA_PORT)
    djnz _CH_READ_DISCARD_DATA_LOOP
    ret


; --------------------------------------
; CH_WRITE_DATA
;
; Write data to the CH data buffer
;
; Input:  HL = Source address of the data
;         B  = Length of the data
; Output: HL = HL + C

CH_WRITE_DATA:
    ld a,CH_CMD_WR_HOST_DATA
    out (CH_COMMAND_PORT),a
    ld a,b
    out (CH_DATA_PORT),a
    or a
    ret z
_CH_WRITE_DATA_LOOP:
    ld a,(hl)
    out (CH_DATA_PORT),a
    inc hl
    djnz _CH_WRITE_DATA_LOOP

    ret


    if HW_IMPL_GET_DEV_DESCR = 1

; Input:  DE = Address of the input or output data buffer
;         A  = Device address
; Output: A  = Error code (one of USB_ERR_*)
    
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


    if HW_IMPL_SET_ADDRESS = 1

    ;In: A=Address
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