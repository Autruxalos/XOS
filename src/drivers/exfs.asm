; =============================================================================
; EXFS - Sistema de Archivos para XOS64
; =============================================================================
[BITS 64]

; Constantes
EXFS_MAGIC equ 'EXFS'

; Estructura SuperBlock
struc EXFS_SuperBlock
    magic           resb 4
    version         resw 1
    total_sectors   resq 1
    free_sectors    resq 1
    xobj_count      resq 1
    root_lba        resq 1
endstruc

exfs_mount:
    mov rsi, msg_mount
    call xk_print
    ret

; Crear objeto (new)
exfs_create:
    ; Implementación básica
    ret

msg_mount db "[EXFS] Volumen montado correctamente.", 10, 0
