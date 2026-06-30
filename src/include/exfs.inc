; =============================================================================
; ARCHIVO: src/include/exfs.inc
; Estructuras rígidas de EXFS para herramientas de 16 bits
; =============================================================================

%ifndef EXFS_INC
%define EXFS_INC

; Geometría fija del sistema de archivos
EXFS_FIRMA          equ 0x00        ; 8 bytes
EXFS_SECTORES_FAT   equ 0x08        ; 2 bytes
EXFS_ENTRADAS_ROOT  equ 0x0A        ; 2 bytes
EXFS_BYTES_SECTOR   equ 0x0C        ; 2 bytes
EXFS_BLOQUE_INICIO  equ 0x0E        ; 2 bytes (Por defecto sector 65)

; Desplazamientos dentro de una entrada de directorio (32 bytes fijos)
DIR_NOMBRE          equ 0           ; 8 bytes
DIR_EXTENSION       equ 8           ; 3 bytes
DIR_ATRIBUTO        equ 11          ; 1 byte
DIR_BLOQUE_INICIO   equ 12          ; 2 bytes
DIR_TAMANO          equ 14          ; 4 bytes
DIR_RESERVADO       equ 18          ; 14 bytes

%endif
