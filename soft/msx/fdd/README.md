# Floppy disk driver controller ROM

This code will generate a MSX-DOS 1 kernel ROM with a device driver capable of controlling a USB floppy disk drive (CBI+UFI compliant). For now it can only read disks (can't write on them) and doesn't implement the FORMAT command. Also, hubs are not supported yet.

The main code file is `rookiefdd.asm`, all others are included from this one. Use [sjasm](https://github.com/Konamiman/sjasm) to assemble it: `sjasm rookiefdd.asm rookiefdd.rom`.

Device hot plug is supported: at any time after boot you can disconnect the USB floopy disk drive, connect it again (or connecte a different one!) and everything will continue working.

The ROM implements a `CALL USBRESET` command that repeats all the initialization process, including the display of the informative message.
