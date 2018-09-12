; -----------------------------------------------------------------------------
; DSKIO
; -----------------------------------------------------------------------------
; Input: 	A	Drivenumber
;		F	Cx reset for read
;			Cx set for write
; 		B	number of sectors
; 		C	Media descriptor
;		DE	logical sectornumber
; 		HL	transferaddress
; Output:	F	Cx set for error
;			Cx reset for ok
;		A	if error, errorcode
;		B	if error, remaining sectors
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

DSKIO:
    push af
    or a
    jr z,_DSKIO_OK_UNIT

    pop af
    ld a,12
    scf
    ret

_DSKIO_OK_UNIT:
    pop af
    ld a,0  ;Write protected error
    ret c

    ld a,b
    or a
    ret z   ;Nothing to read

    push hl
    push de
    push bc

    ld hl,_UFI_READ_SECTOR_CMD
    ld de,(SECBUF)
    push de
    pop ix
    ld bc,13
    ldir
    pop bc
    ld (ix+8+1),b
    pop de
    ld (ix+4+1),d
    ld (ix+5+1),e

    pop de  ;was HL, transfer address
    push ix
    pop hl  ;Command address
    push bc
    sla b
    ld c,0  ;Bytes count = sector count * 512
    ld a,1  ;Retry "media changed"
    or a    ;Read data
    call USB_EXECUTE_CBI_WITH_RETRY

    or a
    pop hl  ;Sector count
    ld a,12
    ld b,0
    scf
    ret nz  ;Return "other error" on USB error

    ld b,h
    ld a,d
    or a
    ret z   ;Sucess if ASC = 0

    call ASC_TO_ERR
    scf
    ld b,0
    ret

_UFI_READ_SECTOR_CMD:
    db 12
    db 28h, 0, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0   ;bytes 4 and 5 = sector number, byte 8 = transfer length


; -----------------------------------------------------------------------------
; ASC_TO_ERR: Convert ASC to DSKIO error
; -----------------------------------------------------------------------------
; Input:  A = ASC
; Output: A = Error

ASC_TO_ERR:
    call _ASC_TO_ERR
    ld a,b
    ret

_ASC_TO_ERR:
    cp 27h      ;Write protected
    ld b,0
    ret z
    cp 3Ah      ;Not ready
    ld b,2
    ret z
    cp 10h      ;CRC error
    ld b,4
    ret z
    cp 21h      ;Invalid logical block
    ld b,6
    ret z
    cp 02h      ;Seek error
    ret z
    cp 03h
    ld b,10
    ret z
    ld b,12     ;Other error
    ret


; -----------------------------------------------------------------------------
; DSKCHG
; -----------------------------------------------------------------------------
; Input: 	A	Drivenumber
; 		B	0
; 		C	Media descriptor
; 		HL	pointer to DPB
; Output:	F	Cx set for error
;			Cx reset for ok
;		A	if error, errorcode
;		B	if no error, disk change status
;			01 disk unchanged
;			00 unknown
;			FF disk changed
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; Remark:	DOS1 kernel expects the DPB updated when disk change status is
;               unknown or changed DOS2 kernel does not care if the DPB is
;               updated or not		
; -----------------------------------------------------------------------------

DSKCHG:
    or a
    ld a,12
    scf
    ret nz

    push hl
    ld hl,READ_0_SECTORS_CMD
    ld de,(SECBUF)
    push de
    ld bc,13
    ldir

    pop hl
    ld bc,0 ;We don't actually retrieve any data
    xor a   ;Don't retry "media changed" + Cy=0 (read data)
    call USB_EXECUTE_CBI_WITH_RETRY

    pop hl
    or a
    ld a,12
    scf
    ret nz  ;Return "other error" on USB error

    ld a,d
    or a
    ld b,1
    ret z   ;If no error, media hasn't changed

    cp 28h  ;ASC for "media changed"
    jr z,_DSKCHG_BUILD_DPB

    call ASC_TO_ERR
    scf
    ret

_DSKCHG_BUILD_DPB:
    xor a
    call GETDPB
    ld b,0FFh
    ret

READ_0_SECTORS_CMD:
    db 12
    db 28h, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

