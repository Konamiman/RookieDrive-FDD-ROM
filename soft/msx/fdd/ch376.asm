USB_ERR_OK: equ 0
USB_ERR_NAK: equ 1
USB_ERR_STALL: equ 2
USB_ERR_TIMEOUT: equ 3
USB_ERR_DATA_ERROR: equ 4
USB_ERR_NO_DEVICE: equ 5
USB_ERR_OTHER: equ 255

;--- Z80 ports

CH_DATA_PORT: equ 20h
CH_COMMAND_PORT: equ 21h

;--- Commands

CH_RESET_ALL: equ 05h
CH_WR_HOST_DATA: equ 2Ch
CH_RD_USB_DATA0: equ 27h
CH_ISSUE_TKN_X: equ 4Eh
CH_GET_STATUS: equ 22h
CH_SET_USB_ADDR: equ 13h
CH_SET_USB_MODE: equ 15h
CH_GET_DESCR: equ 46h

;--- PIDs

CH_PID_SETUP: equ 0Dh
CH_PID_IN: equ 09h
CH_PID_OUT: equ 01h

;--- Status codes

CH_INT_SUCCESS: equ 14h
CH_INT_CONNECT: equ 15h
CH_INT_DISCONNECT: equ 16h
CH_USB_INT_BUF_OVER: equ 17h
CH_CMD_RET_SUCCESS: equ 51h
CH_CMD_RET_ABORT: equ 5Fh


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
    ld a,CH_RESET_ALL
    out (CH_COMMAND_PORT),a

    ld b,200
    call CH_DELAY   ;35ms

    jp HW_DEV_CHANGE


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
    call CH_INT_IS_ACTIVE
    ld a,0
    ret nz
    
    call CH_DO_GET_STATUS
    cp CH_INT_CONNECT
    jr z,_CH_DO_BUS_RESET
    cp CH_INT_DISCONNECT
    jr z,_CH_DO_SET_NOSOF_MODE

    xor a
    ret

_CH_DO_SET_NOSOF_MODE:
    ld a,5
    call CH_DO_SET_USB_MODE

    ld a,-1
    ret

_CH_DO_BUS_RESET:
   ld a,5
   call CH_DO_SET_USB_MODE
   ld a,1
   ret c

   ld b,200 ;35ms
   call CH_DELAY 

   ld a,7
   call CH_DO_SET_USB_MODE

   ld a,1
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
;         BC = Amount of data actually transferred


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

CH_DATA_IN_TRANSFER:
    rra
    ld ix,0 ;IX = Received so far count
    push de
    pop iy  ;IY = EP size + EP number

CH_DATA_IN_LOOP:
    push af ;Toggle in bit 7
    push bc ;Remaining length

    ld e,iyl
    ld b,CH_PID_IN
    call CH_DO_ISSUE_TOKEN

    call CH_WAIT_INT_AND_GET_RESULT
    or a
    jr nz,CH_DATA_IN_DONE   ;DONE if error

    call CH_DO_READ_DATA
    ld b,0
    add ix,bc   ;Update received so far count

    pop de
    pop af
    xor 80h     ;Update toggle
    push af
    push de

    ld a,c
    or a
    jr z,CH_DATA_IN_DONE    ;DONE if no data received

    ex (sp),hl  ;Now HL = Remaining data
    or a
    sbc hl,bc   ;Now HL = Updated remaning data
    ld a,b
    or c
    ex (sp),hl  ;Remaining data is back on the stack
    jr z,CH_DATA_IN_DONE    ;DONE if no data remaining

    ld a,c
    cp iyh
    jr c,CH_DATA_IN_DONE    ;DONE if transferred less than the EP size

    pop bc
    pop af  ;We need this to pass the next toggle to CH_DO_ISSUE_TOKEN

    jr CH_DATA_IN_LOOP

;Input: A=Error code, in stack: remaining length, new toggle
CH_DATA_IN_DONE:
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


CH_DELAY:
    ex (sp),hl
    ex (sp),hl
    djnz CH_DELAY
    ret

;Z if active, NZ if not active
CH_INT_IS_ACTIVE:
    in a,(CH_COMMAND_PORT)
    and 80h
    ret

;Wait for INT to get active, execute GET_STATUS, and return the matching USB_ERR_*
CH_WAIT_INT_AND_GET_RESULT:
    call CH_INT_IS_ACTIVE
    jr nz,CH_WAIT_INT_AND_GET_STATUS
    call CH_DO_GET_STATUS

    cp CH_CMD_RET_SUCCESS
    ld b,USB_ERR_OK
    jr z,_CH_LD_A_B_RET
    cp CH_INT_SUCCESS
    jr z,_CH_LD_A_B_RET
    cp CH_INT_DISCONNECT
    ld b,USB_ERR_NO_DEVICE  ;TODO: Set NO SOF mode
    jr z,_CH_LD_A_B_RET
    cp CH_USB_INT_BUF_OVER
    ld b,USB_ERR_DATA_ERROR
    jr z,_CH_LD_A_B_RET

    and 2Fh

    cp 2Ah
    ld a,USB_ERR_NAK
    jr z,_CH_LD_A_B_RET
    cp 2Eh
    ld a,USB_ERR_STALL
    jr z,_CH_LD_A_B_RET

    and 23h

    cp 20h
    ld b,USB_ERR_TIMEOUT
    jr z,_CH_LD_A_B_RET

    ld b,USB_ERR_OTHER

_CH_LD_A_B_RET:
    ld a,b
    ret


CH_DO_GET_STATUS:
    ld a,CH_GET_STATUS
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    ret

;Input: A = mode
;Output: Cy = 1 on error
CH_DO_SET_USB_MODE:
    ld b,a
    ld a,CH_SET_USB_MODE
    out (CH_COMMAND_PORT),a
    ld a,b
    out (CH_DATA_PORT),a

    ld b,200
_CH_WAIT_USB_MODE:
    in a,(CH_DATA_PORT)
    cp CH_CMD_RET_SUCCESS
    ret z
    djnz _CH_WAIT_USB_MODE
    scf
    ret

CH_SET_TARGET_DEVICE_ADDRESS:
    push af
    ld a,CH_SET_USB_ADDR
    out (CH_COMMAND_PORT),a
    pop af
    out (CH_DATA_PORT),a
    ret

;E=Endpoint
;B=PID
;A=IN toggle in bit 7, OUT toggle in bit 6
CH_DO_ISSUE_TOKEN:
    ld d,a
    ld a,CH_ISSUE_TKN_X
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

;HL = Buffer
;Output: C = Actually read amount
;HL = HL + C
CH_DO_READ_DATA:
    ld a,RD_USB_DATA0
    out (CH_COMMAND_PORT),a
    in a,(CH_DATA_PORT)
    ld c,a
    or a
    ret z   ;No data to transfer at all
    ld b,a
_CH_READ_DATA_LOOP:
    in a,(CH_DATA_PORT)
    ld (hl),a
    inc hl
    djnz _CH_READ_DATA_LOOP

    ret