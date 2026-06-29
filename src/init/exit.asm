; Modulo de inicializacion
global exit_main_executor
exit_main_executor:
    mov qword [exfs_cur_dir_lba], 38
    
    mov rsi, .msg_welcome
    mov bl, 0x0A                ; Texto Verde
    call xk_print
    
    ; Lanzar el bucle principal de la Shell inyectada
    call xsh_interactive_loop
    ret

.msg_welcome: db "XOS: Kernel Modo Largo de 64-Bits Iniciado con Exito.", 10, 0
