; =============================================================================
; EXFS - UNIVERSAL STRUCTURE SPECIFICATION (16 / 32 / 64-BIT COMPATIBLE)
; =============================================================================

; Estructura del SuperBlock (Ocupa exactamente 1 Sector = 512 bytes)
struc exfs_superblock
    .magic          resd 1    ; 4 Bytes - Firma mágica (ej: 0x53465845 -> 'EXFS')
    .version        resw 1    ; 2 Bytes - Versión del sistema de archivos
    .block_size     resw 1    ; 2 Bytes - Tamaño del bloque (fijo en 512)
    .total_blocks   resd 1    ; 4 Bytes - Cantidad total de bloques en el disco
    .root_dir_lba   resd 1    ; 4 Bytes - Sector LBA donde inicia el directorio raíz
    .reserved       resb 496  ; Relleno para completar los 512 bytes del sector
endstruc

; Estructura de una Entrada de Directorio / Archivo (32 bytes fijos)
struc exfs_dir_entry
    .filename       resb 16   ; 16 Bytes - Nombre del archivo (Terminado en 0 o relleno)
    .start_lba      resd 1    ; 4 Bytes  - Sector LBA de inicio en el disco
    .file_size      resq 1    ; 8 Bytes  - Tamaño del archivo (Soporta hasta 64-bits de tamaño)
    .flags          resb 1    ; 1 Byte   - Atributos (0: Archivo, 1: Directorio, 2: Sistema)
    .reserved       resb 3    ; 3 Bytes  - Alineación de estructura a 32 bytes
endstruc

; =============================================================================
; EXFS DRIVER IMPLEMENTATION
; =============================================================================

; -----------------------------------------------------------------------------
; RUTINA PARA MODO REAL (16-BITS)
; -----------------------------------------------------------------------------
bits 16
exfs_validate_16:
    ; Entrada: ES:BX apunta al sector del SuperBlock cargado en RAM por la BIOS
    ; Salida:  AX = 1 (Válido), 0 (Invalido)
    mov eax, [es:bx + exfs_superblock.magic]
    cmp eax, 0x53465845         ; ¿Es la firma 'EXFS'?
    je .valid
    xor ax, ax
    ret
.valid:
    mov ax, 1
    ret

; -----------------------------------------------------------------------------
; RUTINA PARA MODO PROTEGIDO (32-BITS)
; -----------------------------------------------------------------------------
bits 32
exfs_validate_32:
    ; Entrada: ESI apunta a la dirección de memoria donde se copió el SuperBlock
    mov eax, [esi + exfs_superblock.magic]
    cmp eax, 0x53465845
    je .valid
    xor eax, eax
    ret
.valid:
    mov eax, 1
    ret

; -----------------------------------------------------------------------------
; RUTINA PARA MODO LARGO (64-BITS NATIVOS)
; -----------------------------------------------------------------------------
bits 64
exfs_validate_64:
    ; Entrada: RSI apunta a la dirección de memoria virtual del SuperBlock
    ; Salida:  RAX = 1 o 0
    mov eax, [rsi + exfs_superblock.magic] ; El offset sigue siendo el mismo (+0)
    cmp eax, 0x53465845
    je .valid
    xor rax, rax
    ret
.valid:
    mov rax, 1
    ret
