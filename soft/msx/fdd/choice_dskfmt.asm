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
    ld hl,CHOICE_S
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
    call CHECK_SAME_DRIVE

    push bc
    call DSKCHG_IMPL    ;In case drive reports disk change as "not ready"
    pop bc

    dec c

    ;Now C = bit 0: 0 for full format, 1 for quick format
    ;        bit 1: 0 for 720K, 1 for 1440K

    rr c
    jr c,_DSKFMT_QUICK

_DSKFMT_FULL:
    push bc
    rr c
    call PHYSICAL_FORMAT
    pop bc
    jr c,_DSKFMT_END_ERR

_DSKFMT_QUICK:
    rr c
    call LOGICAL_FORMAT
    jr c,_DSKFMT_END_ERR
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


;--- Physically format the disk
;    Input:  Cy=0 for 720K disk, 1 for 1.44M disk
;    Output: Cy=0 inf ok, Cy=1 and A=DSKIO error code on error

_PHYSICAL_FORMAT_STACK_SPACE: equ 12
_PHYSICAL_FORMAT_TRACKS_COUNT: equ 80

PHYSICAL_FORMAT:
    if HW_IMPL_CONFIGURE_NAK_RETRY=1

    push af
    scf
    call HW_CONFIGURE_NAK_RETRY
    pop af
    call _PHYSICAL_FORMAT
    push af
    or a
    call HW_CONFIGURE_NAK_RETRY
    pop af
    ret
_PHYSICAL_FORMAT:

    endif

    ld hl,_UFI_FORMAT_UNIT_DATA_720K_SIDE_0
    jr nc,_PHYSICAL_FORMAT_2
    ld hl,_UFI_FORMAT_UNIT_DATA_1440K_SIDE_0
_PHYSICAL_FORMAT_2:

    ld a,6
    call DO_SNSMAT
    and 1
    jr nz,_PHYSICAL_FORMAT_DO_TRACK_BY_TRACK

_PHYSICAL_FORMAT_DO_ALL_TRACKS:
    ld bc,24
    add hl,bc   ;Point to the _ALL_TRACKS command data

    ex de,hl
    ld hl,_UFI_FORMAT_UNIT_CMD
    ld bc,12
    ld a,1
    scf
    call USB_EXECUTE_CBI_WITH_RETRY

    or a
    ld a,12
    scf
    ret nz

    ld a,d  ;non-zero ASC?
    or a
    ret z

    jp ASC_TO_ERR

_PHYSICAL_FORMAT_DO_TRACK_BY_TRACK:
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

    push hl
    call _PHYSICAL_FORMAT_ONE_SIDE
    pop hl
    jr c,_PHYSICAL_FORMAT_END
    ld bc,12
    add hl,bc   ;Switch to the _SIDE_1 command
    call _PHYSICAL_FORMAT_ONE_SIDE

_PHYSICAL_FORMAT_END:
    push af
    pop hl
    ld ix,_PHYSICAL_FORMAT_STACK_SPACE
    add ix,sp
    ld sp,ix
    push hl
    pop af
    ret

    ;Format all the tracks on one side of the disk
    ;Input: IX=Command, HL=Data

_PHYSICAL_FORMAT_ONE_SIDE:
    ld b,0  ;Track number

_PHYSICAL_FORMAT_TRACK_LOOP:
    ld (ix+2),b

    push ix
    push hl
    push bc

    ex de,hl
    push ix
    pop hl
    ld bc,12
    ld a,1
    scf
    call USB_EXECUTE_CBI_WITH_RETRY

    pop bc
    pop hl
    pop ix

    or a
    ld a,12
    scf
    ret nz

    ld a,d  ;non-zero ASC?
    or a
    jr z,_PHYSICAL_FORMAT_NEXT_TRACK

    jp ASC_TO_ERR

_PHYSICAL_FORMAT_NEXT_TRACK:
    inc b
    ld a,b
    cp _PHYSICAL_FORMAT_TRACKS_COUNT
    jr c,_PHYSICAL_FORMAT_TRACK_LOOP
    ret


_UFI_FORMAT_UNIT_CMD:
    db 4, 17h, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0

_UFI_FORMAT_UNIT_DATA_720K_SIDE_0:
    db 0, 0B0h, 0, 8, 0, 0, 05h, 0A0h, 0, 0, 2, 0
_UFI_FORMAT_UNIT_DATA_720K_SIDE_1:
    db 0, 0B1h, 0, 8, 0, 0, 05h, 0A0h, 0, 0, 2, 0
_UFI_FORMAT_UNIT_DATA_720K_ALL_TRACKS:
    db 0, 0A0h, 0, 8, 0, 0, 05h, 0A0h, 0, 0, 2, 0

_UFI_FORMAT_UNIT_DATA_1440K_SIDE_0:
    db 0, 0B0h, 0, 8, 0, 0, 0Bh, 040h, 0, 0, 2, 0
_UFI_FORMAT_UNIT_DATA_1440K_SIDE_1:
    db 0, 0B1h, 0, 8, 0, 0, 0Bh, 040h, 0, 0, 2, 0
_UFI_FORMAT_UNIT_DATA_1440K_ALL_TRACKS:
    db 0, 0A0h, 0, 8, 0, 0, 0Bh, 040h, 0, 0, 2, 0    


;--- Logically format the disk
;    Input:  Cy=0 for 720K disk, 1 for 1.44M disk
;    Output: Cy=0 if ok, Cy=1 and A=DSKIO error code on error

LOGICAL_FORMAT:
    ld hl,BOOT_PARAMETERS_720K
    jr nc,_LOGICAL_FORMAT_DO
    ld hl,BOOT_PARAMETERS_1440K_DOS1
    ld a,(DOSVER)
    or a
    jr z,_LOGICAL_FORMAT_DO
    ld hl,BOOT_PARAMETERS_1440K

_LOGICAL_FORMAT_DO:

    ;>>> Step 1: write boot sector

    push hl
    call _LOGICAL_FORMAT_ZERO_SECBUF
    ld hl,BOOT_SECTOR
    ld de,(SECBUF)
    ld bc,BOOT_SECTOR_END-BOOT_SECTOR
    ldir

    ld hl,(SECBUF)
    ld bc,BOOT_DISK_PARAMETERS-BOOT_SECTOR
    add hl,bc
    ex de,hl    ;DE = Position of variable disk parameters in SECBUF
    pop hl
    push hl
    ld bc,BOOT_DISK_PARAMETERS_END-BOOT_DISK_PARAMETERS
    ldir

    ld de,0
    ld b,1
    call _LOGICAL_FORMAT_WR_SECTORS
    pop ix
    ret c

    ;>>> Step 2: write first sector of both copies of FAT

    call _LOGICAL_FORMAT_ZERO_SECBUF

    ld hl,(SECBUF)
    ld a,(ix+8) ;Media ID
    ld (hl),a
    inc hl
    ld a,0FFh
    ld (hl),a
    inc hl
    ld (hl),a   ;SECBUF contains now the initialized first FAT sector

    ld de,1
    ld b,1
    call _LOGICAL_FORMAT_WR_SECTORS  ;Write first sector of first FAT
    ret c

    ld e,(ix+9) ;Sectors per FAT
    inc e  ;DE = First sector of second FAT (skip boot sector + 1st FAT)
    ld d,0
    ld b,1
    call _LOGICAL_FORMAT_WR_SECTORS
    ret c

    ;>>> Step 3: clear the rest of the first FAT

    call _LOGICAL_FORMAT_ZERO_SECBUF

    ld b,(ix+9) ;Sectors per FAT
    dec b   ;First sector is already initialized
    ld de,2 ;Skip boot sector + 1st sector of first FAT
    call _LOGICAL_FORMAT_WR_SECTORS
    ret c

    ;>>> Step 4: clear the rest of the second FAT and the root directory

    ld b,0
    ld c,(ix+4)   ;Root directory entries
    srl c
    srl c
    srl c
    srl c   ;BC = sectors for the root directory

    ld h,0
    ld l,(ix+9) ;Sectors per FAT
    dec hl  ;First sector is already initialized
    add hl,bc
    ld b,l  ;B = How many sectors to clear (second FAT except 1st sector + root directory)

    ld d,0
    ld e,(ix+9)
    inc e
    inc e   ;DE = First sector to clear (skip 1st FAT + boot sector + 1st sector of second FAT)

    jp _LOGICAL_FORMAT_WR_SECTORS


    ;Write SECBUF repeatedly in a range of sectors
    ;Input: DE=first sector, B=how many sectors
_LOGICAL_FORMAT_WR_SECTORS:
    push ix
    push de
    push bc
    call WK_GET_LAST_REL_DRIVE
    pop bc
    pop de
    ld h,a
_LOGICAL_FORMAT_WR_SECTORS_LOOP:    
    push bc
    push de
    push hl
    ld a,h
    ld hl,(SECBUF)
    ld b,1
    scf
    call DSKIO_IMPL
    pop hl
    pop de
    pop bc
    jr c,_LOGICAL_FORMAT_WR_SECTORS_LOOP_END
    inc de
    djnz _LOGICAL_FORMAT_WR_SECTORS_LOOP
_LOGICAL_FORMAT_WR_SECTORS_LOOP_END:
    pop ix
    ret

_LOGICAL_FORMAT_ZERO_SECBUF:
    ld hl,(SECBUF)
    push hl
    pop de
    inc de
    ld (hl),0
    ld bc,512-1
    ldir
    ret

BOOT_SECTOR:
	db	0EBh,0FEh,90h,"ROOKIE  "
	db	00h,02h
BOOT_DISK_PARAMETERS:    
    db  02h,01h,00h,02h,70h,00h,0A0h,05h,0F9h,03h,00h,09h
BOOT_DISK_PARAMETERS_END:    
    db  00h,02h,00h,00h,00h,0D0h,0EDh
	db	53h,59h,0C0h,32h,0C4h,0C0h,36h,56h,23h,36h,0C0h,31h,1Fh,0F5h,11h,9Fh
	db	0C0h,0Eh,0Fh,0CDh,7Dh,0F3h,3Ch,0CAh,63h,0C0h,11h,00h,01h,0Eh,1Ah,0CDh
	db	7Dh,0F3h,21h,01h,00h,22h,0ADh,0C0h,21h,00h,3Fh,11h,9Fh,0C0h,0Eh,27h
	db	0CDh,7Dh,0F3h,0C3h,00h,01h,58h,0C0h,0CDh,00h,00h,79h,0E6h,0FEh,0FEh,02h
	db	0C2h,6Ah,0C0h,3Ah,0C4h,0C0h,0A7h,0CAh,22h,40h,11h,79h,0C0h,0Eh,09h,0CDh
	db	7Dh,0F3h,0Eh,07h,0CDh,7Dh,0F3h,18h,0B2h
	db	"Boot error",13,10
	db	"Press any key for retry",13,10,"$",0
	db	"MSXDOS  SYS"
BOOT_SECTOR_END:

;Disk parameters that are different for each disk format:
;+0: Sectors per cluster
;+4: Root directory entries
;+6,7: Sector count
;+8: Media ID
;+9: Sectors per FAT
;+11: Sectors per track

BOOT_PARAMETERS_720K:
	db	02h,01h,00h,02h,70h,00h,0A0h,05h,0F9h,03h,00h,09h

BOOT_PARAMETERS_1440K:
	db	01h,01h,00h,02h,0E0h,00h,40h,0Bh,0F8h,09h,00h,12h

BOOT_PARAMETERS_1440K_DOS1:
	db	04h,01h,00h,02h,0E0h,00h,40h,0Bh,0F8h,03h,00h,12h


    if 0

; -----------------------------------------------------------------------------
; Get information about the disk currently in the drive
;
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

    if HW_IMPL_CONFIGURE_NAK_RETRY=1

    push af
    scf
    call HW_CONFIGURE_NAK_RETRY
    pop af
    call _GET_DISK_INFO
    push af
    or a
    call HW_CONFIGURE_NAK_RETRY
    pop af
    ret
_GET_DISK_INFO:

    endif

    ld ix,-_GET_DISK_INFO_STACK_SPACE
    add ix,sp
    ld sp,ix

    push ix
    pop de
    ld hl,_UFI_READ_FORMAT_CAPACITIES_CMD
    ld bc,12
    or a
    ld a,1
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

    endif
