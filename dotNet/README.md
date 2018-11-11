# .NET support project

This is a C# solution that contains some support/experimental code for the project, it's not very clean and not documented at all - but feel free to take a look if you want. It consists of three projects:

* `Usb`: A DLL that contains classes to manage the USB protocol and the CBI+UFI combo, in the same way that the DiskROM does. It's referenced by the other two projects.
* `Sandbox`: A console application that initializes the device, prints information about it, and then executes various UFI commands depending on the key pressed.
* `NestorMsxPlugins`: It contains two plugins for [NestorMSX](https://github.com/Konamiman/NestorMSX): _RookieDriveFDD_ implements a "full" DiskROM by patching the driver calls and invoking the code in the `Usb` library as a proof of concept (incomplete, eventually it was abandoned); and _RookieDrivePorts_ that simply redirects the inputs and outputs of the Z80 ports used by Rookie Drive to an Arduino board that runs [the Noobtocol](/arduino/Noobtocol).
