# =============================================================================
# MAESTRO MAKEFILE - XOS EXOKERNEL ECOSYSTEM [XSPEC-0001]
# Diseñado para compilar e integrar todos los submódulos en Void Linux
# =============================================================================

ASM=nasm
BUILD_DIR=build
OUTPUT_IMG=$(BUILD_DIR)/xos_bios.img

# Definición de rutas hacia los submódulos independientes de GitHub
BOOT_DIR=src/boot
KERNEL_DIR=src/kernel
INIT_DIR=src/init
APPS_DIR=src/apps

.PHONY: all clean init_submodules image run

# 1. Compilación por defecto: Construye la imagen completa del sistema
all: image

# 2. Inicializar y clonar automáticamente los 5 repositorios periféricos
init_submodules:
	@echo "Vinculando repositorios modulares de GitHub..."
	git submodule init
	git submodule update --remote --recursive

# 3. Ensamblar componente por componente y construir el almacenamiento crudo EXFS
image:
	@mkdir -p $(BUILD_DIR)
	@echo "--- COMPILANDO COMPONENTES NATIVOS EN ASM ---"
	
	# Ensamblar XBOOT (Sector 0 - MBR)
	$(ASM) -f bin $(BOOT_DIR)/xboot.asm -o $(BUILD_DIR)/xboot.bin
	
	# Ensamblar XKERNEL (Núcleo base - Mapeado a partir del Sector 2)
	$(ASM) -f bin $(KERNEL_DIR)/xkernel.asm -o $(BUILD_DIR)/xkernel.bin
	
	# Ensamblar EXIT (Proceso de inicialización)
	$(ASM) -f bin $(INIT_DIR)/exit.asm -o $(BUILD_DIR)/exit.bin
	
	# Ensamblar XSH (Shell nativa en modo 16 bits para el disco real)
	$(ASM) -f bin $(APPS_DIR)/xsh.asm -o $(BUILD_DIR)/xsh.bin

	@echo "--- ESTRUCTURANDO EL DISCO CRUDO EXFS ---"
	# Crear un disco virtual vacío de 10 Megabytes (20480 sectores de 512 bytes)
	dd if=/dev/zero of=$(OUTPUT_IMG) bs=512 count=20480
	
	# Inyectar XBOOT en el Sector Absoluto 0
	dd if=$(BUILD_DIR)/xboot.bin of=$(OUTPUT_IMG) bs=512 count=1 conv=notrunc
	
	# Inyectar el bloque del SuperBlock de EXFS en el Sector Absoluto 1
	# Nota: El formato lógico inicial se autogenera mediante la estructura de datos
	dd if=/dev/zero of=$(OUTPUT_IMG) bs=512 seek=1 count=1 conv=notrunc
	
	# Inyectar XKERNEL en el sector de inicio del sistema operativo (Sector 2)
	dd if=$(BUILD_DIR)/xkernel.bin of=$(OUTPUT_IMG) bs=512 seek=2 conv=notrunc

	# Inyectar EXIT y XSH en el área de datos de EXFS (Sector 38 en adelante)
	dd if=$(BUILD_DIR)/exit.bin of=$(OUTPUT_IMG) bs=512 seek=38 conv=notrunc
	dd if=$(BUILD_DIR)/xsh.bin of=$(OUTPUT_IMG) bs=512 seek=50 conv=notrunc
	
	@echo "¡Instalación exitosa! Imagen generada en: $(OUTPUT_IMG)"

# 4. Limpiar binarios antiguos de la carpeta de compilación
clean:
	rm -rf $(BUILD_DIR)

# 5. Lanzar de forma automática en la máquina virtual QEMU de Void Linux
run: image
	qemu-system-i386 -drive format=raw,file=$(OUTPUT_IMG)
