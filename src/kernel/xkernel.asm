; =============================================================================
; XKERNEL - Versión de Prueba (Minimalista)
; =============================================================================
org 0x9000

[BITS 16]
kernel_16_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov si, msg_loaded
    call print_16

    ; Salto directo a código simple sin transición compleja por ahora
    jmp kernel_simple

print_16:
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    ret

msg_loaded db 'Kernel cargado! Entrando en XOS...', 13, 10, 0

kernel_simple:
    mov si, msg_xos
    call print_16

.halt:
    cli
    hlt
    jmp .halt

msg_xos db 'XOS iniciado correctamente.', 13, 10, 0

; Firma para que NASM no se queje (aunque no es MBR)
times 510 - ($ - $$) db 0
dw 0xAA55
