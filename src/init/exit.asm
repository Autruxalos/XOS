[BITS 16]
exit_main_executor:
    mov si, msg
    call print_16
    ; Llamar a XSH en 16-bit
    jmp xsh_interactive_loop

msg db "EXIT OK", 13, 10, 0
