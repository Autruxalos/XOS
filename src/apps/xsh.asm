; =============================================================================
; XSH - Shell (sin duplicados)
; =============================================================================
[BITS 16]

xsh_interactive_loop:
    mov si, msg_prompt
    call print_16_kernel   ; Usamos la versión del kernel
    jmp xsh_interactive_loop

msg_prompt db "|$ ", 0
