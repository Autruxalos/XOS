# =============================================================================
# MAKEFILE OPTIMIZADO PARA XOS64
# =============================================================================

ASM = nasm
ASM_FLAGS = -f bin -w+all

BUILD_DIR = build
XBOOT_SRC = src/boot/xboot.asm
XKERNEL_SRC = src/kernel/xkernel.asm

IMAGE = $(BUILD_DIR)/XOS.img

all: image

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Compilar el cargador de arranque MBR (Sector 1)
$(BUILD_DIR)/xboot.bin: $(XBOOT_SRC) | $(BUILD_DIR)
	@echo "[NASM] Compilando XBOOT..."
	$(ASM) $(ASM_FLAGS) $(XBOOT_SRC) -o $(BUILD_DIR)/xboot.bin

# Compilar el Kernel Monolítico (Inyecta internamente exit.asm y xsh.asm)
$(BUILD_DIR)/xkernel.bin: $(XKERNEL_SRC) | $(BUILD_DIR)
	@echo "[NASM] Compilando XKERNEL..."
	$(ASM) $(ASM_FLAGS) $(XKERNEL_SRC) -o $(BUILD_DIR)/xkernel.bin

# Construir la imagen de disco cruda unificada
image: $(BUILD_DIR)/xboot.bin $($(BUILD_DIR)/xkernel.bin) | $(BUILD_DIR)
	@echo "[IMG] Generando almacenamiento master XOS.img..."
	# Crear disco vacío de 10 Megabytes relleno de ceros
	dd if=/dev/zero bs=512 count=20480 of=$(IMAGE) status=none
	# Escribir XBOOT en el sector de arranque 0 (Firma 0xAA55)
	dd if=$(BUILD_DIR)/xboot.bin of=$(IMAGE) conv=notrunc status=none
	# Inyectar XKERNEL inmediatamente en el sector 2 (LBA 1)
	dd if=$(BUILD_DIR)/xkernel.bin of=$(IMAGE) seek=1 conv=notrunc status=none
	@echo "====== ¡SISTEMA XOS LISTO PARA DESPEGAR! ======"

run: image
	@echo "[QEMU] Iniciando entorno controlado x86_64..."
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE)

clean:
	@echo "[CLEAN] Removiendo archivos temporales de construcción..."
	rm -rf $(BUILD_DIR)
