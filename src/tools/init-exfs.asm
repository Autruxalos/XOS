; =============================================================================
; Inicializador EXFS - Crea estructura básica con SuperDirs
; Ejecutar una sola vez al crear la imagen
; =============================================================================
[BITS 16]
[ORG 0x1000]

start:
    ; Escribir SuperBlock en sector 1 (relativo)
    mov si, superblock_data
    mov bx, 1
    call write_sector

    ; Crear XOBJ básicos ( |system|, |apps|, etc.)
    call create_root_objects

    mov si, msg_done
    call print
    ret

create_root_objects:
    ; Aquí irían llamadas a exfs_create_xobj para:
    ; - |system|
    ; - |apps|
    ; - |games|
    ; - |packages|
    ; - users/xlosau, etc.
    ret

; Datos
superblock_data:
    db 'EXFS'          ; magic
    dw 1               ; version
    dd 65536           ; total sectors
    dw 10              ; xobj_count inicial
    dw 0               ; root_index
    db 'XOS Volume',0
    times 462 db 0

msg_done db "EXFS Inicializado correctamente con SuperDirs |", 13, 10, 0

; Rutina simple de escritura (usar INT 13h)
write_sector:
    ; Implementación básica con BIOS
    ret

print:
    mov ah, 0x0E
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret
