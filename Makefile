# =============================================================================
# MAKEFILE MAESTRO COMPATIBLE CON BIOS REALES - PROYECTO XOS
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

# Imagen de almacenamiento final
XDISK_IMG   = $(BIN_DIR)/xos_dist.img

.PHONY: all clean directories image

# Regla de compilación total de dependencias
all: directories $(XBOOT) $(XKERNEL) $(XEXIT) $(XPKG) $(XEXE) $(XSH) $(XFL) $(XDT) $(XINSTALLER) image

# Crear directorio de binarios si no existe
directories:
	@mkdir -p $(BIN_DIR)

# -----------------------------------------------------------------------------
# COMPILACIÓN DE COMPONENTES BASE (Bajo nivel y Drivers)
# -----------------------------------------------------------------------------

bin/xboot.bin: src/boot/xboot.asm
	nasm -I./ -f bin src/boot/xboot.asm -o bin/xboot.bin

# El Exokernel (Compilado nativo para el modo largo del Phenom II)
$(XKERNEL): $(SRC_KERNEL)/xkernel.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# COMPILACIÓN DE INFRAESTRUCTURA DE SISTEMA (Módulos de Inicialización / Formatos)
# -----------------------------------------------------------------------------

# Gestor de salida del sistema (exit.asm en src/init/)
$(XEXIT): $(SRC_INIT)/exit.asm
	$(ASM) -f bin $< -o $@

# Gestor de paquetes nativo (xpkg.asm en src/apps/ o src/tools/ según tu árbol)
# NOTA: Ajusta la ruta si xpkg.asm está en otra subcarpeta
$(XPKG): src/pkg/xpkg.asm
	$(ASM) -f bin $< -o $@

# Soporte del formato ejecutable nativo (xexe.asm)
$(XEXE): src/formats/xexe.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# COMPILACIÓN DE APLICACIONES DE USUARIO (Enlazadas o incluyendo xlibc)
# -----------------------------------------------------------------------------

# NOTA: En las aplicaciones añadimos el flag de inclusión '-i' apuntando a donde
# tengas guardada tu 'xlibc' para que puedan heredar las llamadas al sistema.

$(XSH): $(SRC_APPS)/xsh.asm
	$(ASM) -f bin -i $(SRC_APPS)/ $< -o $@

$(XFL): $(SRC_APPS)/xfl.asm
	$(ASM) -f bin -i $(SRC_APPS)/ $< -o $@

$(XDT): $(SRC_APPS)/xdt.asm
	$(ASM) -f bin -i $(SRC_APPS)/ $< -o $@

# El Instalador Nativo ejecutable en entorno real de 16 bits
$(XINSTALLER): $(SRC_TOOLS)/xinstaller.asm
	$(ASM) -f bin $< -o $@

# -----------------------------------------------------------------------------
# MAPEADO DE SECTORES LBA (Inyección en la imagen de disco)
# -----------------------------------------------------------------------------
# Para evitar la pantalla rosada, cada componente se monta en su propia "isla"
# de sectores estables mediante saltos exactos (seek).
# -----------------------------------------------------------------------------

image:
	@echo "Montando la geometría del disco e inyectando dependencias..."
	# Generar el contenedor virtual vacío de 20MB
	$(DD) if=/dev/zero of=$(XDISK_IMG) bs=512 count=40000 status=none
	# Generar un contenedor alineado de 64MB (131072 sectores de 512 bytes)
	# Esto fuerza una geometría virtual CHS limpia para BIOS quisquilleras.
	$(DD) if=/dev/zero of=$(XDISK_IMG) bs=512 count=131072 status=none

	# Sector 0: Master Boot Record (XBOOT)
	# Sector 0: Master Boot Record (XBOOT) con conv=notrunc para preservar el tamaño
	$(DD) if=$(XBOOT) of=$(XDISK_IMG) bs=512 count=1 conv=notrunc status=none

	# Sector 65: El Exokernel principal
@@ -131,9 +128,9 @@
	# Sector 300: Editor de texto (XDT)
	$(DD) if=$(XDT) of=$(XDISK_IMG) bs=512 seek=300 conv=notrunc status=none

	@echo "STRICT_SUCCESS: Todas las dependencias (exit, xpkg, xexe) fueron mapeadas sin solapamiento."
	@echo "STRICT_SUCCESS: Todas las dependencias mapeadas en imagen compatible con BIOS real."

clean:
	@echo "Limpiando binarios..."
	$(RM) $(BIN_DIR)/*.bin $(BIN_DIR)/*.com $(BIN_DIR)/*.img
	@rmdir $(BIN_DIR) 2>/dev/null || true
