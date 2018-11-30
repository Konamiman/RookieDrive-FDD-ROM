; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This is the main file. Assemble with:
; sjasm rookiefdd.asm rookiefdd.rom
;
; See config.asm for customization options


CALL_IX:   equ 7FD0h
CALL_BANK: equ CALL_IX+2

    include "config.asm"
    include "usb_errors.asm"


    ;--- ROM bank 0:
    ;    - MSX-DOS 1 kernel
    ;    - Entry points for MSX-DOS driver functions located in bank 1
    ;    - CALL commands
    ;    - Choice string for FORMAT
    ;    - Default DPB for use by the kernel

    org 4000h

    include "bank0/kernel.asm"
    include "bank0/driver_entry_points.asm"
    include "bank0/choice_strings.asm"
    include "bank0/oemstat.asm"
DEFDPB:
    include "defdpb.asm"    

    ds CALL_IX-$,0FFh
    include "callbnk.asm"

    ds 7FFFh-$,0FFh
    db ROM_BANK_0


    ;--- ROM bank 1: 
    ;    - Initialization routine, executed at boot and by CALL USBRESET
    ;    - MSX-DOS driver function implementations
    ;    - All the USB+CBI related code
    ;    - Default DPB for use by the driver

    ; Note: USB host hardware dependant code needs to be placed before usb.asm 
    ; because of the HW_IMPL_* constants.

    org 4000h

    include "bank1/header.asm"
    include "bank1/ch376.asm" ;USB host hardware dependant code
    include "bank1/inihrd_inienv.asm"
    include "bank1/verbose_reset.asm"
    include "bank1/dskio_dskchg.asm"
    include "bank1/choice_dskfmt.asm"    
    include "bank1/work_area.asm"
    include "bank1/usb.asm"
    include "bank1/misc.asm"
DEFDPB_1:
    include "defdpb.asm"

    ds CALL_IX-$,0FFh
    include "callbnk.asm"

    ds 7FFFh-$,0FFh
    db ROM_BANK_1

