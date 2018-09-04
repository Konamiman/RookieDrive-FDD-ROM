; MSX-DOS 1 kernel with FDD driver for Rookie Drive
; By Konamiman, 2018
;
; Kernel and base driver code taken from the dsk2rom project by joyrex2001:
; https://github.com/joyrex2001/dsk2rom
;
; Assemble with:
; sjasm rookiefdd.asm rookiefdd.rom

    include "const.asm"

    include "kernel.asm"

    include "driver.asm"
    include "inihrd_inienv.asm"
    include "dskio_dskchg.asm"
    include "choice_dskfmt.asm"
    include "work_area.asm"

    ;USB host controller hardware dependant code.
    ;This needs to be placed before usb.asm 
    ;because of the HW_IMPL_* constants.

    include "ch376.asm"

    include "usb.asm"

HOSTILE_TAKEOVER:	db   0	  ; 0 = no, 1 = make this an exclusive diskrom

    DEFS	08000H-$,0
