; Modulo de inicializacion
global exit_main_executor
exit_main_executor:
    mov qword [exfs_cur_dir_lba], 38
    
    ; Intentar mandar un mensaje de control para ver si la CPU sigue viva
    mov rsi, .msg_welcome
    mov bl, 0x0A                ; Texto Verde
    call xk_print
    
    ; Si tienes la shell lista, descomenta la siguiente linea:
    ; call xsh_interactive_loop
    ret

.msg_welcome: db "XOS: Kernel Modo Largo de 64-Bits Iniciado con Exito.", 10, 0
