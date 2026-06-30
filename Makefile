# =============================================================================
# MAKEFILE COMPATIBLE CON BIOS QUISQUILLAS - PROYECTO XOS
# =============================================================================

# Compiladores y herramientas
ASM      = nasm
CC       = gcc
LD       = ld
DD       = dd
RM       = rm -f

# Directorios del proyecto
SRC_BOOT    = src/boot
SRC_KERNEL  = src/kernel
SRC_DRIVERS = src/kernel/drivers
SRC_INIT    = src/init
SRC_APPS    = src/apps
SRC_TOOLS   = src/tools
BIN_DIR     = bin

# Binarios finales de salida
XBOOT       = $(BIN_DIR)/xboot.bin
XKERNEL     = $(BIN_DIR)/xkernel.bin
XSH         = $(BIN_DIR)/xsh.bin
XFL         = $(BIN_DIR)/xfl.bin
XDT         = $(BIN_DIR)/xdt.bin
XINSTALLER  = $(BIN_DIR)/xinstaller.com
XDISK_IMG   = $(BIN_DIR)/xos_dist.img

.PHONY: all clean directories image

# Regla principal
all: directories $(XBOOT) $(XKERNEL) $(XSH) $(XFL) $(XDT) $(XINSTALLER) image

# Crear directorio de binarios si no existe
directories:
	@mkdir -p $(BIN_DIR)

# -----------------------------------------------------------------------------
# COMPILACIÓN DE COMPONENTES BASE (Bajo nivel estricto)
# -----------------------------------------------------------------------------

# 1. Sector de arranque (Alineado estrictamente a 512 bytes gracias a las directivas internas)
$(XBOOT): $(SRC_BOOT)/xboot.asm $(SRC_DRIVERS)/exfs.asm
	$(ASM) -f bin $< -o $@

# 2. El Exokernel (Compilado para el Modo Largo de tu Phenom II)
$(XKERNEL): $(SRC_KERNEL)/xkernel.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# COMPILACIÓN DE ESPACIO DE USUARIO Y UTILIDADES (16-bits Reales)
# -----------------------------------------------------------------------------

# 3. La Shell con comandos lógicos
$(XSH): $(SRC_APPS)/xsh.asm
	$(ASM) -f bin $< -o $@

# 4. Administrador de archivos
$(XFL): $(SRC_APPS)/xfl.asm
	$(ASM) -f bin $< -o $@

# 5. Editor de texto ultra ligero
$(XDT): $(SRC_APPS)/xdt.asm
	$(ASM) -f bin $< -o $@

# 6. El Instalador Nativo de 16 bits (.COM ejecutable desde entorno DOS/XOS)
$(XINSTALLER): $(SRC_TOOLS)/xinstaller.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# CREACIÓN DE LA IMAGEN DE DISCO LBA INMUNE A FALLOS DE BIOS
# -----------------------------------------------------------------------------
# Explicación del mapa de sectores estructurado:
# Sector 0 (LBA 0): XBOOT (MBR con tabla de partición falsa)
# Sectores 1-32 (LBA 1): Reservado para XFAT (Lleno de ceros inicialmente)
# Sectores 33-64 (LBA 33): Reservado para Root Directory
# Sector 65+ (LBA 65): Bloque unificado de Aplicaciones (XSH, XFL, XDT, etc.)
# -----------------------------------------------------------------------------

image:
	@echo "Generando imagen de almacenamiento compatible..."
	# Creación de un disco virtual limpio de 20 Megabytes (Ajustable a tus necesidades)
	$(DD) if=/dev/zero of=$(XDISK_IMG) bs=512 count=40000 status=none
	
	# Inyección del MBR/XBOOT exactamente en el Sector 0
	$(DD) if=$(XBOOT) of=$(XDISK_IMG) bs=512 count=1 conv=notrunc status=none
	
	# Inyección del Kernel en su sector asignado (Supongamos sector LBA 65 para datos puros)
	$(DD) if=$(XKERNEL) of=$(XDISK_IMG) bs=512 seek=65 conv=notrunc status=none
	
	# Concatenación y alineación secuencial de tus apps del sistema en sectores continuos
	# Nota: Esto prepara la estructura interna que leerá tu driver de EXFS
	$(DD) if=$(XSH) of=$(XDISK_IMG) bs=512 seek=200 conv=notrunc status=none
	$(DD) if=$(XFL) of=$(XDISK_IMG) bs=512 seek=250 conv=notrunc status=none
	$(DD) if=$(XDT) of=$(XDISK_IMG) bs=512 seek=300 conv=notrunc status=none
	
	@echo "STRICT_SUCCESS: Imagen '$(XDISK_IMG)' lista para flashear en USB o HDD físico."

# Limpieza de archivos compilados
clean:
	@echo "Limpiando binarios anteriores..."
	$(RM) $(BIN_DIR)/*.bin $(BIN_DIR)/*.com $(BIN_DIR)/*.img
	@rmdir $(BIN_DIR) 2>/dev/null || true
