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
;		B	total count of sectors read
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
    call USB_CHECK_DEV_CHANGE
    pop bc
    pop de
    pop hl
    ld a,12
    ret c   ;No device is connected

    exx
    ld bc,13
    call STACKALLOC
    push hl
    ex de,hl
    ld hl,_UFI_READ_SECTOR_CMD
    ld bc,13
    ldir
    pop ix      ;IX = Read Sector command
    exx
    ld (ix+4),d   ;First sector number
    ld (ix+5),e
    ex de,hl    ;DE = Transfer address

    ;* Sector read loop. 
    ;  We read sectors one by one always, because some FDD units
    ;  choke when requested too many sectors at the same time
    ;  and become unresponsive until they are reset.
    ;
    ;  At this point:
    ;  IX = Read sector command, with the proper sector number
    ;  DE = Transfer address
    ;  B  = Sector count

    ld c,0  ;Count of sectors read so far
_DSKIO_READ_LOOP:
    push bc
    push de

    ld a,d
    cp 3Eh
    jr c,_DSKIO_READ_DIRECT
    and 80h
    jr nz,_DSKIO_READ_DIRECT

    ;* Read using SECBUF and XFER (transfer address is between 4000h and 7FFFh)

    ld de,(SECBUF)
    call _DSKIO_READ_ONE
    jr c,_DSKIO_READ_END_POP

    pop de
    push de
    ld hl,(SECBUF)
    ld bc,512
    call XFER

    jr _DSKIO_READ_STEP_OK

    ;* Direct read

_DSKIO_READ_DIRECT:
    call _DSKIO_READ_ONE
    jr c,_DSKIO_READ_END_POP

    ;* One sector was read ok

_DSKIO_READ_STEP_OK:
    pop de
    inc d
    inc d   ;Update transfer address (+512 bytes)

    pop bc
    inc c   ;Update total sectors already read count

    ld h,(ix+4)
    ld l,(ix+5)
    inc hl      ;Update sector number
    ld (ix+4),h
    ld (ix+5),l

    djnz _DSKIO_READ_LOOP 
    jr _DSKIO_READ_END

_DSKIO_READ_END_POP:
    pop de
    pop bc
_DSKIO_READ_END:    
    ld b,c
    ex af,af
    call STACKFREE
    ex af,af
    ret

    ;--- Routine for reading one sector
    ;    Input:  IX = Command address (with proper sector number and sector count set)
    ;            DE = Transfer address
    ;    Output: On success: Cy = 0
    ;            On error:   Cy = 1, A = DSKIO error code
    ;    Preserves IX
_DSKIO_READ_ONE:
    push ix
    pop hl
    ld bc,512   ;Bytes to transfer
    ld a,1  ;Retry "media changed"
    or a    ;Read data

    push ix
    call USB_EXECUTE_CBI_WITH_RETRY
    pop ix

    or a
    ld a,12
    scf
    ret nz   ;Return "other error" on USB error

    ld a,b
    cp 2
    ld a,12
    scf
    ret nz  ;Return "other error" if no whole sector was transferred

    ld a,d
    or a
    ret z   ;Success if ASC = 0

    call ASC_TO_ERR
    scf
    ret

_UFI_READ_SECTOR_CMD:
    db 28h, 0, 0, 0, 255, 255, 0, 0, 1, 0, 0, 0   ;bytes 4 and 5 = sector number, byte 8 = transfer length


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
    call USB_CHECK_DEV_CHANGE
    pop hl
    ld a,12
    ret c   ;No device is connected

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
    db 28h, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

