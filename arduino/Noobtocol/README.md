# Noobtocol

This project implements "the Noobtocol", a very simple protocol for an Arduino board containing a CH376. It simply waits for "Read port/Write port" commands in the serial port and executes them, reading and writing bytes from/to the serial port and the CH376 as appropriate. See [the source file itself](/blob/master/arduino/Noobtocol/Noobtocol.ino) for more details.