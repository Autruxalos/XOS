# =============================================================================
# MAKEFILE MAESTRO UNIVERSAL - PROYECTO XOS
# COMPATIBLE CON BIOS REALES (64MB) + EJECUCIÓN DIRECTA EN QEMU
# =============================================================================

# Compiladores y herramientas
ASM      = nasm
CC       = gcc
LD       = ld
DD       = dd
RM       = rm -f
QEMU     = qemu-system-x86_64

# Directorios del proyecto
SRC_BOOT    = src/boot
SRC_KERNEL  = src/kernel
SRC_DRIVERS = src/kernel/drivers
SRC_INIT    = src/init
SRC_APPS    = src/apps
SRC_TOOLS   = src/tools
BIN_DIR     = bin

# Binarios de infraestructura y Kernel
XBOOT       = $(BIN_DIR)/xboot.bin
XKERNEL     = $(BIN_DIR)/xkernel.bin
XINSTALLER  = $(BIN_DIR)/xinstaller.com

# Binarios de Init, Subsistemas y Librerías
XEXIT       = $(BIN_DIR)/exit.bin
XPKG        = $(BIN_DIR)/xpkg.bin
XEXE        = $(BIN_DIR)/xexe.bin

# Binarios de Aplicaciones de Usuario
XSH         = $(BIN_DIR)/xsh.bin
XFL         = $(BIN_DIR)/xfl.bin
XDT         = $(BIN_DIR)/xdt.bin

# Imagen de almacenamiento final (Alineada a 64MB para BIOS estrictas)
XDISK_IMG   = $(BIN_DIR)/xos_dist.img

.PHONY: all clean directories image run

# 1. COMPILAR TODO Y GENERAR IMAGEN
all: directories $(XBOOT) $(XKERNEL) $(XEXIT) $(XPKG) $(XEXE) $(XSH) $(XFL) $(XDT) $(XINSTALLER) image

# 2. COMPILAR Y CORRER AUTOMÁTICAMENTE EN QEMU
run: all
	@echo "Lanzando XOS en QEMU (Emulando arquitectura AMD Phenom)..."
	$(QEMU) -cpu phenom -m 2G -drive format=raw,file=$(XDISK_IMG)

# Crear directorio de binarios si no existe
directories:
	@mkdir -p $(BIN_DIR)

# -----------------------------------------------------------------------------
# COMPILACIÓN DE COMPONENTES BASE (Bajo nivel y Drivers)
# -----------------------------------------------------------------------------

$(XBOOT): src/boot/xboot.asm
	$(ASM) -I./ -f bin $< -o $@

$(XKERNEL): $(SRC_KERNEL)/xkernel.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# COMPILACIÓN DE INFRAESTRUCTURA DE SISTEMA
# -----------------------------------------------------------------------------

$(XEXIT): $(SRC_INIT)/exit.asm
	$(ASM) -f bin $< -o $@

$(XPKG): src/pkg/xpkg.asm
	$(ASM) -f bin $< -o $@

$(XEXE): src/formats/xexe.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# COMPILACIÓN DE APLICACIONES DE USUARIO
# -----------------------------------------------------------------------------

$(XSH): $(SRC_APPS)/xsh.asm
	$(ASM) -f bin -i $(SRC_APPS)/ $< -o $@

$(XFL): $(SRC_APPS)/xfl.asm
	$(ASM) -f bin -i $(SRC_APPS)/ $< -o $@

$(XDT): $(SRC_APPS)/xdt.asm
	$(ASM) -f bin -i $(SRC_APPS)/ $< -o $@

$(XINSTALLER): $(SRC_TOOLS)/xinstaller.asm
	$(ASM) -I./ -f bin $< -o $@

# -----------------------------------------------------------------------------
# MAPEADO DE SECTORES LBA (Inyección en la imagen de disco)
# -----------------------------------------------------------------------------

image:
	@echo "Montando la geometría del disco e inyectando dependencias..."
	# Generar un contenedor alineado de 64MB (131072 sectores de 512 bytes)
	# Esto simula una geometría CHS válida que las BIOS reales aceptan como USB-HDD.
	$(DD) if=/dev/zero of=$(XDISK_IMG) bs=512 count=131072 status=none
	
	# Sector 0: Master Boot Record (XBOOT)
	$(DD) if=$(XBOOT) of=$(XDISK_IMG) bs=512 count=1 conv=notrunc status=none
	
	# Sector 65: El Exokernel principal
	$(DD) if=$(XKERNEL) of=$(XDISK_IMG) bs=512 seek=65 conv=notrunc status=none
	
	# --- SECTORES DE COMPONENTES DEL SISTEMA ---
	$(DD) if=$(XEXIT) of=$(XDISK_IMG) bs=512 seek=120 conv=notrunc status=none
	$(DD) if=$(XPKG) of=$(XDISK_IMG) bs=512 seek=140 conv=notrunc status=none
	$(DD) if=$(XEXE) of=$(XDISK_IMG) bs=512 seek=160 conv=notrunc status=none
	
	# --- SECTORES DE APLICACIONES ---
	$(DD) if=$(XSH) of=$(XDISK_IMG) bs=512 seek=200 conv=notrunc status=none
	$(DD) if=$(XFL) of=$(XDISK_IMG) bs=512 seek=250 conv=notrunc status=none
	$(DD) if=$(XDT) of=$(XDISK_IMG) bs=512 seek=300 conv=notrunc status=none
	
	@echo "STRICT_SUCCESS: Imagen de 64MB generada correctamente en: $(XDISK_IMG)"

clean:
	@echo "Limpiando binarios..."
	$(RM) $(BIN_DIR)/*.bin $(BIN_DIR)/*.com $(BIN_DIR)/*.img
	@rmdir $(BIN_DIR) 2>/dev/null || true
