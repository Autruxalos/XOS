# =============================================================================
# Makefile Unificado XOS - Soporte 16/32/64 bits + EXFS
# =============================================================================

NASM = nasm
NASM_FLAGS = -f bin -w+all

BUILD_DIR = build
IMAGE = $(BUILD_DIR)/XOS.img

# Archivos principales
XBOOT_SRC = src/boot/xboot.asm
XKERNEL_SRC = src/kernel/xkernel.asm
EXFS_INIT = src/tools/init_exfs.asm   # Inicializador

all: image

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compilación
$(BUILD_DIR)/xboot.bin: $(XBOOT_SRC) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BUILD_DIR)/xkernel.bin: $(XKERNEL_SRC) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

# Inicializador EXFS
$(BUILD_DIR)/init_exfs.bin: $(EXFS_INIT) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

# Crear imagen + instalar EXFS
image: $(BUILD_DIR)/xboot.bin $(BUILD_DIR)/xkernel.bin $(BUILD_DIR)/init_exfs.bin
	@echo "[IMG] Creando XOS.img con EXFS..."
	dd if=/dev/zero of=$(IMAGE) bs=512 count=65536 status=none
	dd if=$(BUILD_DIR)/xboot.bin of=$(IMAGE) conv=notrunc status=none
	dd if=$(BUILD_DIR)/xkernel.bin of=$(IMAGE) seek=1 conv=notrunc status=none
	dd if=$(BUILD_DIR)/init_exfs.bin of=$(IMAGE) seek=67 conv=notrunc status=none
	@echo "====== XOS COMPILADO CON EXFS INICIALIZADO ======"

run: image
	qemu-system-i386 -drive format=raw,file=$(IMAGE),if=floppy -m 32M -cpu 486 -boot a

run64: image
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE) -m 64M -cpu qemu64

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all image run clean
