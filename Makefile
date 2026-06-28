# =============================================================================
# MAKEFILE - SISTEMA DE COMPILACIÓN MULTI-ARQUITECTURA PARA XOS
# =============================================================================
# Diseñado para compilar el exokernel y sus entornos de ejecución de forma aislada.

# --- CONFIGURACIÓN DE RUTAS Y ARCHIVOS ---
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

# --- HERRAMIENTAS DE COMPILACIÓN ---
ASM         = nasm
ASM_FLAGS   = -f bin

# =============================================================================
# REGLAS DE CONSTRUCCIÓN PRINCIPALES
# =============================================================================

.PHONY: all clean run REBUILD

all: $(IMAGE_OUT)

# Generación del disco estructurado por sectores limpios (Alineación a 512 bytes)
$(IMAGE_OUT): $(BOOT_BIN) $(KERNEL_BIN) $(XSH16_BIN) $(XSH32_BIN) $(XSH64_BIN)
	@echo "================================================================="
	@echo "🛠️  Construyendo imagen de almacenamiento monolítica: $(IMAGE_OUT)"
	@echo "================================================================="
	
	# 1. Sector 0 (Master Boot Record / Bootloader - Exactamente 512 bytes)
	dd if=$(BOOT_BIN) of=$(IMAGE_OUT) bs=512 count=1 conv=notrunc
	
	# 2. Sector 1 al 19: Reservado para el espacio físico del Kernel base
	dd if=$(KERNEL_BIN) of=$(IMAGE_OUT) bs=512 seek=1 conv=notrunc
	
	# 3. Sector 20 al 39: Espacio aislado para la Shell de 16-bits (Modo Real / 8086)
	dd if=$(XSH16_BIN) of=$(IMAGE_OUT) bs=512 seek=20 conv=notrunc
	
	# 4. Sector 40 al 59: Espacio aislado para la Shell de 32-bits (Modo Protegido / i386)
	dd if=$(XSH32_BIN) of=$(IMAGE_OUT) bs=512 seek=40 conv=notrunc
	
	# 5. Sector 60 en adelante: Espacio aislado para la Shell de 64-bits (Long Mode / AMD64)
	dd if=$(XSH64_BIN) of=$(IMAGE_OUT) bs=512 seek=60 conv=notrunc
	
	@echo "================================================================="
	@echo "✅ Imagen de sistema $(IMAGE_OUT) compilada y sectorizada."
	@echo "================================================================="

# =============================================================================
# REGLAS DE COMPILACIÓN DE CÓDIGO FUENTE (NASM)
# =============================================================================

$(BOOT_BIN): $(BOOT_ASM)
	@echo "[ASM] Compilando Cargador de Arranque: $<"
	$(ASM) $(ASM_FLAGS) $< -o $@

$(KERNEL_BIN): $(KERNEL_ASM)
	@echo "[ASM] Compilando Núcleo del Sistema: $<"
	$(ASM) $(ASM_FLAGS) $< -o $@

$(XSH16_BIN): $(XSH16_ASM)
	@echo "[ASM] Compilando Entorno Interactivo 16-bits: $<"
	$(ASM) $(ASM_FLAGS) $< -o $@

$(XSH32_BIN): $(XSH32_ASM)
	@echo "[ASM] Compilando Entorno Interactivo 32-bits: $<"
	$(ASM) $(ASM_FLAGS) $< -o $@

$(XSH64_BIN): $(XSH64_ASM)
	@echo "[ASM] Compilando Entorno Interactivo 64-bits: $<"
	$(ASM) $(ASM_FLAGS) $< -o $@

# =============================================================================
# UTILIDADES Y EMULACIÓN
# =============================================================================

# Forzar recompilación completa borrando la caché previa
REBUILD: clean all

# Eliminar todos los archivos temporales y binarios generados
clean:
	@echo "🧹 Limpiando espacio de trabajo..."
	rm -f *.bin *.img

# Lanzar el sistema en el emulador QEMU con arquitectura x86_64 pura
run: $(IMAGE_OUT)
	@echo "🚀 Iniciando emulación en máquina virtual x86_64..."
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE_OUT)
