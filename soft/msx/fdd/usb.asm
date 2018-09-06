USB_DEVICE_ADDRESS: equ 1

USB_CLASS_MASS: equ 0ffh ;8
USB_SUBCLASS_CBI: equ 4
USB_PROTO_WITH_INT_EP: equ 0

REQUEST_SENSE_CMD_CODE: equ 3

; -----------------------------------------------------------------------------
; INIT_USB_DEV: Initialize USB device and work area
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

INIT_USB_DEV:
    ld bc,128
    call STACKALLOC ;HL = Temporary work area in stack

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
    jp nz,_INIT_USB_DEV_ERR

    ld a,(ix+7)
    push ix
    ld b,2
    call WK_SET_EP_SIZE

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
    jp nz,_INIT_USB_DEV_ERR

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
    jp _INIT_USB_DEV_END

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

    and 1111b
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
    and 1       ;Now B = index in the work area
    ld b,a

    ld a,c
    and 1111b
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

    push iy
    ld hl,USB_CMD_SET_ADDRESS
    ld de,0 ;No data will be actually transferred
    call USB_CONTROL_TRANSFER_0
    pop ix
    or a
    jr nz,_INIT_USB_DEV_ERR

    ;* We must use USB_CONTROL_TRANSFER (not _0) from this point

    ;--- Assign the first configuration to the device

    ld a,(ix+5) ;bConfigurationValue in the configuration descriptor

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
    or a
    jr z,_INIT_USB_DEV_END

_INIT_USB_DEV_ERR:
    push af
    call WK_ZERO
    pop bc
    ld a,2

_INIT_USB_DEV_END:
    ld c,a
    call STACKFREE
    ld a,c
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

USB_CMD_SET_CONFIGURATION:
    db 0, 9, 255, 0, 0, 0, 0, 0 ;Needs actual configuration value in 3rd byte


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
    ld b,0
    call WK_GET_EP_SIZE ;Now B = Max endpoint 0 packet size
    pop af

    pop hl
    pop de

    call HW_CONTROL_TRANSFER
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
;         BC = Amount of data actually received (only if no error)

USB_DATA_IN_TRANSFER:
    push hl
    push bc

    ld b,0
    jr c,_USB_DATA_IN_INT

_USB_DATA_IN_BULK:
    inc b
    call WK_GET_EP_NUMBER
    ld e,a
    ld b,1
    call WK_GET_EP_SIZE
    ld d,b
    jr _USB_DATA_IN_GO

_USB_DATA_IN_INT:
    call WK_GET_EP_NUMBER
    ld e,a
    ld d,2  ;Endpoint size
    ld b,0

_USB_DATA_IN_GO:

    ;* Here E = Endpoint number except bit 7, D = Endpoint size, B=0 for bulk or 1 for int

    push bc ;We'll need B to update the toggle bit

    set 7,e
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
    ret nz

    ;* On success, update toggle bit

    push ix
    pop bc
    push de
    pop af
    call WK_SET_TOGGLE_BIT
    xor a
    ret


; -----------------------------------------------------------------------------
; USB_EXECUTE_CBI: Execute a command using CBI transport
; -----------------------------------------------------------------------------
; Input:  HL = Address of a the command to execute, 1st byte is command length
;         DE = Address of the input or output data buffer
;         BC = Length of data to send or receive
;         Cy = 0 to receive data, 1 to send data
; Output: A  = Error code (one of USB_ERR_*)
;         BC = Amount of data actually transferred (if IN transfer and no error)
;         D  = ASC (if no error)
;         E  = ASCQ (if no error)

USB_EXECUTE_CBI:
    inc hl
    ld a,(hl)   ;First byte of the command
    dec hl

    exx
    ex af,af
    ld bc,64
    call STACKALLOC
    push hl
    pop ix  ;IX = Start of stack allocated area
    ex af,af
    exx

    ;>>> STEP 1: Send command

_USB_EXE_CBI_STEP_1:

    push de
    push bc
    push af
    push hl

    push ix
    pop de
    ld hl,CBI_ADSC
    ld bc,8
    ldir
    call WK_GET_IFACE_NUMBER
    ld (ix+4),a
    pop de  ;DE = Command (was HL)
    ld a,(de)
    ld (ix+6),a ;Command length
    inc de  ;Start of command
    push ix
    pop hl  ;HL = ADSC setup block
    
    push ix
    call USB_CONTROL_TRANSFER
    pop ix

    or a
    jr z,_USB_EXE_CBI_STEP_2
    cp USB_ERR_STALL
    jp nz,_USB_EXE_CBI_POP3_END

    pop af
    push af
    cp REQUEST_SENSE_CMD_CODE   ;Do not try request sense if that's what we are trying to execute now
    ld a,USB_ERR_STALL
    jr z,_USB_EXE_CBI_POP3_END

    pop hl
    pop hl
    pop hl
    ld bc,0
    jr _USB_EXE_DO_REQUEST_SENSE

    ;>>> STEP 2: Send or receive data

_USB_EXE_CBI_STEP_2:
    pop af
    push af
    jr c,_USB_EXE_CBI_DATA_OUT

_USB_EXE_CBI_DATA_IN:
    pop af
    pop bc
    pop hl  ;was DE
    or a
    push af
    push ix
    call USB_DATA_IN_TRANSFER
    pop ix

    or a
    jr z,_USB_EXE_CBI_STEP_3
    cp USB_ERR_STALL
    jp nz,_USB_EXE_CBI_POP1_END

    pop af
    push af
    cp REQUEST_SENSE_CMD_CODE   ;Do not try request sense if that's what we are trying to execute now
    ld a,USB_ERR_STALL
    jr z,_USB_EXE_CBI_POP1_END

    pop hl
    jr _USB_EXE_DO_REQUEST_SENSE

_USB_EXE_CBI_DATA_OUT:
    ;TODO...

    ;>>> STEP 3: Get status on IN endpoint

_USB_EXE_CBI_STEP_3:
    push ix
    pop hl
    push bc ;We need to save the amount of data received
    ld bc,2
    scf
    push ix
    call USB_DATA_IN_TRANSFER
    pop ix

    or a
    jr z,_USB_EXE_CBI_STEP_3_1
    cp USB_ERR_STALL
    jp nz,_USB_EXE_CBI_POP2_END

    pop af
    cp REQUEST_SENSE_CMD_CODE   ;Do not try request sense if that's what we are trying to execute now
    ld a,USB_ERR_STALL    
    jr z,_USB_EXE_CBI_POP1_END

    ld a,b
    or c
    pop bc
    pop de  ;Was AF
    jr z,_USB_EXE_DO_REQUEST_SENSE  ;No data received from INT endpoint?

    ;>>> STEP 3.1: If ASC=0 we're done, otherwise clear error with Reques Sense

    ld a,(ix)
    or a
    ld de,0 ;ASC + ASCQ
    jr z,_USB_EXE_CBI_END

    ;>>> Execute REQUEST SENSE
    ;    Input: BC = Received data

_USB_EXE_DO_REQUEST_SENSE:
    push bc

    push ix
    pop de; Data buffer
    ld hl,UFI_CMD_REQUEST_SENSE
    ld bc,14
    or a
    push ix
    call USB_EXECUTE_CBI
    pop ix

    pop bc
    ld d,(ix+12)    ;ASC
    ld e,(ix+13)    ;ASCQ
    jr _USB_EXE_CBI_END
    
_USB_EXE_CBI_POP3_END:
    pop bc
_USB_EXE_CBI_POP2_END:
    pop bc
_USB_EXE_CBI_POP1_END:
    pop bc
_USB_EXE_CBI_END:
    call STACKFREE
    ret

CBI_ADSC:
    db 21h, 0, 0, 0, 255, 0, 255, 0 ;5th byte is interface number, 6th byte is command length

UFI_CMD_REQUEST_SENSE:
    db REQUEST_SENSE_CMD_CODE, 0, 0, 0, 14, 0, 0, 0, 0, 0, 0, 0
