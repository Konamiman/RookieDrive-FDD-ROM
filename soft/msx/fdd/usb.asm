USB_DEVICE_ADDRESS: equ 1

USB_CLASS_MASS: equ 8
USB_SUBCLASS_CBI: equ 4
USB_PROTO_WITH_INT_EP: equ 1

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
    ld c,2
    call WK_SET_EP_SIZE

    ;--- Get 8 first bytes of device descriptor, grab max endpoint 0 packet size

    push hl

    ex de,hl
    ld hl,USB_CMD_GET_DEV_DESC_8
    call USB_CONTROL_TRANSFER

    pop ix
    or a
    jr nz,_INIT_USB_DEV_ERR

    ld a,(ix+7)
    ld c,2
    call WK_SET_EP_SIZE

    ;--- Get configuration descriptor (we'll look at the first configuration only)

    push ix
    push ix
    pop de
    ld hl,USB_CMD_GET_CONFIG_DESC
    call USB_CONTROL_TRANSFER

    pop ix
    or a
    jr nz,_INIT_USB_DEV_ERR

    ld b,(ix+4) ;Number of interfaces
    ld c,(ix+5) ;Configuration number to set

    call _INIT_USB_SKIP_DESC ;Now IX points to the first interface descriptor 

    ;-- Loop for all interfaces, searching a CBI compliant one

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
    jr z,_INIT_USB_FOUND

_INIT_USB_SKIP_IFACE:   ; Unsuitable interface: skip it
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
    jr _INIT_USB_DEV_END

    ;--- We found a suitable descriptor, now let's setup work area

    ld b,(ix+4) ;Number of endpoints
    call _INIT_USB_SKIP_DESC    ;Now IX points to the first endpoint descriptor

_INIT_USB_CONFIG_EP_LOOP:
    ld a,(ix+3) ;Endpoint type
    and 11b
    cp 2
    jr c,_INIT_USB_NEXT_EP  ;Any control or isochronous EP? Skip it

    cp 2
    jr z,_INIT_USB_BULK_EP

_INIT_USB_INT_EP:
    ld a,(ix+2) ;EP address + type
    bit 7,a
    jr z,_INIT_USB_NEXT_EP  ;Skip if OUT endpoint

    and 1111b
    ld c,2
    call WK_SET_EP_NUMBER

    or a
    ld c,2
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
    call WK_SET_EP_NUMBER

    ld a,(ix+4) ;Endpoint size
    call WK_SET_EP_SIZE

    or a
    call WK_SET_TOGGLE_BIT

_INIT_USB_NEXT_EP:
    call _INIT_USB_SKIP_DESC
    djnz _INIT_USB_CONFIG_EP_LOOP

    ;--- Assign an address to the device

    ;WIP...


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

USB_CMD_GET_DEV_DESC_8:
    db 80h, 6, 0, 1, 0, 0, 8, 0 

USB_CMD_GET_CONFIG_DESC:
    db 80h, 6, 0, 2, 0, 0, 128, 0 


; -----------------------------------------------------------------------------
; USB_CONTROL_TRANSFER: Perform a USB control transfer on endpoint 0
;
; The size and direction of the transfer are taken from the contents
; of the setup packet.
;
; This routine differs from HW_CONTROL_TRANSFER in thath:
;
; - Passing device address is not needed, it checks if device has already address
; - Passing endpoint 0 max packet size is not needed, it gets it from work area
; -----------------------------------------------------------------------------
; Input:  HL = Address of a 8 byte buffer with the setup packet
;         DE = Address of the input or output data buffer
; Output: A  = Error code (one of USB_ERR_*)
;         BC = Amount of data actually transferred (if IN transfer and no error)

USB_CONTROL_TRANSFER:
    push de
    push hl

    call WK_GET_DEVICE_HAS_ADDRESS
    ld a,0
    jr z,_USB_CONTROL_TRANSFER_2
    ld a,USB_DEVICE_ADDRESS
_USB_CONTROL_TRANSFER_2:

    push af
    ld b,0
    call WK_GET_EP_SIZE ;Now B = Max endpoint 0 packet size
    pop af

    pop hl
    pop de

    jp HW_CONTROL_TRANSFER

    