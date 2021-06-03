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
; BYTE2ASC: Convert a byte to ASCII
; -----------------------------------------------------------------------------
; Input: 	A  = Number to convert
;           IX = Destination address for the string
; Output:   IX points after the string
; Modifies: AF, C
; -----------------------------------------------------------------------------

;--- Convert a 1-byte number to an unterminated ASCII string
;    Input:  A  = Number to convert
;            IX = Destination address for the string
;    Output: IX points after the string
;    Modifies: AF, C

BYTE2ASC:  cp  10
  jr  c,B2A_1D
  cp  100
  jr  c,B2A_2D
  cp  200
  jr  c,B2A_1XX
  jr  B2A_2XX

  ; One digit

B2A_1D:  add  "0"
  ld  (ix),a
  inc  ix
  ret

  ; Two digits

B2A_2D:  ld  c,"0"
B2A_2D2:  inc  c
  sub  10
  cp  10
  jr  nc,B2A_2D2

  ld  (ix),c
  inc  ix
  jr  B2A_1D

  ; Between 100 and 199

B2A_1XX:  ld  (ix),"1"
  sub  100
B2A_XXX:  inc  ix
  cp  10
  jr  nc,B2A_2D  ;If 1XY with X>0
  ld  (ix),"0"  ;If 10Y
  inc  ix
  jr  B2A_1D

  ;--- Between 200 and 255

B2A_2XX:  ld  (ix),"2"
  sub  200
  jr  B2A_XXX


;
; Divide 16-bit values (with 16-bit result)
; In: Divide BC by divider DE
; Out: BC = result, HL = rest
;
DIVIDE_16:
    ld hl,0
    ld a,b
    ld b,8
Div16_Loop1:
    rla
    adc hl,hl
    sbc hl,de
    jr nc,Div16_NoAdd1
    add hl,de
Div16_NoAdd1:
    djnz Div16_Loop1
    rla
    cpl
    ld b,a
    ld a,c
    ld c,b
    ld b,8
Div16_Loop2:
    rla
    adc hl,hl
    sbc hl,de
    jr nc,Div16_NoAdd2
    add hl,de
Div16_NoAdd2:
    djnz Div16_Loop2
    rla
    cpl
    ld b,c
    ld c,a
    ret


; -----------------------------------------------------------------------------
; SCANKEYS: Scan all the numeric and alphabetic keys,
;           including the numeric keyboard.
; -----------------------------------------------------------------------------
; Input: 	A = 0 for international keyboard, 1 for Russian keyboard
; Output:   Keys in HLDEB (1 bit each, set if pressed):
;           B: 76543210
;           E: FEDCBA98
;           D: NMLKJIHG
;           L: VUTSRQPO
;           H: ....ZYXW
;
;           H holds also the status of CODE/KANA, GRAPH, CTRL and SHIFT
;           on bits 7,6,5,4 respectively.
; Mofifies: AF, C
; -----------------------------------------------------------------------------

SK_ROW_0: equ 0
SK_ROW_1: equ 1
SK_ROW_2: equ 2
SK_ROW_3: equ 3
SK_ROW_4: equ 4
SK_ROW_5: equ 5
SK_ROW_6: equ 6
SK_ROW_9: equ 7
SK_ROW_10: equ 8
SK_B: equ 9
SK_E: equ 10
SK_D: equ 11
SK_L: equ 12
SK_H: equ 13

SK_SIZE: equ 14

SCANKEYS:
    push iy
    ld iy,-SK_SIZE
    add iy,sp
    ld sp,iy

    push af
    ld bc,0700h
    push iy
    pop hl
    call SK_GET_ROWS

    ld bc,0209h
    call SK_GET_ROWS

    pop af
    or a
    jr nz,SCANK_RUSSIAN
    call SK_INTERNATIONAL
    jr SCANK_DONE
SCANK_RUSSIAN:
    call SK_RUSSIAN
SCANK_DONE:

    ld b,(iy+SK_B)
    ld e,(iy+SK_E)
    ld d,(iy+SK_D)
    ld l,(iy+SK_L)
    ld h,(iy+SK_H)

    ld iy,SK_SIZE
    add iy,sp
    ld sp,iy
    pop iy
    ret


    ;* International keyboard layout version

;0: 76543210
;1: ......98
;2: BA......
;3: JIHGFEDC
;4: RQPONMLK 
;5: ZYXWVUTS
;6: .... CODE/KANA GRAPH CTRL SHIFT
;Numeric:
;9:  43210...
;10: ...98765

SK_INTERNATIONAL:

    ;* 0-7

    ld a,(iy+SK_ROW_0)    ;76543210
    ld (iy+SK_B),a

    ;* 8-F

    ld a,(iy+SK_ROW_1)
    and 00000011b
    ld b,a              ;......89

    ld a,(iy+SK_ROW_2)  ;BA......
    rrca
    rrca
    rrca
    rrca
    and 00001100b       ;....BA..
    or b
    ld b,a              ;....BA89

    ld a,(iy+SK_ROW_3)
    rlca
    rlca
    rlca
    rlca
    ld c,a              ;FEDCJIHG
    and 11110000b       ;FEDC....
    or b                ;FEDCBA89

    ld (iy+SK_E),a

    ;* G-N

    ld a,c
    and 00001111b       ;....JIHG
    ld b,a

    ld a,(iy+SK_ROW_4)
    rlca
    rlca
    rlca
    rlca
    ld c,a              ;NMLKRQPO
    and 11110000b       ;NMLK....
    or b                ;NMLKJIHG

    ld (iy+SK_D),a

    ;* O-V

    ld a,c
    and 00001111b       ;....RQPO
    ld b,a

    ld a,(iy+SK_ROW_5)
    rlca
    rlca
    rlca
    rlca
    ld c,a              ;VUTSZYXW
    and 11110000b       ;VUTS....
    or b                ;VUTSRQPO

    ld (iy+SK_L),a

    ;* W-Z 

    ld a,c
    and 00001111b       ;....ZYXW
    ld (iy+SK_H),a
    ld h,a

SK_COMMON:
    ;Input: H = (SK_H)

    ;* CAPS-GRAPH-CTRL-SHIFT

    ld a,(iy+SK_ROW_6)
    rlca
    rlca
    rlca
    rlca
    and 01110001b       ;0-GRAPH-CTRL-SHIFT-000-CODE/KANA
    bit 0,a
    jr z,SK_COMMON_2    ;CODE/KANA pressed?
    xor 10000001b       ;Set bit 7 and reset bit 0
SK_COMMON_2:
    or  h               ;CODE/KANA-GRAPH-CTRL-SHIFT-ZYXW

    ld (iy+SK_H),a

    ;* Numeric keyboard

    ld a,(iy+SK_ROW_9)     ;43210... from numeric keyboard
    rrca
    rrca
    rrca
    and 00011111b
    ld b,a                 ;...43210 from numeric keyboard

    ld a,(iy+SK_ROW_10)    ;...98765 from numeric keyboard
    rlca
    rlca
    rlca
    rlca
    rlca
    ld c,a              ;C = 765...98, we'll use it later
    and 11100000b       ;765..... from numeric keyboard
    or b                ;76543210 from numeric keyboard

    or (iy+SK_B)    ;76543210 from either the regular or the numeric keyboard
    ld (iy+SK_B),a

    ld a,c
    and 00000011b       ;......98 from numeric keyboard
    or (iy+SK_E)        
    ld (iy+SK_E),a      ;FEDCBA98, with 98 from either the regular or the numeric keyboard 

    ret


    ;* Russian keyboard layout version

;0: 654321.9
;1: V.H..087
;2: IF...B..
;3: O.RPAUWS
;4: KJZ.TXDL 
;5: QN.CMGEY
;6: .... CAPS GRAPH CTRL SHIFT
;Numeric:
;9:  43210...
;10: ...98765

SK_RUSSIAN:
    ld a,(iy+SK_ROW_0)
    ld c,a
    ld b,(iy+SK_ROW_1)
    ld e,0

    and 11111100b   ;654321..

    srl b   ;Cy = 7
    rra     ;7654321.
    srl a   ;.7654321

    srl c   ;Cy = 9
    rl e    ;E = .......9

    srl b   ;Cy = 8
    rl e    ;E = ......98

    srl b   ;Cy = 0
    rl a    ;76543210

    ld (iy+SK_B),a
    ld (iy+SK_E),e

    ;I'm sorry but that's it, only 9 disk image files supported in Russian keyboards.
    ;Pull request implementing the (hellish) conversion of the rest of the keys will be welcome.

    xor a
    ld (iy+SK_D),a
    ld (iy+SK_L),a
    ld (iy+SK_H),a

    ld h,a
    jp SK_COMMON


    ;Input:  HL = First work area address, B=Rows count, C=First row
    ;Output: HL = Last work area address used + 1
SK_GET_ROWS:
    ld a,c
    push bc
    call DO_SNSMAT
    pop bc
    cpl
    ld (hl),a
    inc hl
    inc c
    djnz SK_GET_ROWS
    ret


    ;Returns A=1 if we have a Russian keyboard, A=0 otherwise
CHECK_IS_RUSSIAN: ; in case of ZF
    DI
    CALL KILBUF
    LD HL,(CAPST)
    LD A,(CLIKSW)
    PUSH AF
    PUSH HL
    XOR A
    LD (KANAST),A   ; KANA OFF
    LD (CLIKSW),A   ; Shut up!
    DEC A
    LD (CAPST),A    ; CAPS ON
    LD (NEWKEY+6),A ; No SHIFT, CTRL etc.
    LD A,64
    LD B,7
    CALL 0D89H
    POP HL
    POP AF
    LD (CLIKSW),A
    LD (CAPST),HL
    CALL CHGET
    CP "J"
    ld a,1
    RET z
    dec a
    ret


	;--- Return in A the index of currently pressed key, 0 if none, FFh if CODE/KANA

GETCURKEY:
    xor a ;TODO: For now don't support russian keyboard
    call SCANKEYS
    bit 7,h
    ld a,0FFh
    ret nz
    ld c,b
	ld b,36
    ld a,1

    ;HLDEC = key statuses
    ;B = Keys left to check
    ;A = Current key index
    ;We do an initial rotation because we want to start at key 1.
CHGLOOP:
    sra c
    rr e
    rr d
    rr l
    rr h
    bit 0,c
    ret nz

    inc a
    djnz CHGLOOP

    xor a
    ret


; -----------------------------------------------------------------------------
; WAIT_KEY_RELEASE: Wait until none of the numeric and alphabetic keys
;                   or CODE/KANA, GRAPH, CTRL, SHIFT is pressed.
; -----------------------------------------------------------------------------

WAIT_KEY_RELEASE:
    call GETCURKEY
    or  a
    jr  nz,WAIT_KEY_RELEASE
    ret


; -----------------------------------------------------------------------------
; CAPSON and CAPSOFF: Turn the CAPS led on or off.
; -----------------------------------------------------------------------------

CAPSON:
    push af
    in  a,(0AAh)
    and 10111111b
    out (0AAh),a
    pop af
    ret

CAPSOFF:
    push af
    in a,(0AAh)
    or 01000000b
    out (0AAh),a
    pop af
    ret


; -----------------------------------------------------------------------------
; MYKILBUF: Empty the keyboard buffer (copy of BIOS routine KILBUF)
; Modifies: HL
; -----------------------------------------------------------------------------

MYKILBUF:
    ld hl,(PUTPNT)
    ld (GETPNT),hl
    ret
