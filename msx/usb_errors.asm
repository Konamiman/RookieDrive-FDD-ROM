; Rookie Drive USB FDD BIOS
; By Konamiman, 2018
;
; USB error codes, these are the ones returned by the
; USB routines that are documented as "Output: USB Error code"


USB_ERR_OK: equ 0
USB_ERR_NAK: equ 1
USB_ERR_STALL: equ 2
USB_ERR_TIMEOUT: equ 3
USB_ERR_DATA_ERROR: equ 4
USB_ERR_NO_DEVICE: equ 5
USB_ERR_PANIC_BUTTON_PRESSED: equ 6
USB_ERR_UNEXPECTED_STATUS_FROM_HOST: equ 7

USB_ERR_MAX: equ 7

USB_FILERR_MIN: equ 41h

USB_ERR_OPEN_DIR: equ 41h
USB_ERR_MISS_FILE: equ 42h

USB_FILERR_MAX: equ 0B4h
