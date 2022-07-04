; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the work area handling cod.
; We use the 8 bytes available for our slot at SLTWRK.


; Work area definition when a FDD is connected:
;
; +0: Bulk OUT endpoint parameters
; +1: Bulk IN endpoint parameters
; +2: Interrupt IN endpoint parameters
; +3: Interface number for the ADSC setup packet
; +4: Bits 0-3: Last relative drive accessed
;     Bits 4-7: Misc flags
;               0: set if USB hub found
; +5: Last USB error (for CALL USBERROR)
; +6: Last ASC (for CALL USBERROR)
; +7: Last ASCQ (for CALL USBERROR)
;
; Endpoint parameters are:
;   bits 7 and 3-0: Endpoint number
;   bit 4: Toggle bit state
;   bits 6-5: Endpoint max packet size
;
; For +2 what 6-5 actually stores is the endpoint 0 max packet size,
; the max packet size of the interrupt IN endpoint is assumed to be 2.
;
; Max packet size is stored encoded as follows:
;  00 = 8 bytes
;  01 = 16 bytes
;  10 = 32 bytes
;  11 = 64 bytes
;
; Work area definition when a storage device is connected:
;
; +0: flags:
;     bit 7: set to 1, indicates a storage device is connected
;            (if a floppy is connected it'll be 0 since the byte holds
;             the OUT endpoint number)
;     bit 0: set to 1 if there's a file mounted
;     bit 1: set if mounted in read only mode
;     bit 2: set if file has changed
;     bit 3: set to enable CAPS lit on disk access
; +1: Current directory depth:
;     0: no directory currently open
;     1: root directory, etc
; 
; If no device is connected or the connected device is not a CBI FDD,
; or if some error occurred during USB hardware or device initialization,
; the work area contents is all zero 
; (the last relative drive accessed is always preserved)


; -----------------------------------------------------------------------------
; Store the size of an endpoint.
;
; Input: A = Size
;        B = work area byte (0-2)

WK_SET_EP_SIZE:
    push ix
    call _WK_GET_POINTER

    ld c,0
    cp 8
    jr z,_WK_SET_EP_SIZE_DO
    inc c
    cp 16
    jr z,_WK_SET_EP_SIZE_DO
    inc c
    cp 32
    jr z,_WK_SET_EP_SIZE_DO
    inc c

_WK_SET_EP_SIZE_DO:
    rrc c
    rrc c
    rrc c
    ld a,(hl)
    and 11001111b
    or c
    ld (hl),a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Zero the entire work area except the last relative drive accessed

WK_ZERO:
    push ix
    call _WK_GETWRK
    ld (ix),0
    ld (ix+1),0
    ld (ix+2),0
    ld (ix+3),0
    ld (ix+5),0
    ld (ix+6),0
    ld (ix+7),0
    ld a,(ix+4)
    and 0Fh
    ld (ix+4),a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Retrieve the stored size of an endpoint.
;
; Input:  B = work area byte (0-2)
; Output: B = size

WK_GET_EP_SIZE:
    push ix
    call _WK_GET_POINTER
    pop ix
    ld a,(hl)
    rlca
    rlca
    rlca
    and 11b

    ld b,8
    or a
    ret z
    sla b
    dec a
    ret z
    sla b
    dec a
    ret z
    sla b

    ret


; -----------------------------------------------------------------------------
; Check if the work area has content 
; (meaning that a proper device is initialized and ready to use)
;
; Output: Z and NC if work area is zeroed
;         NZ if work area has contents

WK_HAS_CONTENTS:
    push ix
    call _WK_GETWRK
    ld a,(hl)
    or a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Store the number of an endpoint
;
; Input: A = endpoint number
;        B = work area byte (0-2)

WK_SET_EP_NUMBER:
    push ix
    call _WK_GET_POINTER
    and 10001111b
    ld c,a
    ld a,(hl)
    and 11110000b
    or c
    ld (hl),a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Retrieve the stored number of an endpoint
;
; Input:  B = work area byte (0-2)
; Output: A = endpoint number

WK_GET_EP_NUMBER:
    push ix
    call _WK_GET_POINTER
    ld a,(hl)
    and 10001111b
    pop ix
    ret


; -----------------------------------------------------------------------------
; Store the toggle bit status for an endpoint
;
; Input: Cy = toggle bit status
;        B  = work area byte (0-2)

WK_SET_TOGGLE_BIT:
    push ix
    call _WK_GET_POINTER
    jr c,_WK_SET_TOGGLE_BIT_1
    res 4,(hl)
    pop ix
    ret
_WK_SET_TOGGLE_BIT_1:
    set 4,(hl)
    pop ix
    ret


; -----------------------------------------------------------------------------
; Retrieve the stored toggle bit status for an endpoint
;
; Input: B  = work area byte (0-2)
; Output: Cy = toggle bit status

WK_GET_TOGGLE_BIT:
    push ix
    call _WK_GET_POINTER
    bit 4,(hl)
    pop ix
    scf
    ret nz
    ccf
    ret


; -----------------------------------------------------------------------------
; Store the interface number for the ADSC command
;
; Input: A = interface number

WK_SET_IFACE_NUMBER:
    push ix
    push af
    call _WK_GETWRK
    pop af
    ld (ix+3),a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Retrieve the stored interface number for the ADSC command
;
; Output: A = interface number

WK_GET_IFACE_NUMBER:
    push ix
    call _WK_GETWRK
    ld a,(ix+3)
    pop ix
    ret


; -----------------------------------------------------------------------------
; Store information about the last USB error
; Input: A = USB error
;        D = ASC
;        E = ASCQ

WK_SET_ERROR:
    push ix
    push af
    push de
    call _WK_GETWRK
    pop de
    pop af
    ld (ix+5),a
    ld (ix+6),d
    ld (ix+7),e
    pop ix
    ret


; -----------------------------------------------------------------------------
; Retrieve the stored information about the last USB error
; Output: A = USB error
;         D = ASC
;         E = ASCQ

WK_GET_ERROR:
    push ix
    call _WK_GETWRK
    ld a,(ix+5)
    ld d,(ix+6)
    ld e,(ix+7)
    pop ix
    ret


; -----------------------------------------------------------------------------
; Store the last accessed relative drive
;
; Input: A = relative drive number

WK_SET_LAST_REL_DRIVE:
    push bc
    push ix
    push af
    call _WK_GETWRK
    ld a,(ix+4)
    and 11110000b
    pop bc
    or b
    ld (ix+4),a
    pop ix
    pop bc
    ret


; -----------------------------------------------------------------------------
; Retrieve the stored last accessed relative drive
;
; Output: A = relative drive number

WK_GET_LAST_REL_DRIVE:
    push ix
    call _WK_GETWRK
    ld a,(ix+4)
    and 00001111b
    pop ix
    ret


; -----------------------------------------------------------------------------
; Store the misc flags (lower four bits only)
;
; Input: A = misc flags

WK_SET_MISC_FLAGS:
    push bc
    push ix
    rlca
    rlca
    rlca
    rlca
    and 11110000b
    push af
    call _WK_GETWRK
    ld a,(ix+4)
    and 00001111b
    pop bc
    or b
    ld (ix+4),a
    pop ix
    pop bc
    ret


; -----------------------------------------------------------------------------
; Retrieve the misc flags
;
; Input: A = misc flags (in low nibble)

WK_GET_MISC_FLAGS:
    push ix
    call _WK_GETWRK
    ld a,(ix+4)
    pop ix
    and 11110000b
    ret z
    rrca
    rrca
    rrca
    rrca
    ret


; -----------------------------------------------------------------------------
; Initialize work area for a storage device

WK_INIT_FOR_STORAGE_DEV:
    call WK_ZERO
    call _WK_GETWRK
    ld (ix),80h
    ld (ix+1),0
    ret


; -----------------------------------------------------------------------------
; Retrieve the storage device flags
;
; Output: A = storage device flags byte
;         NZ if a storage device is connected, Z otherwise

WK_GET_STORAGE_DEV_FLAGS:
    push hl
    push de
    push bc
    push ix
    call _WK_GETWRK
    ld a,(ix)
    pop ix
    pop bc
    pop de
    pop hl
    bit 7,a
    ret


; -----------------------------------------------------------------------------
; Set the storage device flags
;
; Input: A = storage device flags byte

WK_SET_STORAGE_DEV_FLAGS:
    push ix
    push af
    call _WK_GETWRK
    pop af
    ld (ix),a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Retrieve the current directory depth for the storage device
;
; Output: A = current directory depth

WK_GET_CUR_DIR_DEPTH:
    push ix
    call _WK_GETWRK
    ld a,(ix+1)
    pop ix
    ret


; -----------------------------------------------------------------------------
; Set the current directory depth for the storage device
;
; Input: A = directory depth to set

WK_SET_CUR_DIR_DEPTH:
    push ix
    push af
    call _WK_GETWRK
    pop af
    ld (ix+1),a
    pop ix
    ret


; -----------------------------------------------------------------------------
; Get the storage address for a given work area value
;
; Input: B = value index (0-7)
; Output: HL = storage address for that value in work area

_WK_GET_POINTER:
    push af
    push bc
    call _WK_GETWRK
    pop bc
    ld c,b
    ld b,0
    add hl,bc
    pop af
    ret


; -----------------------------------------------------------------------------
; Get the base address of work area for our slot
;
; This is the GETWRK routine copied from the kernel code with a small change:
; the address of the SLTWRK entry is returned directly, the original code
; assumes that at offset +2 there's a pointer for allocated space in page 3
; and returns this pointer.
;
; Output: HL = IX = pointer to 8 byte area for the slot in SLTWRK

_WK_GETWRK:
	call _WK_GETSLTWRK			; get my SLTWRK entry
    dec hl
    dec hl
	push hl
	pop	ix
	ret

;	Subroutine	get my SLTWRK entry
;	Inputs		-
;	Outputs		HL = pointer to SLTWRK entry

_WK_GETSLTWRK:
	call _WK_GETEXPTBL			; get my primairy slot
	add	a,a
	add	a,a
	add	a,a
	scf
	adc	a,a			; primary slot*4 + 1
	ld c,a
	ld a,(hl)
	add	a,a
	sbc	a,a
	and	00CH			; 0 for non expanded, 0CH for expanded
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	and	(hl)
	or c
	add	a,a			; word entries
	ld hl,SLTWRK
	jr _WK_ADDHLA

;	Subroutine	get my EXPTBL entry
;	Inputs		-
;	Outputs		HL = pointer to SLTWRK entry

_WK_GETEXPTBL:
	call 0F365h  ;read primary slotregister
	rrca
	rrca
	and	003H
	ld hl,EXPTBL
	ld b,000H
_WK_ADDHLA:
	ld c,a
	add hl,bc
	ret    