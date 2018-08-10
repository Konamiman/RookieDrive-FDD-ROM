; MSX-DOS 1 kernel with FDD driver for Rookie Drive
; By Konamiman, 2018
;
; Kernel and base driver code taken from the dsk2rom project by joyrex2001:
; https://github.com/joyrex2001/dsk2rom
;
; Assemble with:
; sjasm rookiefdd.asm rookiefdd.rom

    include "kernel.asm"
    include "driver.asm"
    include "inihrd.asm"
    include "dskio.asm"
    include "dskchg.asm"

HOSTILE_TAKEOVER:	db   1	  ; 0 = no, 1 = make this an exclusive diskrom

    DEFS	08000H-$,0
