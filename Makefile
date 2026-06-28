# =============================================================================
# MAKEFILE MAESTRO DE XOS - MONORREPOSITORIO ABSOLUTO
# =============================================================================

SRC_DIR   = src
BUILD_DIR = build
IMAGE_OUT = $(BUILD_DIR)/xos_bios.img

.PHONY: all image run clean

all: image

image:
	@mkdir -p $(BUILD_DIR)
	@echo "--- ENSAMBLANDO DEPENDENCIAS NATIVAS LOCALES ---"

	# 1. Compilar XBOOT (Sector 0 - MBR)
	nasm -f bin $(SRC_DIR)/boot/xboot.asm -o $(BUILD_DIR)/xboot.bin

	# 2. Compilar EXFS Driver (Sistema de archivos integrado en el Núcleo)
	nasm -f bin $(SRC_DIR)/kernel/drivers/exfs.asm -o $(BUILD_DIR)/exfs.bin

	# 3. Compilar XKERNEL (El Exokernel base)
	nasm -f bin $(SRC_DIR)/kernel/xkernel.asm -o $(BUILD_DIR)/xkernel.bin

	# 4. Compilar EXIT (Subsistema Init)
	nasm -f bin $(SRC_DIR)/init/exit.asm -o $(BUILD_DIR)/exit.bin

	# 5. Compilar XSH (La Shell interactiva polimórfica)
	nasm -f bin $(SRC_DIR)/apps/xsh.asm -o $(BUILD_DIR)/xsh.bin

	@echo "--- CONCATENANDO SECTORES CRUDOS EN EL ARCHIVO .IMG ---"
	# Fusionamos en orden físico de disco: MBR -> Driver -> Kernel -> Init -> Shell
	cat $(BUILD_DIR)/xboot.bin \
	    $(BUILD_DIR)/exfs.bin \
	    $(BUILD_DIR)/xkernel.bin \
	    $(BUILD_DIR)/exit.bin \
	    $(BUILD_DIR)/xsh.bin > $(IMAGE_OUT)
	@echo "¡Éxito! Todo el árbol de dependencias compilado en: $(IMAGE_OUT)"

run: image
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE_OUT)

clean:
	rm -rf $(BUILD_DIR)
