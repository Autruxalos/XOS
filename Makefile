# =============================================================================
# MAKEFILE MAESTRO DE XOS - MONORREPOSITORIO CORREGIDO (TAMAÑO FIJO)
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

	# 2. Compilar Exokernel Base Polimórfico
	nasm -f bin $(SRC_DIR)/kernel/xkernel.asm -o $(BUILD_DIR)/xkernel.bin

	# 3. Compilar Dependencia: Driver del Sistema de Archivos EXFS
	nasm -f bin $(SRC_DIR)/kernel/drivers/exfs.asm -o $(BUILD_DIR)/exfs.bin

	# 4. Compilar Dependencia: Subsistema Init (EXIT)
	nasm -f bin $(SRC_DIR)/init/exit.asm -o $(BUILD_DIR)/exit.bin

	# 5. Compilar Dependencia: Shell Interactiva Multi-Arquitectura (XSH)
	nasm -f bin $(SRC_DIR)/apps/xsh.asm -o $(BUILD_DIR)/xsh.bin

	@echo "--- CONCATENANDO Y AJUSTANDO IMAGEN FÍSICA DE DISCO ---"
	# Fusionamos los componentes binarios en orden directo
	cat $(BUILD_DIR)/xboot.bin \
	    $(BUILD_DIR)/xkernel.bin \
	    $(BUILD_DIR)/exfs.bin \
	    $(BUILD_DIR)/exit.bin \
	    $(BUILD_DIR)/xsh.bin > $(IMAGE_OUT)

	# CALIBRACIÓN REAL: Forzamos el archivo final a medir exactamente 8704 bytes
	# (1 sector del MBR + 16 sectores leídos por la BIOS = 17 sectores de 512 bytes)
	truncate -s 8704 $(IMAGE_OUT)
	@echo "¡Éxito! Archivo unificado de tamaño fijo listo en: $(IMAGE_OUT)"

run: image
	@echo "--- LANZANDO CONFIGURACIÓN DE PRUEBA EN QEMU ---"
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE_OUT)

clean:
	@echo "--- LIMPIANDO ESTRUCTURAS TEMPORALES ---"
	rm -rf $(BUILD_DIR)
