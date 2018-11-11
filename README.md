# Rookie Drive floppy disk controller ROM

[Rookie Drive](http://rookiedrive.com/en) is a USB host cartridge for MSX computers, powered by a CH376 USB host controller. It's designed and produced by Xavirompe.

This project implements a standard MSX-DOS 1 DiskROM that allows using standard USB floppy disk drives, thus effectively turning Rookie Drive into an "old-school" MSX floppy disk controller with a few extra perks. A few variants are offered that differ in behavior as explained below.

## Compiling

To compile this ROM you can use [Sjasm](https://github.com/Konamiman/sjasm). Adjust the configuration flags as desired in [the config.asm file](/msx/config.asm) and run:

    sjasm rookiefdd.asm rookiefdd.rom

Then burn `rookiefdd.rom` in your Rookie Drive and you're all set.

## Extra features

This ROM adds a few extra features to what a standard DiskROM offers, some of them depend on the variant used.

### Hot-plug support

Although the ROM will detect and initialize the FDD at boot time, you can also plug it later if you want and it will be usable immediately. You can even unplug the device, plug it again (or even plug a different one!) and everything will continue working.

### SHIFT key

If you keep the SHIFT key pressed while booting, this DiskROM will not be disabled, but all other MSX-DOS kernels in the system will. This is useful if you want to disable the internal floppy disk drive of your computer.

If you use one of the "exclusive" variants of the ROM, all other MSX-DOS kernels in the system will be disabled by default, but you can still prevent this from happening by keeping pressed GRAPH while booting.

### CTRL key

As any other standard MSX floppy disk controller, this ROM implements the "phantom drive" feature by allocating two drive letters for the FDD and prompting the user to change the disk and press any key when appropriate. However, if you use one of the "inverted CTRL" variants of the ROM, this behavior is inverted: you get one drive by default and two if you keep pressed CTRL at boot time (note that this won't apply to other MSX-DOS kernels, which will check CTRL by themselves).

If you plan to use this DiskROM primarily to load games, the recommended variant is "exclusive" + "inverted CTRL", as it's the one that leaves the maximum amount of free memory without having to press any key at boot.

### Quick format

Additionally to the usual full formatting, the `(CALL) FORMAT` command offers quick formatting option. This one skips the physical formatting and only initializes the boot sector, FAT and root directory of the disk.

### 1.44M disks support

MSX-DOS 2 can handle standard 1.44M disks out of the box, but MSX-DOS 1 can't. That's because the standard format for these disks uses 9 sectors for the FAT, but MSX-DOS 1 only supports 3 sectors per FAT. So when trying to read one of these disks the MSX-DOS 1 kernel will try to load the entire 4.5K FAT in the allocated 1.5K buffer and the computer will crash.

As a workaround for this, when a disk is formatted under MSX-DOS 1 it will be given a custom FAT format with 4 sectors per cluster and 3 sectors per FAT. This is a quite big cluster size and for disks with many small files it will be a waste of space, but if you really want to use 1.44M disks in MSX-DOS 1, that's the only way.

### CALL USBRESET

You can execute `CALL USBRESET` in BASIC to repeat the initialization procedure that is performed at boot time: the USB host controller hardware will be reset, then the FDD will be reset and initialized, and you will be presented the device name (or an appropriate error message).

### CALL USBERROR

Whenever a USB transaction fails for any reason, the error code is stored and executing `CALL USBERROR` in BASIC will display it (only the error for the last executed USB transaction is stored).

If the error happened at the USB physical or protocol level, you will see it as `USB error`. If what failed was the execution of an UFI command, you will see the ASC and ASCQ codes (as defined by the UFI specification). You can try it by executing `FILES` without a disk in the drive; after getting the "Disk offline" error, CALL USBERROR should present you this (3Ah is the UFI error "MEDIUM NOT PRESENT"):

    ASC:  3Ah
    ASCQ: 00h

### The panic button

Executing USB transactions involves sending a command to the USB host controller hardware and waiting for it to notify completion (or error) with an interrupt. Under normal circumstances this always happens, but if for some reason it doesn't, the computer will hang waiting forever for this interrupt.

If that happens, you can use the "panic button", which is the key combination **CAPS+ESC**. This will abort the USB transaction in progress and reset the device (you will see this process as a generic "Disk error", and then the next disk access should work).

### Alternative ports set

Rookie Drive usually uses ports 20h and 21h to communicate with the USB host controller hardware. However, the "alternative ports" variants use ports 22h and 23h instead. If you want to use two Rookie Drives simultaneously in the same computer (for example, one with the regular Nextor ROM and another one with this DiskROM), one of them must use the normal ports set and the other must use the alternative set.

## Adapting the code to different hardware

It is possible to adapt this project to work with hardware other than Rookie Drive. Such hardware should have at least 32K of mapped ROM in page 1, and of course, some kind of USB host controller.

Regarding the USB host controller, all the code that is specific to the CH376 lives in [the ch376.asm file](/msx/bank1/ch376.asm), you will need to create a new file that implements the same "public" routines but adapted to the new controller. Look at the header of that file for detailed instructions.

As for the ROM mapper implemented by your hardware, if it's DOS 2/ASCII16 you don't need to change anything else from the existing code. If it's ASCII8, set the `USE_ASCII8_ROM_MAPPER` flag in [the config.asm file](/msx/config.asm) to 1. For any other mapping mechanism you will need to manually change the code, search for usages of the `ROM_BANK_SWITCH` constant for guidance.

## Known issues

This DiskROM doesn't work on those MSX computers which have power source that is too "weak" to properly power USB floppy disk drives. This might be solved in a future version by adding support for self-powered USB hubs.

## Disclaimer!

We can't guarantee that this DiskROM will work as expected with any existing USB FDD. Unfortunately, many models violate the existing protocols and specifications in diverse and creative ways, from requiring UFI commands to be sent in a particular order when they shouldn't, to outright refusing to handle 720K disks. Six different FDD devices have been used for testing while developing this project, and in the end five of them work with the resulting DiskROM. One of these five can't handle 720K disks.

Of the tested devices, the one that seems to be working best is the **Sony MPF82E**, it even seems capable of reading single sided disks.

## Last but not least...

...if you like this project **[please consider donating!](http://www.konamiman.com/msx/msx-e.html#donate)** My kids need moar shoes!
