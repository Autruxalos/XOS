; =============================================================================
; MODULE: EXIT (Init / Ejecutor de Entorno Inicial)
; =============================================================================

global exit_main_executor
exit_main_executor:
    ; Sincronizar punteros base del sistema de archivos EXFS
    mov qword [exfs_cur_dir_lba], 38
    
    ; Inicializar buffer de entrada de comandos
    mov rdi, readline_buf
    xor eax, eax
    mov ecx, 32
    rep stosq

    ; Ceder control a la shell
    call xsh_interactive_loop
    ret
