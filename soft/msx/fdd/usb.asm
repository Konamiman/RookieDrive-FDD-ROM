USB_DEVICE_ADDRESS: equ 1

USB_CLASS_MASS: equ 8
USB_SUBCLASS_CBI: equ 4
USB_PROTO_WITH_INT_EP: equ 0

REQUEST_SENSE_CMD_CODE: equ 3


; -----------------------------------------------------------------------------
; USB_CHECK_DEV_CHANGE
;
; Check if a device connection or disconnection has happened.
; On device connection, initialize it.
; On device disconnection, clear work area.
;
; Output: Cy=0 if a properly initialized CBI device is connected, 1 if not

USB_CHECK_DEV_CHANGE:
    call HW_DEV_CHANGE
    jr c,_USB_CHECK_DEV_CHANGE_NO_DEV   ;Device present, but bus reset failed

    or a
    jr nz,_USB_CHECK_DEV_CHANGE_CHANGED

    ;* No device change detected, rely on work area

    call WK_HAS_CONTENTS
    ret nc
    scf
    ret

    ;* Device change detected, act accordingly

_USB_CHECK_DEV_CHANGE_CHANGED:
    inc a
    jr z,_USB_CHECK_DEV_CHANGE_NO_DEV   ;Disconnected

    call USB_INIT_DEV
    or a
    ret z   ;Initialization OK

    ;* No device, or device initialization failed

_USB_CHECK_DEV_CHANGE_NO_DEV:
    call WK_ZERO
    scf
    ret


; -----------------------------------------------------------------------------
; USB_INIT_DEV: Initialize USB device and work area
;
; This routine is invoked after a device connections is detected.
; If checks if the device is a CBI FDD, and if so, configures it
; and initializes the work area; if not, it empties the work area.
;
; Output: A = Initialization result
;             0: Ok, device is a CBI FDD
;             1: The device is not a CBI FDD
;             2: Error when querying or initializing the device
;         B = Error code (one of USB_ERR_*) if A = 2
; -----------------------------------------------------------------------------

USB_INIT_DEV_STACK_SPACE: equ 64

USB_INIT_DEV:
    ld ix,-USB_INIT_DEV_STACK_SPACE
    add ix,sp
    ld sp,ix
    push ix
    pop hl

    push hl

    ;--- Initialize work area: assume max endpoint 0 packet size is 8 bytes

    ld a,8
    ld b,2
    call WK_SET_EP_SIZE

    ;--- Get 8 first bytes of device descriptor, grab max endpoint 0 packet size

    pop de
    push de

    if HW_IMPL_GET_DEV_DESCR = 1

    xor a
    call HW_GET_DEV_DESCR

    else

    ld hl,USB_CMD_GET_DEV_DESC_8
    call USB_CONTROL_TRANSFER_0

    endif

    pop ix
    or a
    jp nz,_USB_INIT_DEV_ERR

    ld a,(ix+7)
    push ix
    ld b,2
    call WK_SET_EP_SIZE

    ;* HACK: Store VID and PID to allow Konamiman's non-standard FDD unit to be used

    ;TODO: Get full device descriptor if HW_IMPL_GET_DEV_DESCR=0

    if 1
    ld l,(ix+8)
    ld h,(ix+9)
    ld (PROCNM),hl
    ld l,(ix+10)
    ld h,(ix+11)
    ld (PROCNM+2),hl
    endif

    ;--- Get configuration descriptor (we'll look at the first configuration only)

    pop de
    push de

    if HW_IMPL_GET_CONFIG_DESCR = 1

    xor a
    call HW_GET_CONFIG_DESCR

    else

    ld hl,USB_CMD_GET_CONFIG_DESC
    call USB_CONTROL_TRANSFER_0

    endif

    pop ix
    or a
    jp nz,_USB_INIT_DEV_ERR

    ld b,(ix+4) ;Number of interfaces

    push ix
    pop iy  ;Save pointer to beginning of descriptor

    call _INIT_USB_SKIP_DESC ;Now IX points to the first interface descriptor 

    ;-- Loop for all interfaces, searching a CBI+UFI compliant one

_INIT_USB_CHECK_IFACE:
    push bc

    ld a,(ix+3) ;Alternate setting
    or a
    jr nz,_INIT_USB_SKIP_IFACE

    ;* HACK: Check if it's Konamiman's non-standard FDD (VID=0644h, PID=0001h)

    if 1
    ld hl,(PROCNM)
    ld a,l
    cp 44h
    jr nz,_INIT_USB_CHECK_IFACE_2
    ld a,h
    cp 6
    jr nz,_INIT_USB_CHECK_IFACE_2
    ld hl,(PROCNM+2)
    ld a,l
    dec a   ;cp 1
    jr nz,_INIT_USB_CHECK_IFACE_2
    ld a,h
    or a
    jr z,_INIT_USB_FOUND_CBI
    endif
    
_INIT_USB_CHECK_IFACE_2:
    ld a,(ix+5)
    cp USB_CLASS_MASS
    jr nz,_INIT_USB_SKIP_IFACE
    ld a,(ix+6)
    cp USB_SUBCLASS_CBI
    jr nz,_INIT_USB_SKIP_IFACE
    ld a,(ix+7)
    cp USB_PROTO_WITH_INT_EP
    jp z,_INIT_USB_FOUND_CBI

_INIT_USB_SKIP_IFACE:   ; Not a CBI+UFI interface: skip it
    ld b,(ix+4)     ;Number of endpoints
    inc b           ;To include the interface descriptor itself
_INIT_USB_SKIP_IFACE_LOOP:
    call _INIT_USB_SKIP_DESC
    djnz _INIT_USB_SKIP_IFACE_LOOP

    pop bc
    djnz _INIT_USB_CHECK_IFACE

    ;* No suitable interface found

    call WK_ZERO
    ld a,1
    jp _USB_INIT_DEV_END

    ;--- We found a suitable descriptor, now let's setup work area

_INIT_USB_FOUND_CBI:
    pop bc  ;Throw away interfaces counter

    ld a,(ix+2)
    call WK_SET_IFACE_NUMBER    ;bInterfaceNumber

    ld b,(ix+4) ;Number of endpoints
    call _INIT_USB_SKIP_DESC    ;Now IX points to the first endpoint descriptor

_INIT_USB_CONFIG_EP_LOOP:
    push bc
    ld a,(ix+3) ;Endpoint type
    and 11b
    cp 2
    jr c,_INIT_USB_NEXT_EP  ;Control or isochronous EP? Skip it

    cp 2
    jr z,_INIT_USB_BULK_EP

_INIT_USB_INT_EP:
    ld a,(ix+2) ;EP address + type
    bit 7,a
    jr z,_INIT_USB_NEXT_EP  ;Skip if interrupt OUT endpoint

    and 10001111b
    ld b,2
    call WK_SET_EP_NUMBER

    or a
    ld b,2
    call WK_SET_TOGGLE_BIT

    jr _INIT_USB_NEXT_EP

_INIT_USB_BULK_EP:
    ld a,(ix+2) ;EP address + type
    ld c,a
    rlca
    and 1 ;Now B = index in the work area
    ld b,a

    ld a,c
    and 10001111b
    push bc
    call WK_SET_EP_NUMBER
    pop bc

    ld a,(ix+4) ;Endpoint size
    push bc
    call WK_SET_EP_SIZE
    pop bc

    or a
    call WK_SET_TOGGLE_BIT

_INIT_USB_NEXT_EP:
    pop bc
    call _INIT_USB_SKIP_DESC
    djnz _INIT_USB_CONFIG_EP_LOOP

    ;--- Assign an address to the device

    if HW_IMPL_SET_ADDRESS = 1

    ld a,USB_DEVICE_ADDRESS
    call HW_SET_ADDRESS
    push iy
    pop ix

    else

    push iy
    ld hl,USB_CMD_SET_ADDRESS
    ld de,0 ;No data will be actually transferred
    call USB_CONTROL_TRANSFER_0
    pop ix

    endif

    or a
    jr nz,_USB_INIT_DEV_ERR

    ;* We must use USB_CONTROL_TRANSFER (not _0) from this point

    ;--- Assign the first configuration to the device

    ld a,(ix+5) ;bConfigurationValue in the configuration descriptor

    if HW_IMPL_SET_CONFIG = 1

    ld b,a
    ld a,USB_DEVICE_ADDRESS
    call HW_SET_CONFIG

    else

    push ix
    pop de
    ld hl,USB_CMD_SET_CONFIGURATION
    ld bc,8
    push de
    ldir
    pop hl

    ld (ix+2),a ;wValue in the SET_CONFIGURATION command

    ld de,0 ;No data will be actually transferred
    call USB_CONTROL_TRANSFER

    endif

    or a
    jr z,_USB_INIT_DEV_END

_USB_INIT_DEV_ERR:
    push af
    call WK_ZERO
    pop bc
    ld a,2

_USB_INIT_DEV_END:
    ld ix,USB_INIT_DEV_STACK_SPACE
    add ix,sp
    ld sp,ix
    ret

    ;* Skip the current descriptor

_INIT_USB_SKIP_DESC:
    ld e,(ix)
    ld d,0
    add ix,de
    ret


; -----------------------------------------------------------------------------
; USB commands used for initialization
; -----------------------------------------------------------------------------

    if HW_IMPL_GET_DEV_DESCR = 0

USB_CMD_GET_DEV_DESC_8:
    db 80h, 6, 0, 1, 0, 0, 8, 0

    endif

    if HW_IMPL_GET_CONFIG_DESCR = 0

USB_CMD_GET_CONFIG_DESC:
    db 80h, 6, 0, 2, 0, 0, 128, 0

    endif

USB_CMD_SET_ADDRESS:
    db 0, 5, 1, 0, 0, 0, 0, 0

    if HW_IMPL_SET_CONFIG = 0

USB_CMD_SET_CONFIGURATION:
    db 0, 9, 255, 0, 0, 0, 0, 0 ;Needs actual configuration value in 3rd byte

    endif


; -----------------------------------------------------------------------------
; USB_CONTROL_TRANSFER: Perform a USB control transfer on endpoint 0
;
; The size and direction of the transfer are taken from the contents
; of the setup packet.
;
; This routine differs from HW_CONTROL_TRANSFER in that:
;
; - Passing the device address is not needed
; - Passing endpoint 0 max packet size is not needed, it's taken from work area
; -----------------------------------------------------------------------------
; Input:  HL = Address of a 8 byte buffer with the setup packet
;         DE = Address of the input or output data buffer
; Output: A  = Error code (one of USB_ERR_*)
;         BC = Amount of data actually transferred (if IN transfer and no error)

;This entry point is used before SET_ADDRESS has been executed
USB_CONTROL_TRANSFER_0:
    xor a
    jr _USB_CONTROL_TRANSFER_DO

USB_CONTROL_TRANSFER:
    ld a,USB_DEVICE_ADDRESS

_USB_CONTROL_TRANSFER_DO:
    push de
    push hl

    push af
    ld b,2
    call WK_GET_EP_SIZE ;Now B = Max endpoint 0 packet size
    pop af

    pop hl
    pop de

    call HW_CONTROL_TRANSFER
    or a
    call nz,USB_PROCESS_ERROR
    ret


; -----------------------------------------------------------------------------
; USB_DATA_IN_TRANSFER: Perform a USB data IN transfer
;
; This routine differs from HW_CONTROL_TRANSFER in that:
;
; - Passing the device address is not needed
; - Passing endpoint max packet size is not needed, it's taken from work area
; - Endpoint number is not (directly) passed
; - It manages the state of the toggle bit in work area
; -----------------------------------------------------------------------------
; Input:  HL = Address of a buffer for the received data
;         BC = Data length
;         Cy = 0 for bulk IN endpoint, 1 for interrupt endpoint
; Output: A  = Error code (one of USB_ERR_*)
;         BC = Amount of data actually received

USB_DATA_IN_TRANSFER:
    push af
    ld a,b
    or c
    jr nz,_USB_DATA_IN_NZ
    pop de
    ret
_USB_DATA_IN_NZ:
    pop af

    push hl
    push bc

    ld b,1
    jr c,_USB_DATA_IN_INT

_USB_DATA_IN_BULK:
    call WK_GET_EP_NUMBER
    ld e,a
    ld b,1
    call WK_GET_EP_SIZE
    ld d,b
    ld b,1
    jr _USB_DATA_IN_GO

_USB_DATA_IN_INT:
    inc b
    call WK_GET_EP_NUMBER
    ld e,a
    ld d,2  ;Endpoint size
    ld b,d

_USB_DATA_IN_GO:

    ;* Here E = Endpoint number, D = Endpoint size, B=1 for bulk or 2 for int

    push bc ;We'll need B to update the toggle bit

    push de
    call WK_GET_TOGGLE_BIT
    pop de

    pop ix  ;Was B

    pop bc
    pop hl
    push ix
    ld a,USB_DEVICE_ADDRESS
    call HW_DATA_IN_TRANSFER
    pop ix
    push af
    or a
    pop de
    ld a,d
    jr z,_USB_DATA_IN_OK

    ;* On STALL error, clear endpoint HALT

    cp USB_ERR_STALL
    jp nz,USB_PROCESS_ERROR

    push ix
    pop af
    or a
    push bc
    call USB_CLEAR_ENDPOINT_HALT
    pop bc
    ld a,USB_ERR_STALL
    ret

    ;* On success, update toggle bit

_USB_DATA_IN_OK:
    push bc ;Save retrieved data count
    push ix
    pop bc
    push de
    pop af
    call WK_SET_TOGGLE_BIT
    xor a
    pop bc
    ret


; -----------------------------------------------------------------------------
; USB_CLEAR_ENDPOINT_HALT
;
; Also clears the toggle bit in the work area.
; -----------------------------------------------------------------------------
; Input: A = which endpoint to clear:
;            0: bulk OUT
;            1: bulk IN
;            2: interrupt IN

USB_CLEAR_ENDPOINT_HALT_STACK_SPACE: equ 8

USB_CLEAR_ENDPOINT_HALT:
    push af
    pop hl
    ld ix,-USB_CLEAR_ENDPOINT_HALT_STACK_SPACE
    add ix,sp
    ld sp,ix
    push hl ;Was A

    ex de,hl
    push de
    ld hl,USB_CMD_CLEAR_ENDPOINT_HALT
    ld bc,8
    ldir
    pop ix
    ld b,a
    call WK_GET_EP_NUMBER
    ld (ix+4),a

    push ix
    pop hl
    call USB_CONTROL_TRANSFER

    pop bc ;was A
    or a
    call z,WK_SET_TOGGLE_BIT

    ld d,a
    ld ix,USB_CLEAR_ENDPOINT_HALT_STACK_SPACE
    add ix,sp
    ld sp,ix
    ld a,d
    ret

USB_CMD_CLEAR_ENDPOINT_HALT:
    db 2, 1, 0, 0, 255, 0, 0, 0     ;byte 4 is the endpoint to be cleared

;!!!TESTING
    if 0
SET_HALT:
    push bc,de,hl,ix,iy
    ld hl,USB_CMD_SET_ENDPOINT_HALT
    call USB_CONTROL_TRANSFER
    pop bc,de,hl,ix,iy
    ret

ENDPOINT_HALTED: equ 81h

USB_CMD_SET_ENDPOINT_HALT:
    db 2, 3, 0, 0, ENDPOINT_HALTED, 0, 0, 0    
    endif
;!!!


; -----------------------------------------------------------------------------
; USB_PROCESS_ERROR
;
; If USB error is "device disconnected", clear work area
; -----------------------------------------------------------------------------
; Does not modify registers

USB_PROCESS_ERROR:
    push af
    cp USB_ERR_NO_DEVICE
    jr nz,_USB_PROCESS_ERROR_END

    push bc
    push de
    push hl
    call WK_ZERO
    pop hl
    pop de
    pop bc
_USB_PROCESS_ERROR_END:
    pop af
    ret    


; -----------------------------------------------------------------------------
; USB_EXECUTE_CBI_WITH_RETRY: Execute a command using CBI transport with error retry
;
; Retried errors are those of type "device powered" or "not ready to
; ready transition", plus optionally "media changed"
; -----------------------------------------------------------------------------
; Input:  Same as USB_EXECUTE_CBI, plus:
;         A = 1 to retry "media changed" errors, 0 to no retry them
; Output: Same as USB_EXECUTE_CBI

USB_EXECUTE_CBI_WITH_RETRY:
    push hl
    push de
    push bc
    push af

    call USB_EXECUTE_CBI
    or a
    jr nz,_USB_ECBIR_POPALL_END_NZ   ;USB level error: do not retry

    ld a,d
    or a    ;No error at all
    jr z,_USB_ECBIR_POPALL_END_NZ

    ;Report success if the error is one of the "recovered data" (17h or 18h)

    cp 17h
    jr z,_USB_ECBIR_POPALL_END
    cp 18h
    jr z,_USB_ECBIR_POPALL_END

    ;Retry if ASC=4 and ASCQ=1 (unit becoming ready) or FFh (unit busy)

    cp 4
    jr nz,_USB_ECBIR_NO_ASC_4
    ld a,e
    cp 1
    jr z,_USB_ECBIR_DO_RETRY
    cp 0FFh
    jr z,_USB_ECBIR_DO_RETRY
    jr _USB_ECBIR_POPALL_END
_USB_ECBIR_NO_ASC_4:

    ;Retry "device powered" error

    ld a,d
    cp 29h
    jr z,_USB_ECBIR_DO_RETRY

    ;Retry "media changed" only if we were instructed to do so

    cp 28h
    jr nz,_USB_ECBIR_POPALL_END
    pop af
    push af
    or a
    jr z,_USB_ECBIR_POPALL_END

    ;Here we know we must retry

_USB_ECBIR_DO_RETRY:
    pop af
    pop bc
    pop de
    pop hl    
    jr USB_EXECUTE_CBI_WITH_RETRY

    ;Success, or do not retry

_USB_ECBIR_POPALL_END:
    xor a
_USB_ECBIR_POPALL_END_NZ:
    pop hl
    pop hl
    pop hl
    pop hl
    ret


; -----------------------------------------------------------------------------
; USB_EXECUTE_CBI: Execute a command using CBI transport
; -----------------------------------------------------------------------------
; Input:  HL = Address of the 12 byte command to execute
;         DE = Address of the input or output data buffer
;         BC = Length of data to send or receive
;         Cy = 0 to receive data, 1 to send data
; Output: A  = Error code (one of USB_ERR_*)
;         BC = Amount of data actually transferred (if IN transfer)
;         D  = ASC (if no error)
;         E  = ASCQ (if no error)

USB_EXECUTE_CBI_STACK_SPACE: equ 8+18

USB_EXECUTE_CBI:
    push af
    pop iy
    ld ix,-USB_EXECUTE_CBI_STACK_SPACE
    add ix,sp
    ld sp,ix

    push hl
    push de
    push bc

    push ix
    pop de
    ld hl,CBI_ADSC
    ld bc,8
    ldir
    call WK_GET_IFACE_NUMBER
    ld (ix+4),a

    pop bc
    pop de
    pop hl
    push iy
    pop af

    push ix
    call _USB_EXECUTE_CBI_CORE
    pop ix
    cp USB_ERR_STALL
    ld de,0 ;ASC+ASCQ in case we return now
    jr nz,_USB_EXE_CBI_END  ;Return on succes or USB error other than stall
    ;jr _USB_EXE_CBI_END

_USB_EXECUTE_REQUEST_SENSE:
    push bc ;Data actually transferred

    push ix 
    ld bc,8
    add ix,bc
    push ix
    pop de  ;DE = Buffer for request sense data

    pop ix  ;IX = Prepared ADSC
    push de
    ld hl,UFI_CMD_REQUEST_SENSE
    ld bc,18
    or a    ;receive data
    call _USB_EXECUTE_CBI_CORE

    pop ix
    pop bc
    ld d,(ix+12)
    ld e,(ix+13)

_USB_EXE_CBI_END:
    ld ix,USB_EXECUTE_CBI_STACK_SPACE
    add ix,sp
    ld sp,ix
    ret

    ;Does not retry, nor request sense
    ;In: IX=Prepared ADSC, HL = command, DE=data buffer, BC=data length, Cy=0 to receive
    ;Out: A=USB error code (STALL if non-zero ASC), BC=data transferred
_USB_EXECUTE_CBI_CORE:

    ;>>> STEP 1: Send command

_USB_EXE_CBI_STEP_1:
    push af ;Send or receive flag
    push de ;Data buffer address
    push bc ;Data length

    ex de,hl    ;Now DE = UFI command (data for the USB ADSC)
    push ix
    pop hl      ;HL = Prepared ADSC
    call USB_CONTROL_TRANSFER
    or a
    jr z,_USB_EXE_CBI_STEP_2

    pop hl
    pop hl
    pop hl
    ld bc,0
    ret

    ;>>> STEP 2: Send or receive data

_USB_EXE_CBI_STEP_2:
    pop bc  ;Data length
    pop hl  ;was DE, data buffer
    pop af
    jr c,_USB_EXE_CBI_DATA_OUT

_USB_EXE_CBI_DATA_IN:
    or a    ;From bulk endpoint
    call USB_DATA_IN_TRANSFER

    or a
    jr z,_USB_EXE_CBI_STEP_3
    ret

_USB_EXE_CBI_DATA_OUT:
    ;TODO...

    ;>>> STEP 3: Get status from INT endpoint

_USB_EXE_CBI_STEP_3:
    push bc ;We need to save the amount of data received
    push bc ;Allocate 2 bytes on stack
    ld hl,0
    add hl,sp   ;HL = 2 byte buffer for INT data
    ld bc,2
    scf
    call USB_DATA_IN_TRANSFER
    pop hl ;L = ASC, H = ASCQ
    push bc
    pop de  ;Amount of data transferred from INT endpoint
    pop bc  ;Amount of data received from bulk in
    or a
    ret nz  ;Return on any USB error

    ld a,d
    or e
    ld a,USB_ERR_STALL
    ret z   ;Return if no data transferred from INT endpoint

    ld a,h  ;ASC or ASCQ not zero?
    or l
    ld a,USB_ERR_STALL
    ret nz
    xor a
    ret

CBI_ADSC:
    db 21h, 0, 0, 0, 255, 0, 12, 0 ;4th byte is interface number, 6th byte is command length

UFI_CMD_REQUEST_SENSE:
    db REQUEST_SENSE_CMD_CODE, 0, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0
