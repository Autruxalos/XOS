# =============================================================================
# MAKEFILE MAESTRO DE XOS - MONORREPOSITORIO TOTALMENTE SINCRONIZADO
# =============================================================================

SRC_DIR   = src
BUILD_DIR = build
IMAGE_OUT = $(BUILD_DIR)/xos_bios.img

.PHONY: all image run clean

# Acción por defecto
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

	@echo "--- CONCATENANDO Y RELLENANDO IMAGEN FÍSICA DE DISCO ---"
	# Fusionamos los componentes binarios en el orden en que se mapean en la RAM
	cat $(BUILD_DIR)/xboot.bin \
	    $(BUILD_DIR)/xkernel.bin \
	    $(BUILD_DIR)/exfs.bin \
	    $(BUILD_DIR)/exit.bin \
	    $(BUILD_DIR)/xsh.bin > $(IMAGE_OUT)

	# CALIBRACIÓN TÉCNICA: Rellenamos con ceros usando dd para coincidir exactamente
	# con los 64 sectores que xboot.asm le exige a la BIOS (65 sectores en total = 33,280 bytes)
	dd if=/dev/zero bs=512 count=65 >> $(IMAGE_OUT) 2>/dev/null
	@echo "¡Éxito! Archivo unificado listo en: $(IMAGE_OUT)"

run: image
	@echo "--- LANZANDO CONFIGURACIÓN DE PRUEBA EN QEMU ---"
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE_OUT)

clean:
	@echo "--- LIMPIANDO ESTRUCTURAS TEMPORALES ---"
	rm -rf $(BUILD_DIR)
