; =============================================================================
; EXFS — Sistema de Archivos Propio de XOS (16/32/64 bits)
; Minimalista, sin inodos, compatible desde 8086
; =============================================================================

[BITS 16]   ; Código base en 16 bits, con wrappers para 32/64

; --- Constantes ---
EXFS_MAGIC      equ 'EXFS'
XOBJ_SIZE       equ 64
MAX_XOBJ        equ 1024

; --- SuperBlock (512 bytes) ---
struc EXFS_SuperBlock
    .magic          resb 4
    .version        resw 1
    .total_sectors  resd 1
    .free_sectors   resd 1
    .xobj_count     resw 1
    .root_index     resw 1
    .label          resb 32
    .reserved       resb 462
endstruc

; --- Entrada XOBJ (64 bytes) ---
struc XOBJ
    .name           resb 32   ; Nombre del objeto
    .type           resb 1    ; 0=Dir, 1=XEXE, 2=Doc, ...
    .attributes     resw 1    ; Bit 0=ReadOnly, Bit 1=AutoExec, etc.
    .start_lba      resd 1
    .size           resd 1
    .parent         resw 1    ; Índice del padre
    .default_type   resb 1    ; Para Directorios Inteligentes
    .reserved       resb 25
endstruc

; Variables globales (en BSS o sección de datos)
exfs_base_lba   dd 0
xobj_table      resb MAX_XOBJ * XOBJ_SIZE

; =============================================================================
; Inicialización (llamada desde EXIT)
; =============================================================================
exfs_mount:
    ; Leer SuperBlock desde disco (sector 1)
    mov bx, superblock_buffer
    mov ax, 1          ; Sector 1
    call disk_read_sector

    ; Verificar magic
    cmp dword [superblock_buffer], EXFS_MAGIC
    jne .mount_error

    mov si, msg_mounted
    call xk_print
    ret

.mount_error:
    mov si, msg_mount_fail
    call xk_print
    ret

; =============================================================================
; Crear objeto (new / make-dir)
; =============================================================================
exfs_create_xobj:
    ; Input: DS:SI = nombre, AL = tipo
    ; Busca entrada libre en tabla XOBJ y la llena
    ret   ; Implementación completa según necesidad

; =============================================================================
; Listar directorio actual
; =============================================================================
exfs_list:
    ; Recorre tabla XOBJ y muestra los del directorio actual
    ret

; =============================================================================
; Datos
msg_mounted     db "EXFS: Volumen montado correctamente.", 13, 10, 0
msg_mount_fail  db "EXFS: Error al montar volumen.", 13, 10, 0

superblock_buffer resb 512
