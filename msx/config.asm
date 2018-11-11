; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This is the customization options file.
; Flags are enabled with value 1 or disabled with value 0.


; -----------------------------------------------------------------------------
; Behavior configuration flags
; -----------------------------------------------------------------------------

;Invert the behavior of the CTRL flag, so that
;the second "ghost" drive exists only if CTRL is pressed at boot time
;(this won't apply to the internal disk drive or other MSX-DOS kernels)
INVERT_CTRL_KEY: equ 0

;When this flag is disabled, pressing SHIFT at boot time will disable
;all other MSX-DOS ROMs but not this one.
;When enabled, all other MSX-DOS ROMs will be disabled except if
;GRAPH is pressed at boot time.
DISABLE_OTHERS_BY_DEFAULT: equ 0

;Implement the "panic button":
;pressing CAPS+ESC will abort the current USB operation
;and reset the device
IMPLEMENT_PANIC_BUTTON: equ 1

;Use the alternative set of Z80 ports for accessing the CH376,
;if you want to use two Rookie Drives in the same computer
;one of them must use the normal ports and the other one
;must use the alternative ports
USE_ALTERNATIVE_PORTS: equ 0


; -----------------------------------------------------------------------------
; Debugging switches
; You shouldn't enable these unless you are, well, debugging
; -----------------------------------------------------------------------------

;Enable this if you are Konamiman and you are using NestorMSX with
;the almigthy Arduino board that Xavirompe sent you 
USING_ARDUINO_BOARD: equ 0

;Enable to debug DSKIO calls: whenever DSKIO is called, text mode is enabled,
;the input parameters are printed, and system stops waiting for a key press
DEBUG_DSKIO: equ 0

;Enable to wait for a key press after displaying the device information
;at boot time
WAIT_KEY_ON_INIT: equ 0


; -----------------------------------------------------------------------------
; ROM configuration
; -----------------------------------------------------------------------------

;The address to switch the ROM bank in the DOS2 mapper implemented by Rookie Drive
ROM_BANK_SWITCH: equ 6000h

;Enable this if you are adapting this BIOS for hardware other than Rookie Drive
;and that hardware uses ASCII8 for ROM mapping.
;If you use any ROM mapper other than ASCII8 or DOS2 you will need to change
;the code, search usages of ROM_BANK_SWITCH for that.
USE_ASCII8_ROM_MAPPER: equ 0

;The ROM banks where all the code lives.
;You will need to change this only if you plan to somehow integrate this
;BIOS into a bigger ROM.
;Note that these refer to 16K banks, even in the case of using the ASCII8 mapper.
ROM_BANK_0: equ 0
ROM_BANK_1: equ 1



