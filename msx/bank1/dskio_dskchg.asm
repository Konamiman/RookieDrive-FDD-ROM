; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This file contains the implementation of the DSKIO, DSKCHG and GETDPB
; driver routines.


; Error codes used by DSKIO, DSKCHG and GETDPB:
;
; 0	write protect error
; 2	not ready error
; 4	data (crc) error
; 6	seek error
; 8	record not found error
; 10 write fault error
; 12 other error


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

DSKIO_STACK_SPACE: equ 32

DSKIO_IMPL:

    jr nc,DSKIO_IMPL_DO
    call DSKIO_IMPL_DO
    ld b,0
    ret
DSKIO_IMPL_DO:

    if USE_ROM_AS_DISK

    ; In ROM disk mode writing is not supported 
    ; and reading is done by individual sectors.

    jr nc,DSKIO_IMPL2
    xor a   ;Write protected error
    scf
    ld b,0
    ret
DSKIO_IMPL2:

    else

    ; If single sided disk, do transfer by individual sectors
    ; unless first and last sector are on the same track
    ; (dividing both by 9 yields the same value).

    push af
    call IS_SINGLE_SIDED
    jr z,DSKIO_IMPL3
    pop af
    jr DSKIO_IMPL5
DSKIO_IMPL3:

    push bc
    push hl
    push de
    ex de,hl
    call DIV9 ;A  = HL/9 = first sector track
    pop hl    ;HL = first sector
    push hl
    ld e,b
    ld d,0
    add hl,de
    dec hl    ;HL = last sector
    ld b,a    ;B = first sector track
    call DIV9 ;A = last sector track
    cp b
    pop de
    pop hl
    pop bc
    jr nz,DSKIO_IMPL4

    pop af
    jr DSKIO_IMPL5

DSKIO_IMPL4:
    pop af

    endif

    ;di
    ;call 0FFCFh

    ld ix,0  ;Count of transferred sectors
DSKIO_IMPLOOP:
    push af
    push bc
	push de
	push hl
    push ix
    ld b,1
	call DSKIO_IMPL5
    jr c,DSKIO_IMPLOOP_ERR
    pop  ix
	pop  hl
	inc  h
	inc  h
	pop  de
	inc  de
	pop  bc
    inc ix
    pop  af
	djnz DSKIO_IMPLOOP  ;DJNZ preserves the carry flag

    ;call 0FFD4h
    ;ei

    ld b,ixl
    xor a

    ret

DSKIO_IMPLOOP_ERR:
    pop ix
    pop hl
    pop de
    pop bc
    ld b,c
    inc sp  ;Remove pushed AF without popping it
    inc sp
    ret

DSKIO_IMPL5:

    if DEBUG_DSKIO
    call DO_DEBUG_DSKIO
    endif

    call CHECK_SAME_DRIVE

    push af
    cp 2
    jr nc,_DSKIO_ERR_PARAM

    bit 7,b ;Sanity check: transfer of 64K or more requested?
    jr z,_DSKIO_OK_UNIT

_DSKIO_ERR_PARAM:
    pop af
    ld a,12
    scf
    ret

_DSKIO_OK_UNIT:
    push hl
    push de
    push bc
    call USB_CHECK_DEV_CHANGE
    pop bc
    pop de
    pop hl
    ld a,12
    jr c,_DSKIO_ERR_PARAM   ;No device is connected

    call WK_GET_STORAGE_DEV_FLAGS
    jp nz,_DSKIO_IMPL_STDEV


    ;=== DSKIO for floppy disk drives ===

    ld a,b
    pop bc
    rrc c   ;Now C:7 = 0 to read, 1 to write
    ld b,a

    ;ld a,b
    or a
    ret z   ;Nothing to read

    push hl
    push de
    push bc
    call TEST_DISK
    pop bc
    pop de
    pop hl
    ret c

    call IS_SINGLE_SIDED
    call z,ADJUST_SECTOR_NUMBER

    ld ix,-DSKIO_STACK_SPACE
    add ix,sp
    ld sp,ix

    push hl
    push de
    push bc

    push ix
    pop de
    ld hl,_UFI_READ_SECTOR_CMD
    ld bc,12
    ldir
    
    pop bc
    bit 7,c
    jr z,_DSKIO_OK_CMD
    ld a,2Ah    ;Convert "Read sector" command into "Write sector" command
    ld (ix),a
_DSKIO_OK_CMD:    
    pop de
    ld (ix+4),d   ;First sector number
    ld (ix+5),e
    pop de      ;DE = Transfer address

    ;  At this point:
    ;  IX = Read or write sector command, with the proper sector number and count=1
    ;  DE = Transfer address
    ;  B  = Sector count

    ;* Check if we can transfer sectors directly or we need to transfer one by one.
    ;* We'll start with one by one transfer if page 1 is involved in the transfer.

    call CHECK_XFER_IS_NEEDED
    jr c,_DSKIO_ONE_BY_ONE

    ;>>> Direct transfer
    ;    We transfer sectors directly from/to the source/target address,
    ;    in 16 sector chunks (some device NAK or fail on larger transfers)

_DSKIO_DIRECT_TRANSFER:
    ld c,0 
_DSKIO_DIRECT_TRANSFER_LOOP:
    ;Here IX=Read/write command, DE=Transfer address, B=Sectors remaining, C=Sectors transferred so far

    ld a,b
    or a
    jp z,_DSKIO_TX_END    ;Terminate if no more sectors to transfer
    cp 16
    jr c,_DSKIO_DIRECT_TRANSFER_OK_COUNT
    ld a,16
_DSKIO_DIRECT_TRANSFER_OK_COUNT:
    ld (ix+8),a     ;Set sector count on command
    push bc
    push de
    call _DSKIO_DO_SECTOR_TX
    pop hl  ;transfer address
    jr nc,_DSKIO_DIRECT_TRANSFER_OK_BLOCK

    ;Transfer error: just update transferred sectors count and terminate

    srl b   ;B=transferred sectors (will always be 0 on write, that's ok)
    pop hl  ;L=Sectors transferred so far
    push af
    ld a,l
    add b
    ld c,a
    pop af
    scf
    jr _DSKIO_TX_END

_DSKIO_DIRECT_TRANSFER_OK_BLOCK:
    ld b,(ix+8) ;Transfer length in sectors
    sla b
    ld c,0      ;BC = transfer length in bytes
    add hl,bc   ;Update transfer address
    ex de,hl
    ld h,b
    srl h   ;H=transfer length in sectors

    pop bc
    ld a,c
    add h
    ld c,a  ;Update sectors transferred so far
    ld a,b
    sub h
    ld b,a  ;Update remaining sectors

    push hl
    push bc
    ld c,h
    ld b,0
    ld h,(ix+4)
    ld l,(ix+5)
    add hl,bc     ;Update sector number
    ld (ix+4),h
    ld (ix+5),l
    pop bc
    pop hl

    jr _DSKIO_DIRECT_TRANSFER_LOOP

    ;>>> One by one sector transfer, using SECBUF and XFER

_DSKIO_ONE_BY_ONE:
    ld c,0
_DSKIO_TX_LOOP:
    ;Here IX=Read/write command, DE=Transfer address, B=Sectors remaining, C=Sectors transferred so far

    bit 7,d ;Switch to direct transfer if source/target address becomes >=8000h
    jr nz,_DSKIO_DIRECT_TRANSFER_LOOP

    push bc
    push de

    ld a,(ix)   ;Command is 28h to read or 2Ah to write
    cp 2Ah
    jr z,_DSKIO_WRITE_XFER

_DSKIO_READ_XFER:
    ld de,(SECBUF)
    call _DSKIO_DO_SECTOR_TX
    jr c,_DSKIO_TX_END_POP

    pop de
    push de
    ld hl,(SECBUF)
    ld bc,512
    call CALL_XFER

    jr _DSKIO_TX_STEP_OK

_DSKIO_WRITE_XFER:
    pop hl
    push hl
    ld de,(SECBUF)
    ld bc,512
    call CALL_XFER

    ld de,(SECBUF)
    call _DSKIO_DO_SECTOR_TX
    jr c,_DSKIO_TX_END_POP

    jr _DSKIO_TX_STEP_OK

    ;* One sector was transferred ok

_DSKIO_TX_STEP_OK:
    pop de
    inc d
    inc d   ;Update transfer address (+512 bytes)

    pop bc
    inc c   ;Update total sectors already transferred count

    ld h,(ix+4)
    ld l,(ix+5)
    inc hl      ;Update sector number
    ld (ix+4),h
    ld (ix+5),l

    djnz _DSKIO_TX_LOOP 
    jr _DSKIO_TX_END

_DSKIO_TX_END_POP:
    pop hl
    pop bc
_DSKIO_TX_END:
    ld b,c
_DSKIO_TX_END_2:    
    push af
    pop hl
    ld ix,DSKIO_STACK_SPACE
    add ix,sp
    ld sp,ix
    push hl
    pop af
    ret

    ;--- This routine does the actual sector transfer
    ;    Input:  IX = UFI read or write command address,
    ;                 with proper sector number and sector count set
    ;            DE = Transfer address
    ;    Output: On success: Cy = 0
    ;            On error:   Cy = 1, A = DSKIO error code
    ;            BC = Amount of bytes transferred (on read only)
    ;    Preserves IX

_DSKIO_DO_SECTOR_TX:
    push ix
    pop hl
    ld b,(ix+8)
    sla b
    ld c,0  ;BC = Bytes to transfer
    ld a,(ix)   ;Command is 28h to read or 2Ah to write
    rra
    rra     ;Now Cy=0 to read or 1 to write
    ld a,1  ;Retry "media changed"

    push ix
    if USE_ROM_AS_DISK
    call READ_DATA_FROM_ROM
    else
    call USB_EXECUTE_CBI_WITH_RETRY
    endif
    pop ix

    or a
    ld a,12
    scf
    ret nz   ;Return "other error" on USB error

_DSKIO_DO_SECTOR_TX_2:
    ld a,d
    or a
    jp nz,ASC_TO_ERR

    ld a,(ix)
    cp 2Ah
    ld a,0
    ret z

    ld a,b
    cp 2
    ld a,12
    ret c  ;Return "other error" if no whole sector was read

    xor a   ;Success if ASC = 0 and whole sector was transferred
    ret

_UFI_READ_SECTOR_CMD:
    db 28h, 0, 0, 0, 255, 255, 0, 0, 1, 0, 0, 0   ;bytes 4 and 5 = sector number, byte 8 = transfer length

;_UFI_WRITE_SECTOR_CMD:
;    db 2Ah, 0, 0, 0, 255, 255, 0, 0, 1, 0, 0, 0   ;bytes 4 and 5 = sector number, byte 8 = transfer length

CALL_XFER:
    push af
    push ix
    ld a,(XFER)
    cp 0C9h
    jr z,CALL_OWN_XFER

    ld iy,ROM_BANK_0
    ld ix,XFER
    call CALL_BANK
    pop ix
    pop af
    ret

CALL_OWN_XFER:
    ld ix,-(OWN_XFER_END-OWN_XFER)
    add ix,sp
    ld sp,ix

	PUSH	HL
	PUSH	DE
	PUSH	BC
    push ix
    pop de
    ld hl,OWN_XFER
    ld bc,OWN_XFER_END-OWN_XFER
    ldir

    ld iy,CALL_OWN_XFER_END
    push iy     ;Return address after "jp (ix)"
    push ix
    ld ix,A402D ;Get my slot number
    ld iy,ROM_BANK_0
	CALL	CALL_BANK   ;Get my own slot
    pop ix
    jp (ix)

CALL_OWN_XFER_END:
    ld ix,OWN_XFER_END-OWN_XFER
    add ix,sp
    ld sp,ix

    pop ix
    pop af
    ret

OWN_XFER:
    pop iy  ;Return address
    push af ;Save old slot number
	LD	H,40H
	LD	A,(RAMAD1)
	CALL	ENASLT
    pop af
	POP	BC
	POP	DE
	POP	HL
	LDIR
    push iy
	LD	H,40H
	CALL	ENASLT
	RET
OWN_XFER_END:


    if USE_ROM_AS_DISK

; Read sector data from ROM, which is supposed to contain a .DSK file
; starting at block 4 (only ASCII 8 is supported)
;
; Input: IX = CBI command that was supposed to be executed,
;             must be a "read" command (28h); sector number is
;             at positions 4 and 5 in big endian.
;        DE = Transfer address

READ_DATA_FROM_ROM:
    ld a,(ix)
    cp 28h
    ld a,1
    ret nz

    push de     ;Save transfer address

    ld h,(ix+4)
    ld l,(ix+5) ;HL = sector number

    ;There are 16 sectors per 8K ROM block.
    ;Divide sector number by 16 and add 4
    ;to get the ROM block number.
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l

    ld bc,4
    add hl,bc
    ex de,hl   ;Now E = ROM block number

    ;Sector address within ROM block is
    ;((sec num & 15) * 512) + 6000h
    ld a,(ix+5)
    and 15
    ld h,a
    ld l,0
    add hl,hl
    set 6,h
    set 5,h     ;Now HL = sector address within ROM block

    ld a,e
    ld (6800h),a    ;Select ROM block
    pop de
    ld bc,512
    ldir    ;Do transfer

    ld a,3
    ld (6800h),a    ;Restore original ROM block

    xor a
    ld bc,512   ;Bytes transferred
    ld de,0     ;Fake successful ASC and ASCQ
    ret

    endif


    ;=== DSKIO for storage devices (mounted file) ===

_DSKIO_IMPL_STDEV:
    ; Wait for VDP interrupt.
	; This introduces a small delay that is required by some games.

    push af
	di
	ld	a,2
	out	(99h),a
	ld	a,8fh
	out	(99h),a
WVDP:
	in	a,(99h)
	and	81h
	dec	a
	jr	z,WVDP
	xor	a
	out	(99h),a
	ld	a,8fh
	out	(99h),a
    pop af

    call MAYBE_CHANGE_DSK

    push hl
    push bc

    call WK_GET_STORAGE_DEV_FLAGS
    and 0FBh    ;reset  "Disk changed" flag
    call WK_SET_STORAGE_DEV_FLAGS

    ld h,0
    ld l,d
    ld d,e
    ld e,0
    sla d
    rl l
    rl h    ;HLDE = DE*512
    call HWF_SEEK_FILE

    pop bc
    pop hl
    ld c,b
    ld b,0
    or a
    jr z,_DSKIO_IMPL_STDEV_SEEKOK

    call WK_GET_STORAGE_DEV_FLAGS
    and 81h
    cp 80h
    jp z,_DSKIO_IMPL_POPAF_RET_ERR  ;Storage device but no disk mounted

    pop hl  ;Discard input AF
    dec a
    ld a,8  ;Record not found
    scf
    ret z
    ld a,12 ;Other error
    ret

_DSKIO_IMPL_STDEV_SEEKOK:
    ld b,c

    call DSK_TEST_CAPS_LIT_WK
    jr nz,_DSKIO_IMPL_STDEV_GO_CAPS
    pop af
    jr _DSKIO_IMPL_STDEV_GO

_DSKIO_IMPL_STDEV_GO_CAPS:
    pop af
    call CAPSON
    call _DSKIO_IMPL_STDEV_GO
    call CAPSOFF
    ret

_DSKIO_IMPL_STDEV_GO:
    jp c,_DSKIO_IMPL_STDEW_WRITE


    ;=== DSKIO for storage devices - READ ===

_DSKIO_IMPL_STDEW_READ:
    ex de,hl
    call CHECK_XFER_IS_NEEDED
    ex de,hl
    jr c,_DSKIO_R_STDEV_XFER

    ;* Direct transfer

_DSKIO_R_STDEV_DIRECT:
    sla b
    ld c,0  ;BC = B*512
    call HWF_READ_FILE
    srl b  ;B = BC/512

    or a
    ld a,12
    scf
    ret nz
    
    xor a
    ret

    ;* Transfer using XFER

_DSKIO_R_STDEV_XFER:
    ld c,0
_DSKIO_R_STDEV_XFER_LOOP:
    push bc ;B=Sectors left, C=Sectors transferred
    push hl ;Dest address

    ld hl,(SECBUF)
    ld bc,512
    call HWF_READ_FILE
    or a
    jr nz,_DSKIO_IMPL_STDEV_XFER_ERR
    ld a,b
    cp 2
    jr c,_DSKIO_IMPL_STDEV_XFER_ERR ;Error if less than 1 sector transferred

    pop de
    push de

    ld hl,(SECBUF)
    ld bc,512
    call CALL_XFER

    pop hl
    pop bc
    inc c
    inc h
    inc h   ;HL=HL+512
    djnz _DSKIO_R_STDEV_XFER_LOOP

    ld b,c
    xor a
    ret


    ;=== DSKIO for storage devices - WRITE ===

_DSKIO_IMPL_STDEW_WRITE:
    call WK_GET_STORAGE_DEV_FLAGS
    and 2   ;Read only?
    ld a,0
    scf
    ret nz

    ex de,hl
    call CHECK_XFER_IS_NEEDED
    ex de,hl
    jr c,_DSKIO_W_STDEV_XFER

    ;* Direct transfer

_DSKIO_W_STDEV_DIRECT:
    sla b
    ld c,0  ;BC = B*512
    call HWF_WRITE_FILE
    srl b  ;B = BC/512

    or a
    ld a,12
    scf
    ret nz
    
    xor a
    ret

    ;* Transfer using XFER

_DSKIO_W_STDEV_XFER:
    ld c,0
_DSKIO_W_STDEV_XFER_LOOP:
    push bc ;B=Sectors left, C=Sectors transferred
    push hl ;Src address

    ld de,(SECBUF)
    ld bc,512
    call CALL_XFER

    ld hl,(SECBUF)
    ld bc,512
    call HWF_WRITE_FILE
    or a
    jr nz,_DSKIO_IMPL_STDEV_XFER_ERR
    ld a,b
    cp 2
    jr c,_DSKIO_IMPL_STDEV_XFER_ERR ;Error if less than 1 sector transferred

    pop hl
    pop bc
    inc c
    inc h
    inc h   ;HL=HL+512
    djnz _DSKIO_W_STDEV_XFER_LOOP

    ld b,c
    xor a
    ret


    ;=== DSKIO for storage devices - common ===

_DSKIO_IMPL_STDEV_XFER_ERR:
    pop hl
    pop bc
    ld b,c
    ld a,12
    scf
    ret

_DSKIO_IMPL_POPAF_RET_ERR:
    pop af
    ld b,0
    ld a,2
    scf
    ret


    ;-- Check if transfer can be done directly or if we need to use XFER
    ;   (XFER will be needed if page 1 is involved in the transfer).
    ;
    ;   Input:  DE = Transfer address
    ;           B  = How many sectors to transfer
    ;   Output: Cy = 0 if direct transfer is possible
    ;                1 if XFER is needed

CHECK_XFER_IS_NEEDED:
    bit 7,d
    scf
    ccf
    ret nz    ;Transfer starts at >= 8000h, so direct ok
    bit 6,d
    scf
    ret nz    ;Transfer starts at >= 4000h and <8000h, so XFER needed
    push de
    push bc
    ex de,hl
    sla b
    ld c,0  ;BC = Sectors * 512
    add hl,bc
    dec hl  ;Now HL = Last transfer address
    pop bc
    pop de
    ld a,h
    cp 40h  ;If transfer starts at <4000h, it must end at <4000h for direct transfer
    ccf
    ret


; Is the disk (or we must consider it) single sided?
; Input:  C = Media ID (used only in FDD mode 0)
; Output: Z if single side disk, NZ if double sided disk

IS_SINGLE_SIDED:
    push hl
    push de
    push bc
    call WK_GET_MISC_FLAGS
    pop bc
    pop de
    pop hl
    and 110b
    cp 10b
    ret z      ;01x: single sided
    and 100b   ;1xx: double sided
    ret nz     ;00x: look at media ID byte

    ld a,c
    cp 0F0h
    ret z
    and 1
    ret


; Adjust the sector number to skip the tracks belonging to the second side,
; this is needed for single side disks.
;
; Sectors are arranged in the following way in a double side disk:
; First 9 sectors: track 0 of side 1
; Next 9 sectors:  track 0 of side 2
; Next 9 sectors:  track 1 of side 1
; Next 9 sectors:  track 1 of side 2...
;
; The disk drive doesn't know about single sided disks so it will always
; try to read sectors according to the above arrangement.
; Thus if the disk is single sided, we need to adjust the sector number
; so that the side 2 tracks are skipped.
;
; The adjustment formula is:
; ((sector number / 9) * 9) * 2 + (sector number MOD 9)
; 
; Input:  B = Sector count
;         DE = Sector number
;         HL = Transfer address
; Output: DE = Adjusted sector number
; Preserves HL, BC

ADJUST_SECTOR_NUMBER:
    call DRIVE_RECOGNIZES_SS_DISK
    ret z   ;The drive itself adjusts the sector number already

    push hl     ;Save transfer address
    push de     ;Save sector number

    ex de,hl    ;HL = sector number
    call DIV9   ;A = sector number / 9

    ld l,a
    ld h,0
    ld e,a
    ld d,h     ;HL = DE = sector number / 9
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,de
    ex de,hl   ;DE = (sector number / 9) * 9

    pop hl     ;HL = sector number
    push de    ;Save (sector number / 9) * 9
    or a
    sbc hl,de
    ex de,hl   ;DE = sector number - ((sector number / 9) * 9) = (sector number MOD 9)
    
    pop hl     ;HL = (sector number / 9) * 9
    add hl,hl  ;HL = ((sector number / 9) * 9) * 2
    add hl,de  
    ex de,hl   ;DE = ((sector number / 9) * 9) * 2 + (sector number MOD 9)

    pop hl     ;Restore transfer address
    ret


; Division by nine, valid in the range 0-1440
; By Ricardo Bittencourt
; Input:  HL = sector number
; Output: A = HL/9
; Corrupts HL, DE

DIV9:   INC     HL              ;  7    1
        LD      D,H             ;  5    1
        LD      E,L             ;  5    1
        ADD     HL,HL           ;  12   1
        ADD     HL,HL           ;  12   1
        ADD     HL,HL           ;  12   1
        SBC     HL,DE           ;  17   2
        LD      E,0             ;  8    2
        LD      D,L             ;  5    1
        LD      A,H             ;  5    1
        ADD     HL,HL           ;  12   1
        ADD     HL,HL           ;  12   1
        ADD     HL,DE           ;  12   1
        ADC     A,E             ;  5    1
        XOR     H               ;  5    1
        AND     03FH            ;  8    2
        XOR     H               ;  5    1
        RLCA                    ;  5    1
        RLCA                    ;  5    1
        RET            ; total  = 157  22 


    ;=== Handle possible disk image file change ===

MAYBE_CHANGE_DSK:
    push af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
    ld iy,-65
    add iy,sp
    ld sp,iy
	call	_MAYBE_CHANGE_DSK
    ld iy,65
    add iy,sp
    ld sp,iy
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
    pop af
	ret

_MAYBE_CHANGE_DSK:
    push iy
    call GETCURKEY
    pop iy
    or a
    ret z
    cp 0FFh
    jr nz,CHGF3

    call CAPSON
    call WAIT_KEY_RELEASE ;CODE/KANA pressed: wait for other keys to release...

CHGWA2:
    call CAPSON
CHGWA22:
    push iy
	call	GETCURKEY	;...then to be pressed again.
    pop iy
	or	a
	jr	z,CHGWA22

    cp 0FFh      ;User changed his mind and pressed GRAPH 
    jr nz,CHGF3

    call WAIT_KEY_RELEASE
    call CAPSOFF
    ret

CHGF3:
	ld	c,a
	call	CAPSOFF

    ;--- The key with index C is pressed

    push bc
    push iy
    pop hl
    call DSK_GET_CURDIR
    pop bc

    ld a,c
    dec a
    push iy
    pop hl
    push hl
    call HWF_FIND_NTH_FILE
    pop hl
    or a
    jr nz,CHGWA2

    ld de,12
    add hl,de
    ex de,hl
    push iy
    pop hl
    push de
    call BM_GENERATE_FILENAME
    pop hl

    xor a
    call DSK_MOUNT
    or a
    jr nz,CHGWA2

CHGF_END:
    call WAIT_KEY_RELEASE
    call MYKILBUF
    call CAPSOFF
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

DSKCHG_IMPL:
    call CHECK_SAME_DRIVE

    cp 2
    ld a,12
    ccf
    ret c

    if USE_ROM_AS_DISK
    xor a
    ld b,1
    ret
    endif

    push hl
    call USB_CHECK_DEV_CHANGE
    pop hl
    ld a,12
    ret c   ;No device is connected

    push af
    call WK_GET_STORAGE_DEV_FLAGS
    jp nz,_DSKCHG_IMPL_STDEV
    pop af

    push hl
    call TEST_DISK
    pop hl
    ret c

    ld a,b
    dec a   ;Disk unchanged?
    ret z

    push bc
    call GETDPB_IMPL
    pop bc
    xor a
    ret

_DSKCHG_IMPL_STDEV:
    and 81h
    cp 80h
    jp z,_DSKIO_IMPL_POPAF_RET_ERR  ;Storage device but no disk mounted

    call MAYBE_CHANGE_DSK

    pop af
    
    call WK_GET_STORAGE_DEV_FLAGS
    and 4
    ld a,0
    ld b,1  ;Unchanged
    ret z
    call GETDPB_IMPL
    xor a
    ld b,0FFh   ;Changed
    ret


; -----------------------------------------------------------------------------
; GETDPB
; -----------------------------------------------------------------------------
; Input: 	A	Drivenumber
; 		B	first byte of FAT
; 		C	Media descriptor
; 		HL	pointer to DPB
; Output:	[HL+1]
;		..
;		[HL+18]	updated
; Changed:	AF,BC,DE,HL,IX,IY may be affected
; -----------------------------------------------------------------------------

; This routine was borrowed from https://github.com/joyrex2001/dsk2rom

GETDPBERR:
	pop  bc
	pop  af
	ld   a,12
	scf
	ret
GETDPB_IMPL:
	push af 
	push bc 
	push hl 
	ld   hl,(SECBUF)
	push hl
	ld   b,1
	ld   de,0 
	or   a 
	ld   c,0FFh 
	call DSKIO_IMPL
	pop  iy 
	pop  hl 
	jr   c,GETDPBERR
	inc  hl
	push hl
	ex   de,hl
	ld   hl,DEFDPB_1+1
	ld   bc,18
	ldir
	pop  hl
	ld   a,(iy+21)
	cp   0F9h
	jr   z,GETDPBEND 
	ld   (hl),a
	inc  hl
	ld   a,(iy+11)
	ld   (hl),a
	inc  hl
	ld   a,(iy+12)
	ld   (hl),a
	inc  hl
	ld   (hl),0Fh
	inc  hl
	ld   (hl),04h
	inc  hl
	ld   a,(iy+0Dh)
	dec  a
	ld   (hl),a
	inc  hl
	add  a,1
	ld   b,0
GETDPB0: 
	inc  b
	rra 
	jr   nc,GETDPB0
	ld   (hl),b
	inc  hl
	push bc
	ld   a,(iy+0Eh)
	ld   (hl),a
	inc  hl
	ld   d,(iy+0Fh)
	ld   (hl),d
	inc  hl
	ld   b,(iy+010h)
	ld   (hl),b
	inc  hl
GETDPB1: 
	add  a,(iy+016h)
	jr   nc,GETDPB2
	inc  d
GETDPB2: 
	djnz GETDPB1
	ld   c,a
	ld   b,d
	ld   e,(iy+011h)
	ld   d,(iy+012h)
	ld   a,d
	or   a
	ld   a,0FEh
	jr   nz,GETDPB3
	ld   a,e
GETDPB3: 
	ld   (hl),a
	inc  hl
	dec  de
	ld   a,4
GETDPB4: 
	srl  d
	rr   e
	dec  a
	jr   nz,GETDPB4
	inc  de
	ex   de,hl
	add  hl,bc
	ex   de,hl
	ld   (hl),e
	inc  hl
	ld   (hl),d
	inc  hl
	ld   a,(iy+013h)
	sub  e
	ld   e,a
	ld   a,(iy+014h)
	sbc  a,d
	ld   d,a
	pop  af
GETDPB5: 
	dec  a
	jr   z,GETDPB6
	srl  d
	rr   e
	jr   GETDPB5
GETDPB6:
	inc  de
	ld   (hl),e
	inc  hl
	ld   (hl),d
	inc  hl
	ld   a,(iy+016h)
	ld   (hl),a
	inc  hl
	ld   (hl),c
	inc  hl
	ld   (hl),b
GETDPBEND: 
	pop  bc
	pop  af 
	xor  a
	ret


;Debug DSKIO

    if DEBUG_DSKIO

CHGCLR: equ 0062h
INIPLT: equ 0141h
EXTROM: equ 015Fh
BEEP:   equ 00C0h

DO_DEBUG_DSKIO:
    push af
    push bc
    push hl
    push de

    ld ix,INITXT
    call CALBIOS

    ld a,15
    ld (0F3E9h),a
    ld a,1
    ld (0F3EAh),a
    ld ix,CHGCLR
    call CALBIOS

    pop hl  ;Secnum (was DE)
    push hl
    call PRINTHEXBIOS_HL
    call PRINTSPACE

    pop de
    pop hl
    push hl     ;Dest address
    push de
    call PRINTHEXBIOS_HL
    call PRINTSPACE

    pop de
    pop hl
    pop bc
    push bc
    push hl
    push de
    ld a,b  ;Sec count
    call PRINTHEXBIOS

    ld ix,CHGET
    call CALBIOS

    pop de
    pop hl
    pop bc
    push bc
    push hl
    push de

BEEPS:
    push bc
    ld ix,BEEP
    call CALBIOS
    pop bc
    djnz BEEPS

    pop de
    pop hl
    pop bc
    pop af

    ret


CALBIOS:
    ld iy,0
    jp CALSLT

PRINTSPACE:
    ld a," "
PRINTBIOS:
    ld ix,CHPUT
    jp CALBIOS

PRINTHEXBIOS_HL:
    ld a,h
    call PRINTHEXBIOS
    ld a,l
PRINTHEXBIOS:
    push af
	call	_PRINTHEXBIOS1
	pop af
	jr	_PRINTHEXBIOS2

_PRINTHEXBIOS1:	rra
	rra
	rra
	rra
_PRINTHEXBIOS2:	or	0F0h
	daa
	add	a,0A0h
	adc	a,40h

	call PRINTBIOS
	ret

    endif