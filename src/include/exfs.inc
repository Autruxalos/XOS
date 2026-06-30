; =============================================================================
; EXFS - ESTRUCTURAS FÍSICAS UNIFICADAS DEL SISTEMA DE ARCHIVOS
; =============================================================================
; Este archivo se incluye con %include para que los módulos de 16, 32 y 64 bits 
; conozcan la arquitectura del disco virtual sin duplicar código.

; --- EL SUPERBLOQUE (Debe medir exactamente 512 bytes / 1 Sector) ---
struc exfs_superblock
    .magic          resb 4      ; Firma mágica 'EXFS'
    .version        resw 1      ; Versión del sistema de archivos
    .total_sectors  resd 1      ; Tamaño total del disco en sectores lógicos
    .kernel_start   resd 1      ; LBA de inicio del XKERNEL
    .kernel_sectors resd 1      ; Cantidad de sectores que ocupa el XKERNEL
    .root_index     resd 1      ; LBA donde empieza el directorio Raíz (|)
    .block_size     resw 1      ; Tamaño estándar (512 bytes)
    .label          resb 32     ; Nombre del volumen (Ej. "XOS_MAIN_DRIVE")
    .reserved       resb 456    ; Relleno calculado: 512 - 56 = 456 bytes
endstruc

; --- OBJETO DE ARCHIVO/DIRECTORIO (Debe medir exactamente 64 bytes) ---
; Caben exactamente 8 objetos (XOBJ) por cada sector del disco
struc exfs_xobj
    .name           resb 32     ; Nombre del archivo o directorio
    .type           resb 1      ; 0 = Archivo, 1 = Directorio
    .attributes     resw 1      ; Permisos y flags
    .start_lba      resd 1      ; LBA donde residen los datos de este archivo
    .size           resd 1      ; Tamaño en bytes del archivo
    .parent_lba     resd 1      ; LBA del directorio padre
    .reserved       resb 17     ; Relleno calculado: 64 - 47 = 17 bytes
endstruc

; Constantes globales para la Shell
XOBJ_TYPE_FILE  equ 0
XOBJ_TYPE_DIR   equ 1
