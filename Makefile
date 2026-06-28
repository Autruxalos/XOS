# Makefile - Generación de imagen multi-arquitectura por sectores estructurados
all: xos.img

xos.img: xboot.bin xkernel.bin xsh16.bin xsh32.bin xsh64.bin
	# Sector 0: El cargador de arranque (512 bytes)
	dd if=xboot.bin os=xos.img bs=512 count=1
	
	# Sector 1 al 10: El Kernel (Ajusta según el tamaño de tu kernel)
	dd if=xkernel.bin of=xos.img bs=512 seek=1
	
	# Sector 11: Shell de 16 bits (8086)
	dd if=xsh16.bin of=xos.img bs=512 seek=11
	
	# Sector 21: Shell de 32 bits (i386)
	dd if=xsh32.bin of=xos.img bs=512 seek=21
	
	# Sector 31: Shell de 64 bits (x86_64) - ¡Aquí saltará tu kernel actual!
	dd if=xsh64.bin of=xos.img bs=512 seek=31

xboot.bin: src/boot/xboot.asm
	nasm -f bin src/boot/xboot.asm -o xboot.bin

xkernel.bin: src/kernel/xkernel.asm
	nasm -f bin src/kernel/xkernel.asm -o xkernel.bin

xsh16.bin: src/apps/xsh16.asm
	nasm -f bin src/apps/xsh16.asm -o xsh16.bin

xsh32.bin: src/apps/xsh32.asm
	nasm -f bin src/apps/xsh32.asm -o xsh32.bin

xsh64.bin: src/apps/xsh64.asm
	nasm -f bin src/apps/xsh64.asm -o xsh64.bin

clean:
	rm -f *.bin *.img
