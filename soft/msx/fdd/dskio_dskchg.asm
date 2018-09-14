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

    exx
    ld bc,13
    call STACKALLOC
    push hl
    ex de,hl
    ld hl,_UFI_READ_SECTOR_CMD
    ld bc,13
    ldir
    pop ix  ;IX = Read Sector command
    exx
    ld (ix+4+1),d   ;First sector
    ld (ix+5+1),e

    ;* At this point:
    ;  IX = Read sector command, with the proper first sector number
    ;  HL = Transfer address
    ;  B  = Sector count

    ;If the last transfer address is in page 0,
    ;of if the first transfer address is in page 2 or 3,
    ;we transfer all sectors in one single operation.
    ;Otherwise we transfer sectors one by one using XFER.

    bit 7,h
    jr nz,_DSKIO_DIRECT     ;Transfer starts at page 2 or 3
    push hl
    push bc
    sla b
    ld c,0
    add hl,bc
    dec hl      ;Now HL = last transfer address
    ld a,h
    cp 40h
    pop bc
    pop hl
    jr c,_DSKIO_DIRECT

    ;--- Transfer using XFER

_DSKIO_WITH_XFER:
    ld c,0  ;C = Count of sectors successfully transferred
    ld (ix+8+1),1
_DSKIO_WITH_XFER_LOOP:    
    push bc
    push hl
    ld hl,(SECBUF)
    ld bc,512
    call _DSKIO_DO_READ
    pop hl
    pop bc
    jr c,_DSKIO_WITH_XFER_END

    push bc
    ex de,hl
    ld hl,(SECBUF)
    ld bc,512
    push ix
    call XFER
    pop ix
    pop bc
    ex de,hl    ;HL = Updated transfer address

    inc c   ;One more successful sector
    ;inc hl
    ;inc hl ;HL = HL + 512
    ld d,(ix+4+1)
    ld e,(ix+5+1)
    inc de      ;Update sector number
    ld (ix+4+1),d
    ld (ix+5+1),e
    djnz _DSKIO_WITH_XFER_LOOP

    xor a
_DSKIO_WITH_XFER_END:
    call STACKFREE
    ld b,c
    ret

    ;--- Direct transfer

_DSKIO_DIRECT:
    ld (ix+8+1),b
    sla b  ;Bytes count = sector count * 512
    ld c,0
    call _DSKIO_DO_READ
    call STACKFREE
    ret

    ;--- Routine for one execution of the Read Sector command
    ;    Input:  IX = Command address (with proper sector number and sector count set)
    ;            HL = Transfer address
    ;            BC = Bytes count
    ;    Output: B = transferred sectors count
    ;            HL increased by the transferred sectors count
    ;            On success: Cy = 0
    ;            On error:   Cy = 1, A = DSKIO error code
    ;            
    ;    Preserves IX

_DSKIO_DO_READ:
    ld de,0 ;Total sectors transferred
_DSKIO_DO_READ_LOOP    
    ex de,hl    ;HL = Total sectors transferred, DE = Transfer address
    push ix
    push hl
    push de
    push ix
    pop hl
    ld a,1  ;Retry "media changed"
    or a    ;Read data
    call USB_EXECUTE_CBI_WITH_RETRY
    push de
    pop iy  ;IY = ASC + ASCQ
    pop hl  ;HL = Transfer address
    pop de  ;DE = Total sectors transferred
    pop ix

    ld c,0
    res 0,b     ;BC = Bytes transferred, rounded down to sector boundary
    add hl,bc   ;HL = Updated transfer address
    ld c,b
    ld b,0
    sra c       ;BC = Count of sectors transferred in this iteration
    ex de,hl
    add hl,bc
    ex de,hl    ;DE = Updated total sectors transferred count
    ld b,e

    or a
    ld a,12
    scf
    ret nz  ;Return "other error" on USB error

    ld a,iyh
    or a
    ret z   ;Success if ASC = 0

    cp 8
    scf
    jp nz,ASC_TO_ERR

    ;* If ASC is of "logical unit communication" type, retry at the appropriate
    ;  transfer address, unles the amount of received data is < 1 sector

    ld a,c
    or a
    ld a,12
    scf
    ret z

    push hl
    ld h,(ix+4+1)
    ld l,(ix+5+1)
    ld b,0
    add hl,bc      ;Update sector number in the command
    ld (ix+4+1),h
    ld (ix+5+1),l
    pop hl

    jr _DSKIO_DO_READ_LOOP

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
    ld a,c
    ret

_ASC_TO_ERR:
    cp 27h      ;Write protected
    ld c,0
    ret z
    cp 3Ah      ;Not ready
    ld c,2
    ret z
    cp 10h      ;CRC error
    ld c,4
    ret z
    cp 21h      ;Invalid logical block
    ld c,6
    ret z
    cp 02h      ;Seek error
    ret z
    cp 03h
    ld c,10
    ret z
    ld c,12     ;Other error
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

