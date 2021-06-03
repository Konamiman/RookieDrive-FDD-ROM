# Rookie Drive floppy disk controller ROM - disk image mode

When a USB storage device is connected to the USB port of the Rookie Drive the ROM will switch to disk image mode. In this mode you are able to mount disk image files and work with them as if they were regular floppy disks: when you "mount" a disk image file, accessing the drive associated to the ROM will actually read or write the mounted file.

Note that the storage device must hold a FAT12, FAT16 or FAT32 filesystem. Also, long filenames are not supported so all file and directory names will be handled as 8.3 names.


## The main directory

First of all you need to know that the ROM will create some small files in the storage device for the purpose of storing configuration. These files will be stored inside a directory named `_USB` which is itself inside what the ROM considers the _main directory_ of the storage device. This main directory is a directory named `MSX` in the root directory of the storage if that directory exists; otherwise the main directory is just the root directory itself.

If you plan to use a storage device exclusively with your MSX you may not want to create a `MSX` directory, otherwise creating it and putting all your disk image files (and ROM configuration) there is a clean way to have everything in one single place. If you decide to use a `MSX` directory, make sure to create it before you first plug the device in your Rookie Drive! (othersiwe you'll need to manually delete or move the `_USB` directory that the ROM will have created).


## The boot menu

When your computer boots with a storage device plugged in, and unless configured otherwise, the ROM will present a "graphical" user interface (40 column text mode actually) with a list of the files and directories found in the _boot directory_ (the boot directory is the main directory unless configured otherwise). At this point you can press F1 to get help on the keys you can use to navigate the menu, but the basic ones are:

- Use the cursor keys to select one file or directory.
- Press `Enter` when a directory is selected to enter it, press `BS` to go back to the parent directory.
- Press `Enter` when a file is selected to mount it and exit the menu (and then continue the computer boot process).
- Press `ESC` to exit the menu (and then continue the computer boot process) without mounting any file.

Hidden files and directories, and those whose name starts with an underscore "`_`" character, won't be listed.

The boot menu can also be invoked by executing `CALL USBMENU` from BASIC.


## The default file

Each directory that is not empty has a _default file_. This is the file that will be mounted when you press `Shift+Enter` while the directory is selected in the boot menu, when you run the `CALL USBMOUNT(0)` command from BASIC, and when booting the computer in boot mode 3.

The default file for a given directory is determined as follows:

* It's the file whose name is stored in a `_USB/DEFFILE` file in the directory; or if that file doesn't exist...
* It's a file named `DEFAULT.DSK` in the directory; or if that file doesn't exist...
* It's the first file found in the directory.

The default file for any directory can be set from the configuration menu.


## The boot mode

The ROM supports four boot modes, that is, four different behaviors when the computer boots and a USB storage device is detected:

1. Change to the boot directory and show the boot menu.
2. Change to the boot directory but don't show the boot menu and don't mount any file.
3. Change to the boot directory and mount the default file in that directory.
4. Mount the last file that has been mounted.

The boot mode can be set from the configuration menu, being 1 the default mode when nothing has been configured. When booting in boot mode 4, if the file that was mounted the last time no longer exists then the ROM will revert to boot mode 3.

Pressing the `TAB` key while booting will force the boot mode 1 temporarily, this is useful in boot modes 3 and 4 as an alternative to unplugging the device if you don't want the corresponding file to be mounted at boot time.


### Temporary boot mode 4

When mounting a file from the boot menu with `Ctrl+Enter` or from BASIC with the `CALL USBMOUNTR` command, the computer will be reset and the ROM will boot in "temporary boot mode 4". This means that the file that had been selected will be mounted at boot but only once, and in the next computer reset the configured boot mode will be restored. This is achieved by creating a temporary configuration file that is read and then deleted at boot time.

By the way `Ctrl+Enter` works for directories too, in this case what will be mounted is the default file of the directory.


## The configuration menu

Pressing F2 while in the boot menu will open the configuration directory, from here you can:

* Set the boot mode.
* Set the boot directory (as the current directory).
* Set the default file for the current directory (as the file currently selected).
* Enable or disable the CAPS led litting when disk access is performed while a file is mounted.

All of these settings are stored in configuration files and thus they are permanent (they remain after computer resets and poweroffs).


## Hot swap of disk images

The mounted disk image can be changed via the boot menu and the `CALL USBMOUNT` command, but often you'll want a more dynamic mechanism, especially when playing multidisk games. The _hot swap_ mechanism allows to quickly mount a different disk image file from the same directory at the exact moment in which disk access is about to be performed.

That's how it works: when the ROM is about to perform disk access (for example after a game says "change disk and press any key"), press the key corresponding to the numbers 1-9 or the letters A-Z, then the Nth disk image file found in the current directory (the directory of the currently mounted file) will be mounted right before the actual disk access happens. For example, press "1" to mount the first file, or "A" to mount the 10th file. Using this mechanism you can change between 35 different disk image files.

Alternatively, you can press the `Code/Kana` key instead. Then the CAPS led will lit and the ROM will wait for you to press the appropriate 1-9 or A-Z key; or you can just press `Code/Kana` again if you change your mind.

The files taken in account when using this mechanism are the same ones that are listed in the boot menu, this means that hidden files and files whose name starts with an underscore "`_`" character won't be counted.


## CALL commands reference

There are a few `CALL` commands that allow you to control directories and disk images from BASIC. You'll get a quick summary if you execute `CALL USBHELP`, but here's the complete reference.


### CALL USBMENU

Shows the boot menu as when it's displayed during the boot process (the only difference is that when pressing `Esc` it'll go back to BASIC instead of continuing the boot process).


### CALL USBCD

Use this command to handle directories in the USB device. It supports these variants:

* **CALL USBCD** - Simply print the current directory.
* **CALL USBCD("dir/dir")** - Change to the specified directory, relative to the current one.
* **CALL USBCD("/dir/dir")** - Change to the specified absolute directory. Note that the difference is an extra slash at the beginning of the specified directory chain.

Changing the current directory will unmount the currently mounted file, this is due to a limitation on how the underlying USB controller hardware works.

Note that an alternative way to change the current directory (without mounting any file) is to go to the boot menu, enter the desired directory, and then pressing `Shift+Esc` (`Esc` alone will restore the previous directory and mounted file).


### CALL USBFILES

Use this command to list the disk images files and directories in the current directory, in a similar format as the DiskBASIC `FILES` command (but you can't specify wildcards, all the files will be listed).


### CALL USBMOUNT

Use this command to mount disk image files. It supports these variants:

* **CALL USBMOUNT** - Simply print the name of the currently mounted file.
* **CALL USBMOUNT("file.ext")** - Mount the specified file in the current directory. If you want to mount a file in a different directory, change to that directory first using `CALL USBCD`.
* **CALL USBMOUNT(-1)** - Unmount the currently mounted file.
* **CALL USBMOUNT(0)** - Mount the default file in the current directory.
* **CALL USBMOUNT(n)** - Mount the Nth file in the current directory (with "n" between 1 and 255). Hidden files and files whose name starts with an underscore "`_`" character don't count.


### CALL USBMOUNTR

This command works the same way as `CALL USBMOUNT(...)`, but after a successful file mount the computer will be reset and the ROM will boot in mode 4 temporarily.


## Configuration files reference

The configuration set via the configuration menu is stored in a set of files within the `_USB` directory in the main directory. Occasionally you may want to manipulate these files manually using another computer, so here's a reference of what these files are named and what are their contents.

* **BOOTMODE**: This file contains one single ASCII character with the current boot mode, "1" to "4". If the file doesn't exist the default boot mode is 1.
* **BOOTDIR**: Contains the full path of the boot directory, using a slash "`/`" as directory separator, with no slashes at either end; for example "`MSX/GAMES`". If the file doesn't exist then the boot directory is the main directory.
* **CURDIR**: Contains the full path of the current directory, with the same format as `BOOTDIR`. If the file doesn't exist then the current directory is the main directory.
* **CURFILE**: Contains the name of the file currently mounted. The file doesn't exist when no file is mounted.
* **NOCAPS**: When this file exists and is not empty then the CAPS lit on disk access when a file is mounted is disabled.
* **TMP4**: If this file exists and is not empty then at the next computer boot the ROM will delete it and then it will boot in mode 4.
* **DEFFILE**: Contains the name of the default file for the directory. This file is special in that it can exist not only in the `_USB` directory of the main directory, but also in the `_USB` directory of any other directory.

File and directory names must be stored in uppercase and in 8.3 format.

The `CURDIR` and `CURFILE` files are the ones that the ROM reads in order to determine which file is to be mounted when booting in mode 4.

The ROM will treat CR (ASCII 13) and LF (ASCII 10) characters found in configuration files as an end of file mark, keep this in mind if you manipulate these files by hand.


## Other features

A disk image file will be mounted as read-only if it has the read-only attribute set.


## Limitations

The ROM doesn't currently provide any way to create, delete, rename, move, change attributes, or otherwise manipulate the directories and disk image files on the storage device from within the MSX itself; you'll have to do that from another USB-capable computer (you can, of course, write to mounted disk image files using the regular MSX-DOS/DiskBASIC functions). These missing bits might be added in a future version of the ROM.

The files and directories are always listed (in the boot menu and with `CALL USBFILES`) in the order in which their directory entries are physically located in the device, if you want to see them in alphabetical order you'll have to use a tool to permanently reorder them from within another computer.
