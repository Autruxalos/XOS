
# =============================================================================
# MAKEFILE - XOS EXOKERNEL OPERATING SYSTEM
# =============================================================================
# Mapa de sectores en disco (cada sector = 512 bytes):
#
#   Sector   0       → XBOOT   (MBR, 512 bytes exactos)
#   Sectores 1-16   → XKERNEL (hasta 8 KB)
#   Sectores 50-53  → EXIT    (hasta 2 KB)
#   Sectores 100-103→ XSH     (hasta 2 KB)
#
# Tamaño total de la imagen: 2 MB (4096 sectores)
# =============================================================================
 
ASM         = nasm
ASMFLAGS    = -f bin -w+all
 
BOOT_SRC    = src/boot/xboot.asm
KERNEL_SRC  = src/kernel/xkernel.asm
EXIT_SRC    = src/init/exit.asm
XSH_SRC     = src/apps/xsh.asm
 
BOOT_BIN    = build/xboot.bin
KERNEL_BIN  = build/xkernel.bin
EXIT_BIN    = build/exit.bin
XSH_BIN     = build/xsh.bin
 
IMAGE       = xos.img
IMAGE_SIZE  = 4096      # sectores × 512 bytes = 2 MB
 
.PHONY: all clean run debug
 
all: $(IMAGE)
 
# Crear directorio de build
build:
	@mkdir -p build
 
# Compilar XBOOT
$(BOOT_BIN): $(BOOT_SRC) | build
	@echo "[NASM] Compilando XBOOT..."
	$(ASM) $(ASMFLAGS) $< -o $@
	@size=$$(wc -c < $@); \
	if [ $$size -ne 512 ]; then \
		echo "ERROR: XBOOT tiene $$size bytes (debe ser exactamente 512)"; \
		exit 1; \
	fi
	@echo "      XBOOT OK (512 bytes, firma 0xAA55)"
 
# Compilar XKERNEL
$(KERNEL_BIN): $(KERNEL_SRC) | build
	@echo "[NASM] Compilando XKERNEL..."
	$(ASM) $(ASMFLAGS) $< -o $@
	@echo "      XKERNEL OK ($$(wc -c < $@) bytes)"
 
# Compilar EXIT
$(EXIT_BIN): $(EXIT_SRC) | build
	@echo "[NASM] Compilando EXIT..."
	$(ASM) $(ASMFLAGS) $< -o $@
	@echo "      EXIT OK ($$(wc -c < $@) bytes)"
 
# Compilar XSH
$(XSH_BIN): $(XSH_SRC) | build
	@echo "[NASM] Compilando XSH..."
	$(ASM) $(ASMFLAGS) $< -o $@
	@echo "      XSH OK ($$(wc -c < $@) bytes)"
 
# Ensamblar imagen de disco
$(IMAGE): $(BOOT_BIN) $(KERNEL_BIN) $(EXIT_BIN) $(XSH_BIN)
	@echo ""
	@echo "[IMG] Creando imagen de disco $(IMAGE) ($(IMAGE_SIZE) sectores)..."
 
	# 1. Inicializar imagen completa con ceros (CRÍTICO: evita basura entre sectores)
	dd if=/dev/zero of=$(IMAGE) bs=512 count=$(IMAGE_SIZE) status=none
 
	# 2. Sector 0: XBOOT (MBR)
	dd if=$(BOOT_BIN) of=$(IMAGE) bs=512 seek=0 count=1 conv=notrunc status=none
	@echo "      [sector   0] XBOOT"
 
	# 3. Sectores 1-16: XKERNEL
	dd if=$(KERNEL_BIN) of=$(IMAGE) bs=512 seek=1 conv=notrunc status=none
	@echo "      [sector   1] XKERNEL"
 
	# 4. Sectores 50-53: EXIT
	dd if=$(EXIT_BIN) of=$(IMAGE) bs=512 seek=50 conv=notrunc status=none
	@echo "      [sector  50] EXIT"
 
	# 5. Sectores 100-103: XSH
	dd if=$(XSH_BIN) of=$(IMAGE) bs=512 seek=100 conv=notrunc status=none
	@echo "      [sector 100] XSH"
 
	@echo ""
	@echo "[OK] Imagen lista: $(IMAGE)"
	@echo "     Usa 'make run' para ejecutar en QEMU."
 
# Ejecutar en QEMU (x86_64)
run: $(IMAGE)
	@echo "[QEMU] Iniciando XOS..."
	qemu-system-x86_64 \
		-drive format=raw,file=$(IMAGE),if=ide,media=disk \
		-m 32M \
		-no-reboot \
		-no-shutdown \
		-display sdl
 
# Ejecutar con monitor de QEMU y serial para debugging
debug: $(IMAGE)
	@echo "[QEMU] Modo debug - usa Ctrl+Alt+2 para el monitor de QEMU"
	qemu-system-x86_64 \
		-drive format=raw,file=$(IMAGE),if=ide,media=disk \
		-m 32M \
		-no-reboot \
		-no-shutdown \
		-monitor stdio \
		-d int,cpu_reset \
		-D qemu_debug.log
 
clean:
	@echo "[CLEAN] Limpiando binarios e imagen..."
	rm -rf build/
	rm -f $(IMAGE) qemu_debug.log
	@echo "      Listo."
