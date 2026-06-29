global exit_main_executor
exit_main_executor:
    ; Inicializaciones críticas
    call xk_init_video
    call xk_init_keyboard
    call exfs_mount   ; Monta en RAM o disco

    mov rsi, welcome_msg
    mov bl, 0x0A
    call xk_print

    call xsh_interactive_loop
    ret

welcome_msg db "XOS EXIT: Sistema inicializado. Bienvenido.", 10, 0
