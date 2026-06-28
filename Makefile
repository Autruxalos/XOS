# =============================================================================
# MAKEFILE UNIFICADO - DISTRIBUCIÓN DE ALMACENAMIENTO DE XOS
# =============================================================================

BOOT_ASM    = src/boot/xboot.asm
KERNEL_ASM  = src/kernel/xkernel.asm
XSH16_ASM   = src/apps/xsh16.asm
XSH32_ASM   = src/apps/xsh32.asm
XSH64_ASM   = src/apps/xsh64.asm

BOOT_BIN    = xboot.bin
KERNEL_BIN  = xkernel.bin
XSH16_BIN   = xsh16.bin
XSH32_BIN   = xsh32.bin
XSH64_BIN   = xsh64.bin

IMAGE_OUT   = xos.img
ASM         = nasm
FLAGS       = -f bin

.PHONY: all clean run

all: $(IMAGE_OUT)

$(IMAGE_OUT): $(BOOT_BIN) $(KERNEL_BIN) $(XSH16_BIN) $(XSH32_BIN) $(XSH64_BIN)
	@echo "--- Creando topología física del disco libre de colisiones ---"
	# Sector 0: Gestor de arranque (512 bytes fijos)
	dd if=$(BOOT_BIN) of=$(IMAGE_OUT) bs=512 count=1 conv=notrunc
	
	# Sector 1: Kernel base multi-modo (Margen de 99 sectores libres)
	dd if=$(KERNEL_BIN) of=$(IMAGE_OUT) bs=512 seek=1 conv=notrunc
	
	# Sector 100: Código de aplicación interactiva para 16-bits
	dd if=$(XSH16_BIN) of=$(IMAGE_OUT) bs=512 seek=100 conv=notrunc
	
	# Sector 120: Código de aplicación interactiva para 32-bits
	dd if=$(XSH32_BIN) of=$(IMAGE_OUT) bs=512 seek=120 conv=notrunc
	
	# Sector 140: Código de aplicación interactiva para 64-bits
	dd if=$(XSH64_BIN) of=$(IMAGE_OUT) bs=512 seek=140 conv=notrunc
	@echo "--- Finalizado: Imagen $(IMAGE_OUT) lista para pruebas ---"

%.bin: src/boot/%.asm
	$(ASM) $(FLAGS) $< -o $@

$(BOOT_BIN): $(BOOT_ASM)
	$(ASM) $(FLAGS) $(BOOT_ASM) -o $(BOOT_BIN)

$(KERNEL_BIN): $(KERNEL_ASM)
	$(ASM) $(FLAGS) $(KERNEL_ASM) -o $(KERNEL_BIN)

$(XSH16_BIN): $(XSH16_ASM)
	$(ASM) $(FLAGS) $(XSH16_ASM) -o $(XSH16_BIN)

$(XSH32_BIN): $(XSH32_ASM)
	$(ASM) $(FLAGS) $(XSH32_ASM) -o $(XSH32_BIN)

$(XSH64_BIN): $(XSH64_ASM)
	$(ASM) $(FLAGS) $(XSH64_ASM) -o $(XSH64_BIN)

clean:
	rm -f *.bin *.img

run: $(IMAGE_OUT)
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE_OUT)
