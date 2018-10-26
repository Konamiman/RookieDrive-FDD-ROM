; errorcodes used by DSKFMT
;
; 0	write protect error
; 2	not ready error
; 4	data (crc) error
; 6	seek error
; 8	record not found error
; 10	write fault error
; 12	bad parameter
; 14	insufficient memory
; 16	other error


; -----------------------------------------------------------------------------
; CHOICE
; -----------------------------------------------------------------------------
; Input: 	None
; Output:	HL	pointer to choice string, 0 if no choice
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

CHOICE_IMPL:
    call USB_CHECK_DEV_CHANGE
    ld hl,CHOICE_S_ERR_NO_DEV
    ret c   ;No device is connected

    call TEST_DISK

    ld a,1  ;Retry "disk changed" error
    call GET_DISK_INFO
    ld hl,CHOICE_S_ERR_DISK_INFO
    jr nc,_CHOICE_IMPL_OK_DISK

    ld hl,CHOICE_S_ERR_NO_DISK
    cp 2
    ret z
    ld hl,CHOICE_S_ERR_DISK_INFO
    ret

_CHOICE_IMPL_OK_DISK:
    bit 0,c
    ld hl,0
    ret z   ;Disk not formatted: only choice is full format

    ld hl,CHOICE_S_2DD
    bit 1,c
    ret z

	ld hl,CHOICE_S_2HD
    ret


; -----------------------------------------------------------------------------
; DSKFMT
; -----------------------------------------------------------------------------
; Input: 	A	choicecode (1-9)
;		D	drivenumber
;		HL	begin of workarea
;		BC	length of workarea
; Output:	F	Cx set for error
;			Cx reset for ok
;		A	if error, errorcode
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

DSKFMT_IMPL:
    ld c,a
    ld a,d
    or a
    jr z,_DSKFMT_BAD_PARAM
    ld a,c

    or a
    jr z,_DSKFMT_BAD_PARAM  ;Choice = 0
    cp 3
    jr nc,_DSKFMT_BAD_PARAM ;Choice > 2

    push af
    ld a,1
    call GET_DISK_INFO
    pop de
    jr c,_DSKFMT_END_ERR

    ld a,d  ;Choice
    cp 1
    jr z,_DSKFMT_FULL
    bit 0,c
    jr nz,_DSKFMT_BAD_PARAM     ;Quick format was requested but disk is not formatted
    jr _DSKFMT_QUICK

_DSKFMT_FULL:
    rr c
    rr c
    push bc
    call PHYSICAL_FORMAT
    pop bc
    jr c,_DSKFMT_END_ERR

_DSKFMT_QUICK:
    ;TODO: Initialize boot, FAT, root dir
    xor a
    ret

_DSKFMT_BAD_PARAM:
    ld a,12
    scf
    ret

_DSKFMT_END_ERR:
    cp 12
    jr nz,_DSKFMT_END_ERR2
    ld a,16
_DSKFMT_END_ERR2:
    scf
    ret


;Physically format the disk
;Input:  Cy=0 for 720K disk, 1 for 1.44M disk
;Output: Cy=0 inf ok, Cy=1 and A=DSKIO error code on error

_PHYSICAL_FORMAT_STACK_SPACE: equ 12
_PHYSICAL_FORMAT_TRACKS_COUNT: equ 80

PHYSICAL_FORMAT:
    ld hl,_UFI_FORMAT_UNIT_DATA_720K
    jr nc,_PHYSICAL_FORMAT_2
    ld hl,_UFI_FORMAT_UNIT_DATA_1440K
_PHYSICAL_FORMAT_2:

    ld ix,-_PHYSICAL_FORMAT_STACK_SPACE
    add ix,sp
    ld sp,ix

    push hl
    push ix
    pop de
    ld hl,_UFI_FORMAT_UNIT_CMD
    ld bc,12
    ldir
    pop hl

    ld b,0

    ;B=Track number, IX=Command, HL=Data
_PHYSICAL_FORMAT_TRACK_LOOP:
    ld (ix+2),b

    push ix
    push hl
    push bc

    ex de,hl
    push ix
    pop hl
    ld bc,12
    or a
    call USB_EXECUTE_CBI_WITH_RETRY

    pop bc
    pop hl
    pop ix

    or a
    ld a,12
    jr nz,_PHYSICAL_FORMAT_ERR_END

    ld a,d
    or a
    jr z,_PHYSICAL_FORMAT_NEXT_TRACK

    call ASC_TO_ERR
    jr _PHYSICAL_FORMAT_ERR_END

_PHYSICAL_FORMAT_NEXT_TRACK:
    inc b
    ld a,b
    cp _PHYSICAL_FORMAT_TRACKS_COUNT
    jr c,_PHYSICAL_FORMAT_TRACK_LOOP

_PHYSICAL_FORMAT_ERR_END:
    scf
_PHYSICAL_FORMAT_END:
    push af
    pop hl
    ld ix,_PHYSICAL_FORMAT_STACK_SPACE
    add ix,sp
    ld sp,ix
    push hl
    pop af
    ret

_UFI_FORMAT_UNIT_CMD:
    db 4, 17h, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0

_UFI_FORMAT_UNIT_DATA_720K:
    db 0, 0B0h, 0, 8, 0, 0, 05h, 0A0h, 0, 0, 2, 0

_UFI_FORMAT_UNIT_DATA_1440K:
    db 0, 0B0h, 0, 8, 0, 0, 0Bh, 040h, 0, 0, 2, 0


; -----------------------------------------------------------------------------
; GET_DISK_INFO: Get information about the disk currently in the drive
; -----------------------------------------------------------------------------
; Input:  A = 1 to retry "disk changed" error
; Output: A = DSKIO error code (if Cy=1)
;         Cy = 1 on error
;         B = FFh if disk changed
;              1 if disk unchanged
;              (only if A=0 at input)
;         C = bit 0: 1 if disk is already formatted
;             bit 1: 0 if disk is 720k, 1 if disk is 1.44M
;             (only if Cy=0 and B=1)


_GET_DISK_INFO_STACK_SPACE: equ 12

GET_DISK_INFO:
    ld ix,-_GET_DISK_INFO_STACK_SPACE
    add ix,sp
    ld sp,ix

    push ix
    pop de
    ld hl,_UFI_READ_FORMAT_CAPACITIES_CMD
    ld bc,12
    or a
    push ix
    call USB_EXECUTE_CBI_WITH_RETRY
    pop ix

    or a
    ld a,12
    scf
    jr nz,_GET_DISK_INFO_END   ;Return "other error" on USB error

    ld a,d
    or a
    jr z,_GET_DISK_INFO_NO_ERR
    cp 28h  ;"Disk changed" error
    ld b,0FFh
    jr z,_GET_DISK_INFO_OK
    jr _GET_DISK_INFO_ASC_ERR

_GET_DISK_INFO_NO_ERR:

    ;Useful information returned by the Read Format Capacities command:
    ;+6: High byte of disk capacity in sectors:
    ;    5h: 720K
    ;    4h: 1.25M
    ;    Bh: 1.44M 
    ;+8: Disk format status:
    ;    01b: unformatted
    ;    10b: formatted
    ;    11b: no disk in drive

    ld a,(ix+8)
    and 11b
    cp 3
    ld a,2
    scf
    jr z,_GET_DISK_INFO_END     ;Return "not ready" if no disk present

    ld a,(ix+8)
    and 1
    xor 1
    ld c,a  ;Now C = 0 for unformatted disk, 1 for formatted disk

    ld b,1  ;Disk not changed
    ld a,(ix+6)
    cp 05h
    jr z,_GET_DISK_INFO_OK
    set 1,c
    cp 0Bh
    jr z,_GET_DISK_INFO_OK

    ld c,10b    ;If the disk is 1.25M, report it as unformatted 1.44M
    jr _GET_DISK_INFO_END

_GET_DISK_INFO_ASC_ERR:
    call ASC_TO_ERR
    scf
    jr _GET_DISK_INFO_END
_GET_DISK_INFO_OK:
    xor a
_GET_DISK_INFO_END:
    push af
    pop hl
    ld ix,_GET_DISK_INFO_STACK_SPACE
    add ix,sp
    ld sp,ix
    push hl
    pop af
    ret

_UFI_READ_FORMAT_CAPACITIES_CMD:
    db 23h, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0


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