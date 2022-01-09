all: 
	nasm src/x86_64/boot/bootloader.S -f bin -o bootloader.bin
	sudo dd if=bootloader.bin of=/dev/sdb
	rm *.bin

run:
	sudo qemu-system-x86_64 -hda /dev/sdb -monitor stdio
