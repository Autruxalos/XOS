; =============================================================================
; EXIT — Init del sistema [XSPEC-0005]
; Punto de entrada UNICO llamado por xkernel.asm (kernel_64_entry)
; =============================================================================
[BITS 64]

global exit_main_executor
exit_main_executor:
    call xk_init_keyboard
    call exfs_init

    mov  rsi, welcome_msg
    mov  bl,  0x0A
    call xk_println

    ; xsh_main esta definido en src/apps/xsh.asm y nunca retorna
    ; (su bucle principal es infinito hasta el comando "halt")
    call xsh_main
    ret

welcome_msg: db "XOS EXIT: Sistema inicializado. Bienvenido.", 0
