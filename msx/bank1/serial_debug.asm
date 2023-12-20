DEBUG_SEND_INIT_MSG:
    ld hl,DEBUG_INIT_MSG
    call sendstring
    ret

DEBUG_INIT_MSG:
    db "RookieDrive ROM initialized!",13,10,0


;------------------

DEBUG_ON_DSKIO:
    ; Input: 	A	Drivenumber
    ;		F	Cx reset for read
    ;			Cx set for write
    ; 		B	number of sectors
    ; 		C	Media descriptor
    ;		DE	logical sectornumber
    ; 		HL	transferaddress

    push af
    push bc
    push hl
    push de

    ld hl,DSKIO_MSG_1
    call sendstring

    ld hl,DSKIO_MSG_WRITE
    jr c,DEBUG_ON_DSKIO_2
    ld hl,DSKIO_MSG_READ
DEBUG_ON_DSKIO_2
    call sendstring

    ld a,b
    call sendhex

    ld hl,DSKIO_MSG_SECTORS
    call sendstring

    pop de  ;sector
    push de
    ld a,d
    call sendhex
    ld a,e
    call sendhex

    ld hl,DSKIO_MSG_ADDR
    call sendstring

    pop de
    pop hl  ;address
    push hl
    push de

    ld a,h
    call sendhex
    ld a,l
    call sendhex

    ld hl,DSKIO_MSG_LAST
    call sendstring

    pop de
    pop hl
    pop bc
    pop af

    ret


DSKIO_MSG_1: db "DSKIO! ",0
DSKIO_MSG_READ: db "Read ",0
DSKIO_MSG_WRITE: db "Write ",0
DSKIO_MSG_SECTORS: db " sectors, "
DSKIO_MSG_SECNUM: db "sec = ",0
DSKIO_MSG_ADDR: db "h, addr = ",0
DSKIO_MSG_LAST: db "h"
DSKIO_MSG_CRLF_END: db 13,10,0

;------------------

SEND_DSKIO_FD_START:
    push hl
    ld hl,DSKIO_FD_START_MSG
    call sendstring
    pop hl
    ret

DSKIO_FD_START_MSG: db "  DSKIO FD start",13,10,0

;------------------

SEND_DSKIO_FD_END:
    push hl
    ld hl,DSKIO_FD_END_MSG
    call sendstring
    pop hl
    ret

DSKIO_FD_END_MSG: db "  DSKIO FD end",13,10,0


SEND_DSKIO_DT:
    push hl
    ld hl,DSKIO_DT_MSG
    call sendstring
    pop hl

    ret

DSKIO_DT_MSG: db "  DSKIO direct transfer",13,10,0


SEND_DSKIO_1BY1:
    push af
    push hl

    ld hl,DSKIO_1BY1_MSG
    call sendstring

    ld a,d
    call sendhex
    ld a,e
    call sendhex

    ld hl,DSKIO_MSG_LAST
    call sendstring

    pop hl
    pop af

    ret

DSKIO_1BY1_MSG: db "  DSKIO transfer one by one, sec =",0

;-----------------------

SEND_DSKIO_DO_SECTOR_TX_START:
    push af
    push hl

    ld hl,DSKIO_DO_SECTOR_TX_START_MSG
    call sendstring

    pop hl
    pop af

    ret

DSKIO_DO_SECTOR_TX_START_MSG: db "    DSKIO TX sector start",13,10,0

SEND_DSKIO_DO_SECTOR_TX_END:
    push af
    push hl

    ld hl,DSKIO_DO_SECTOR_TX_END_MSG
    call sendstring

    pop hl
    pop af

    ret

DSKIO_DO_SECTOR_TX_END_MSG: db "    DSKIO TX sector end",13,10,0


;---------------

SEND_DSKIO_DO_SECTOR_TX_RESULT:
    push af
    push de
    push hl

    push af
    ld hl,DSKIO_TX_RESULT_MSG
    call sendstring
    pop af

    call sendhex

    ld a,","
    call sendchar
    ld a,d
    call sendhex
    ld a,e
    call sendhex

    ld hl,DSKIO_MSG_CRLF_END
    call sendstring

    pop hl
    pop de
    pop af

    ret

DSKIO_TX_RESULT_MSG: db "      Result: ",0



;--------------------

SEND_DSKIO_EXECUTING_CBI:
    push af
    push hl
    
    ld hl,DSKIO_EXE_CBI_MSG
    call sendstring

    ld a,d
    call sendhex
    ld a,e
    call sendhex

    ld hl,DSKIO_EXE_CBI_LEN_MSG
    call sendstring

    ld a,b
    call sendhex
    ld a,c
    call sendhex

    ld a," "
    call sendchar

    pop af
    push af
    ld a,"W"
    jr c,kkx
    ld a,"R"
kkx:
    call sendchar

    ld hl,DSKIO_MSG_CRLF_END
    call sendstring

    pop hl
    pop af
    ret


DSKIO_EXE_CBI_MSG: db "    Executing CBI, addr = ",0
DSKIO_EXE_CBI_LEN_MSG db "h, len = ",0

;------------------

SEND_DSKIO_CBI_CORE_RESULT:
    push af
    push hl

    ld hl,DSKIO_CBI_CORE_RESULT_MSG
    call sendstring

    pop af
    push af
    call sendhex

    ld a,","
    call sendchar

    ld a,b
    call sendhex
    ld a,c
    call sendhex

    ld a,","
    call sendchar

    ld a,d
    call sendhex
    ld a,e
    call sendhex

    ld hl,DSKIO_MSG_CRLF_END
    call sendstring

    pop hl
    pop af
    ret

DSKIO_CBI_CORE_RESULT_MSG: db "    CBI core result: ",0

;----------------------

SEND_DSKIO_CTRL_TRANSFER_RESULT:
    push hl
    push af
    
    ld a,"!"
    call sendchar
    ld a," "
    call sendchar

    pop af
    push af
    call sendhex

    ld hl,DSKIO_MSG_CRLF_END
    call sendstring

    pop af
    pop hl
    ret


;---------------------

SEND_DSKIO_OUT_TRANSFER_RESULT:
    push hl
    push af
    
    ld a,"!"
    call sendchar
    ld a,"!"
    call sendchar
    ld a," "
    call sendchar

    pop af
    push af
    call sendhex

    ld hl,DSKIO_MSG_CRLF_END
    call sendstring

    pop af
    pop hl
    ret

