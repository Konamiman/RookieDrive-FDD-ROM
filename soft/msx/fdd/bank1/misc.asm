; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains miscellaneous routines used by other modules.


; -----------------------------------------------------------------------------
; ASC_TO_ERR: Convert UFI ASC to DSKIO error
; -----------------------------------------------------------------------------
; Input:  A = ASC
; Output: A = Error
;         Cy = 1

ASC_TO_ERR:
    call _ASC_TO_ERR
    ld a,h
    scf
    ret

_ASC_TO_ERR:
    cp 27h      ;Write protected
    ld h,0
    ret z
    cp 3Ah      ;Not ready
    ld h,2
    ret z
    cp 10h      ;CRC error
    ld h,4
    ret z
    cp 21h      ;Invalid logical block
    ld h,6
    ret z
    cp 02h      ;Seek error
    ret z
    cp 03h
    ld h,10
    ret z
    ld h,12     ;Other error
    ret


; -----------------------------------------------------------------------------
; TEST_DISK: Test if disk is present and if it has changed
;
; We need to call this before any attempt to access the disk,
; not only to actually check if it has changed,
; before some drives fail the READ and WRITE commands the first time
; they are executed after a disk change otherwise.
; -----------------------------------------------------------------------------
; Output:	F	Cx set for error
;			Cx reset for ok
;		A	if error, errorcode
;		B	if no error, disk change status
;			01 disk unchanged
;			00 unknown
;			FF disk changed

TEST_DISK:
    call _RUN_TEST_UNIT_READY
    ret c

    ld a,d
    or a
    ld b,1  ;No error: disk unchanged
    ret z

    ld a,d
    cp 28h  ;Disk changed if ASC="Media changed"
    ld b,0FFh
    ret z

    cp 3Ah  ;"Disk not present"
    jp nz,ASC_TO_ERR

    ;Some units report "Disk not present" instead of "medium changed"
    ;the first time TEST UNIT READY is executed after a disk change.
    ;So let's execute it again, and if no error is returned,
    ;report "disk changed".

    call _RUN_TEST_UNIT_READY
    ret c

    ld b,0FFh
    ld a,d
    or a
    ret z
    cp 28h  ;Test "Media changed" ASC again just in case
    ret z
    
    jp ASC_TO_ERR


; Output: Cy=1 and A=12 on USB error
;         Cy=0 and DE=ASC+ASCQ on USB success
_RUN_TEST_UNIT_READY:
    ld b,3  ;Some drives stall on first command after reset so try a few times
TRY_TEST:
    push bc    
    xor a   ;Receive data + don't retry "Media changed"
    ld hl,_UFI_TEST_UNIT_READY_CMD
    ld bc,0
    ld de,0
    call USB_EXECUTE_CBI_WITH_RETRY
    pop bc
    or a
    ret z
    djnz TRY_TEST

    ld a,12
    scf
    ret

_UFI_TEST_UNIT_READY_CMD:
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


; -----------------------------------------------------------------------------
; CHECK_SAME_DRIVE
;
; If the drive passed in A is not the same that was passed last time,
; display the "Insert disk for drive X:" message.
; This is needed for phantom drive emulation.
; -----------------------------------------------------------------------------
; Input: 	A	Drive number
; Preserves AF, BC, DE, HL
; -----------------------------------------------------------------------------

CHECK_SAME_DRIVE:
    push hl
    push de
    push bc
    push af
    
    cp 2
    jr nc,_CHECK_SAME_DRIVE_END ;Bad drive number, let the caller handle the error

    call WK_GET_LAST_REL_DRIVE
    pop bc
    cp b
    push bc
    jr z,_CHECK_SAME_DRIVE_END

    ld a,b
    call WK_SET_LAST_REL_DRIVE
    ld ix,PROMPT
    ld iy,ROM_BANK_0
    call CALL_BANK

_CHECK_SAME_DRIVE_END:
    pop af
    pop bc
    pop de
    pop hl
    ret


; -----------------------------------------------------------------------------
; SNSMAT: Read the keyboard matrix
;
; This is the same SNSMAT provided by BIOS, it's copied here to avoid
; having to do an interslot call every time it's used
; -----------------------------------------------------------------------------

DO_SNSMAT:
    ld c,a
    di
    in a,(0AAh)
    and 0F0h
    add c
    out (0AAh),a
    ei
    in a,(0A9h)
    ret

    ;row 6:  F3     F2       F1  CODE    CAPS  GRAPH  CTRL   SHIFT
    ;row 7:  RET    SELECT   BS  STOP    TAB   ESC    F5     F4
    ;row 8:	 right  down     up  left    DEL   INS    HOME  SPACE


; -----------------------------------------------------------------------------
; SNSMAT: Print a string describing an USB error code
; -----------------------------------------------------------------------------


