ca65 --cpu 65c02 -t none -I"%cd%" -o bios.o bios.S
ld65 -C target.cfg -o bios.bin bios.o