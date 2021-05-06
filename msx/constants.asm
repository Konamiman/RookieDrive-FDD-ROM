CGTABL: equ 0004h ;Address of font definition in BIOS ROM

VDP_DW: equ 0007h
WRTVRM: equ 004Dh
SETWRT: equ 0053h
INITXT: equ 006Ch
INIT32: equ 006Fh
CHGET:  equ 009Fh
CHPUT:  equ 00A2h
BREAKX: equ 00B7h
CLS:    equ 00C3h
POSIT:  equ 00C6h
ERAFNK: equ 00CCh
DSPFNK: equ 00CFh
KILBUF: equ 0156h

CHRGTR: equ 4666h
FRMEVL: equ 4C64h
FRMQNT: equ 542Fh
FRESTR: equ 67D0h

LINL40: equ 0F3AEh
LINL32: equ 0F3AFh
LINLEN: equ 0F3B0h
CRTCNT: equ 0F3B1h
TXTCGP: equ 0F3B7h ;Address of pattern generator table in VRAM
CLIKSW: equ 0F3DBh
CNSDFG: equ 0F3DEh
PUTPNT: equ 0F3F8h
GETPNT: equ 0F3FAh
STREND: equ 0F6C6h ;End of memory used by BASIC
;NLONLY: equ 0F87Ch
OLDKEY: equ 0FBDAh
NEWKEY: equ 0FBE5h
CAPST:  equ	0FCABh
KANAST: equ 0FCACh
;FLBMEM: equ 0FCAEh
SCRMOD: equ 0FCAFh
;VALTYP: equ 0F663h

;Keyboard matrix:
;       bit 7  bit 6   bit 5   bit 4   bit 3   bit 2   bit 1   bit 0
;row 6  F3     F2      F1      CODE    CAPS    GRAPH	CTRL   SHIFT
;row 7  RET    SELECT  BS      STOP    TAB     ESC      F5     F4
;row 8  Right  Down    Up      Left    DEL     INS      HOME   SPACE
;row 9  NUM4   NUM3    NUM2    NUM1    NUM0    NUM/     NUM+   NUM*
;row 10 NUM.   NUM,    NUM-    NUM9    NUM8    NUM7     NUM6   NUM5
