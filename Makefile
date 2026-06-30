# =============================================================================
# Makefile Unificado XOS (Edición Definitiva - i486 / x86_64)
# =============================================================================

# Configuración del compilador Assembler
NASM       = nasm
NASM_FLAGS = -f bin -w+all

# Directorios y Archivos de salida
BUILD_DIR  = build
IMAGE      = $(BUILD_DIR)/XOS.img

# Archivos Fuente
XBOOT_SRC     = src/boot/xboot.asm
XKERNEL_SRC   = src/kernel/xkernel.asm
EXFS_INIT_SRC = src/tools/init-exfs.asm

# Objetivo por defecto
all: image

# Creación del directorio de compilación si no existe
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Reglas de compilación de binarios planos
$(BUILD_DIR)/xboot.bin: $(XBOOT_SRC) | $(BUILD_DIR)
	@echo "[NASM] Compilando Bootloader..."
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BUILD_DIR)/xkernel.bin: $(XKERNEL_SRC) | $(BUILD_DIR)
	@echo "[NASM] Compilando Kernel..."
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BUILD_DIR)/init-exfs.bin: $(EXFS_INIT_SRC) | $(BUILD_DIR)
	@echo "[NASM] Compilando init-exfs..."
	$(NASM) $(NASM_FLAGS) $< -o $@

# Construcción de la imagen de disco cruda (.img)
image: $(BUILD_DIR)/xboot.bin $(BUILD_DIR)/xkernel.bin $(BUILD_DIR)/init-exfs.bin
	@echo "[IMG] Generando imagen de disco vacía..."
	dd if=/dev/zero of=$(IMAGE) bs=512 count=131072 status=none
	@echo "[IMG] Escribiendo Bootloader (Sector 0)..."
	dd if=$(BUILD_DIR)/xboot.bin of=$(IMAGE) conv=notrunc status=none
	@echo "[IMG] Escribiendo Kernel (Sector 1 al 66)..."
	dd if=$(BUILD_DIR)/xkernel.bin of=$(IMAGE) seek=1 conv=notrunc status=none
	@echo "[IMG] Escribiendo Sistema de Archivos exFS (Sector 67)..."
	dd if=$(BUILD_DIR)/init-exfs.bin of=$(IMAGE) seek=67 conv=notrunc status=none
	@echo "========================================="
	@echo "      ====== XOS COMPILADO ======"
	@echo "========================================="

# Ejecución en entorno nativo i486 (Modo protegido 32-bits emulado)
run: image
	@echo "[QEMU] Iniciando emulación i486..."
	qemu-system-i386 -cpu 486 -drive format=raw,file=$(IMAGE) -d int,cpu_reset -no-reboot -no-shutdown

# Ejecución alternativa en entorno x86_64
run64: image
	@echo "[QEMU] Iniciando emulación x86_64..."
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE) -m 64M -cpu qemu64

# Limpieza del espacio de trabajo
clean:
	@echo "[CLEAN] Eliminando archivos del directorio build..."
	rm -rf $(BUILD_DIR)

.PHONY: all image run run64 clean
