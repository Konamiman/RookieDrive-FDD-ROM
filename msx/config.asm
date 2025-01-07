; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; This is the customization options file.
; Flags are disabled when the value is 0 and enabled with any other value.
; For debugging purposes you may make temporary changes directly to this file,
; but a cleaner approach is to use the --define-symbols argument
; when running Nestor80 (see rookiefdd.asm for an example).


; -----------------------------------------------------------------------------
; Configuration constant definition macro
; -----------------------------------------------------------------------------

; This macro defines a configuration flag/value if it hasn't been defined yet,
; so the value will be the one defined here by default, but it can be overridden
; by passing a --define-symbols argument to Nestor80.

config_const: macro name,value
    ifndef name
        ifb <value>
name: defl 0
        else
name: defl value
        endif
    endif
endm


; -----------------------------------------------------------------------------
; Behavior configuration flags
; -----------------------------------------------------------------------------

;Invert the behavior of the CTRL flag, so that
;the second "ghost" drive exists only if CTRL is pressed at boot time
;(this won't apply to the internal disk drive or other MSX-DOS kernels)
config_const INVERT_CTRL_KEY

;When this flag is disabled, pressing SHIFT at boot time will disable
;all other MSX-DOS ROMs but not this one.
;When enabled, all other MSX-DOS ROMs will be disabled except if
;GRAPH is pressed at boot time.
config_const DISABLE_OTHERS_BY_DEFAULT

;Use the alternative set of Z80 ports for accessing the CH376,
;if you want to use two Rookie Drives in the same computer
;one of them must use the normal ports and the other one
;must use the alternative ports
config_const USE_ALTERNATIVE_PORTS

;Implement the "panic button":
;pressing CAPS+ESC will abort the current USB operation
;and reset the device
config_const IMPLEMENT_PANIC_BUTTON,1


; -----------------------------------------------------------------------------
; Debugging switches
; You shouldn't enable these unless you are, well, debugging
; -----------------------------------------------------------------------------

;Enable this if you are Konamiman and you are using NestorMSX with
;the almigthy Arduino board that Xavirompe sent you 
config_const USING_ARDUINO_BOARD

;Enable to debug DSKIO calls: whenever DSKIO is called, text mode is enabled,
;the input parameters are printed, and system stops waiting for a key press
config_const DEBUG_DSKIO

;Enable to wait for a key press after displaying the device information
;at boot time
config_const WAIT_KEY_ON_INIT

;Enable to simulate a fake storage device connected to a USB port
config_const USE_FAKE_STORAGE_DEVICE

;Enable this to use a disk image file simulating a real floppy disk drive.
;If this is enabled, the path of the disk image file needs to be set
;in rookiefdd.asm, right after the "if USE_ROM_AS_DISK".
;Also if this is enabled then the only supported mapper is ASCII 8.
config_const USE_ROM_AS_DISK


; -----------------------------------------------------------------------------
; ROM configuration
; -----------------------------------------------------------------------------

;The address to switch the ROM bank in the DOS2 mapper implemented.
;Set it to 6000h if the target is Rookie Drive or 5000h if the target is MSXUSB
config_const ROM_BANK_SWITCH,6000h

;Enable this if you are adapting this BIOS for hardware other than Rookie Drive
;and that hardware uses ASCII8 for ROM mapping.
;Use the default if the target is Rookie Drive or change it to
;USE_KONAMISCC_ROM_MAPPER if the target is MSXUSB.
;If you use any ROM mapper other than ASCII8 or DOS2 you will need to change
;the code, search usages of ROM_BANK_SWITCH for that.
config_const USE_ASCII8_ROM_MAPPER

;The ROM banks where all the code lives.
;You will need to change this only if you plan to somehow integrate this
;BIOS into a bigger ROM.
;Note that these refer to 16K banks, even in the case of using the ASCII8 mapper.
config_const ROM_BANK_0,0
config_const ROM_BANK_1,1

