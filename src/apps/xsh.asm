; =============================================================================
; XSH - Shell Minimalista (16-bit para compatibilidad inicial)
; =============================================================================
[BITS 16]

xsh_interactive_loop:
    mov si, msg_prompt
    call print_16

    ; Bucle simple (puedes expandir después con lectura de teclado)
    jmp xsh_interactive_loop

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

msg_prompt db "|$ ", 0
