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
;         BC = Amount of data actually received
;         Cy = New state of the toggle bit (even on error)


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

CH_WAIT_INT_AND_GET_STATUS:
    call CH_INT_IS_ACTIVE
    jr nz,CH_WAIT_INT_AND_GET_STATUS

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