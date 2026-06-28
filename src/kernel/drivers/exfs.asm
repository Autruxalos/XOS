; =============================================================================
; EXFS - UNIVERSAL STRUCTURE SPECIFICATION (16 / 32 / 64-BIT COMPATIBLE)
; Syntax: NASM
; Base Mapped Position: Sector 2 of XKERNEL block (Aligned to 512 bytes)
; =============================================================================

; Estructura del SuperBlock (Fijo: 512 bytes)
struc exfs_superblock
    sb_magic          resd 1    ; 4 Bytes - Firma mágica (0x53465845 -> 'EXFS')
    sb_version        resw 1    ; 2 Bytes - Versión del sistema de archivos
    sb_block_size     resw 1    ; 2 Bytes - Tamaño del bloque (512)
    sb_total_blocks   resd 1    ; 4 Bytes - Cantidad total de bloques
    sb_root_dir_lba   resd 1    ; 4 Bytes - Sector LBA del directorio raíz
    sb_reserved       resb 496  ; Relleno para completar los 512 bytes
endstruc

; Estructura de una Entrada de Directorio / Archivo (32 bytes fijos)
struc exfs_dir_entry
    dir_filename      resb 16   ; 16 Bytes - Nombre del archivo
    dir_start_lba     resd 1    ; 4 Bytes  - Sector LBA de inicio
    dir_file_size     resq 1    ; 8 Bytes  - Tamaño del archivo
    dir_flags         resb 1    ; 1 Byte   - Atributos
    dir_reserved      resb 3    ; 3 Bytes  - Alineación
endstruc

; =============================================================================
; EXFS DRIVER IMPLEMENTATION
; =============================================================================

; -----------------------------------------------------------------------------
; RUTINA PARA MODO REAL (16-BITS)
; -----------------------------------------------------------------------------
bits 16
exfs_validate_16:
    ; Entrada: ES:BX apunta al sector del SuperBlock cargado en RAM
    mov eax, [es:bx + sb_magic]
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
    ; Entrada: ESI apunta a la dirección de memoria del SuperBlock
    mov eax, [esi + sb_magic]
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
    ; Entrada: RSI apunta a la dirección del SuperBlock
    mov eax, [rsi + sb_magic]
    cmp eax, 0x53465845
    je .valid
    xor rax, rax
    ret
.valid:
    mov rax, 1
    ret

; =============================================================================
; ALINEACIÓN GEOMÉTRICA CRÍTICA
; =============================================================================
; Forzamos a que el driver ocupe exactamente 1 sector de disco (512 bytes).
; Esto evita que los archivos posteriores (exit.bin y xsh.bin) colisionen
; con los offsets en la memoria RAM del Exokernel.
times 512 - ($ - $$) db 0
