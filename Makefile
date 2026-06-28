# =============================================================================
# MAKEFILE MAESTRO DE XOS - CONFIGURACIÓN DE SEGURIDAD (OPCIÓN B)
# =============================================================================

SRC_DIR   = src
BUILD_DIR = build
IMAGE_OUT = $(BUILD_DIR)/xos_bios.img

.PHONY: all image run clean

all: image

image:
	@mkdir -p $(BUILD_DIR)
	@echo "--- COMPILANDO COMPONENTES DEL MONORREPOSITORIO ---"

	# 1. Compilar Cargador de Arranque MBR (Sector 0)
	nasm -f bin $(SRC_DIR)/boot/xboot.asm -o $(BUILD_DIR)/xboot.bin

	# 2. Compilar Exokernel Base Polimórfico (Sector 1)
	nasm -f bin $(SRC_DIR)/kernel/xkernel.asm -o $(BUILD_DIR)/xkernel.bin

	# 3. Compilar Subsistema Init (Pasado al Sector 2)
	nasm -f bin $(SRC_DIR)/init/exit.asm -o $(BUILD_DIR)/exit.bin

	# 4. Compilar Shell Interactiva Multi-Arquitectura
	nasm -f bin $(SRC_DIR)/apps/xsh.asm -o $(BUILD_DIR)/xsh.bin

	# 5. Compilar Driver EXFS (Módulo de almacenamiento aislado al final)
	nasm -f bin $(SRC_DIR)/kernel/drivers/exfs.asm -o $(BUILD_DIR)/exfs.bin

	@echo "--- CONCATENANDO SECTORES EN ORDEN OPERATIVO SEGURO ---"
	# CORRECCIÓN DE FLUJO: EXFS va al final para evitar ejecuciones accidentales
	cat $(BUILD_DIR)/xboot.bin \
	    $(BUILD_DIR)/xkernel.bin \
	    $(BUILD_DIR)/exit.bin \
	    $(BUILD_DIR)/xsh.bin \
	    $(BUILD_DIR)/exfs.bin > $(IMAGE_OUT)

	# Forzamos tamaño de imagen limpia para SeaBIOS (17 sectores de 512 bytes)
	truncate -s 8704 $(IMAGE_OUT)
	@echo "¡Éxito! Imagen operativa estructurada en: $(IMAGE_OUT)"

run: image
	@echo "--- EJECUTANDO INSTANCIA ESTABLE EN QEMU ---"
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE_OUT)

clean:
	@echo "--- ELIMINANDO BINARIOS LOCALES ---"
	rm -rf $(BUILD_DIR)
