# =============================================================================
# Makefile Unificado XOS
# =============================================================================

NASM = nasm
NASM_FLAGS = -f bin -w+all

BUILD_DIR = build
IMAGE = $(BUILD_DIR)/XOS.img

XBOOT_SRC = src/boot/xboot.asm
XKERNEL_SRC = src/kernel/xkernel.asm
EXFS_INIT_SRC = src/tools/init-exfs.asm

all: image

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/xboot.bin: $(XBOOT_SRC) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BUILD_DIR)/xkernel.bin: $(XKERNEL_SRC) | $(BUILD_DIR)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BUILD_DIR)/init-exfs.bin: $(EXFS_INIT_SRC) | $(BUILD_DIR)
	@echo "[NASM] Compilando init-exfs..."
	$(NASM) $(NASM_FLAGS) $< -o $@

image: $(BUILD_DIR)/xboot.bin $(BUILD_DIR)/xkernel.bin $(BUILD_DIR)/init-exfs.bin
	@echo "[IMG] Creando imagen..."
	dd if=/dev/zero of=$(IMAGE) bs=512 count=131072 status=none
	dd if=$(BUILD_DIR)/xboot.bin of=$(IMAGE) conv=notrunc status=none
	dd if=$(BUILD_DIR)/xkernel.bin of=$(IMAGE) seek=1 conv=notrunc status=none
	dd if=$(BUILD_DIR)/init-exfs.bin of=$(IMAGE) seek=67 conv=notrunc status=none
	@echo "====== XOS COMPILADO ======"

run: image
	qemu-system-i386 -drive format=raw,file=$(IMAGE) -m 32M -cpu 486 -boot c

run64: image
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE) -m 64M -cpu qemu64

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all image run clean
