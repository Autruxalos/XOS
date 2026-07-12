; =============================================================================
; EXIT - Inicializador Mínimo y Estable
; =============================================================================
[BITS 64]

exit_main_executor:
    ; Mensaje simple en pantalla
    mov rsi, msg_exit
    call xk_print

    ; Llamar a la shell
    call xsh_interactive_loop

    ret

msg_exit db " [EXIT] Sistema inicializado correctamente.", 10, 0
