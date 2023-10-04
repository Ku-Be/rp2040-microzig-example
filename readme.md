Trying to create a ram-only binary for raspberry pi pico rp2040 with microzig.
ram-dis.txt and flash-dis.txt were created with "arm-none-eabi-objdump -D -M force-thumb morse-pico.elf > flash-dis.txt".
Flash/Ram mode can be changed in build.zig.
The program runs as expected from flash, but nothing happens when loading the ram binary via uf2.
