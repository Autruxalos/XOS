; =============================================================================
; MODULE: EXIT (Init / Ejecutor de Entorno Inicial)
; =============================================================================
[BITS 64]

exit_main_executor:
    ; 1. Sincronizar nombres y asegurar que estamos apuntando al LBA raíz
    mov qword [exfs_cur_dir_lba], 38 ; EXFS_DATA_LBA definido en tu data
    
    ; 2. Limpiar el buffer de comandos para evitar basura de memoria
    mov rdi, readline_buf
    xor eax, eax
    mov ecx, 32
    rep stosq

    ; 3. Transferir el control total a la Shell del sistema
    call xsh_interactive_loop

    ; Si la shell retorna (por ejemplo, ejecutan 'halt'), EXIT toma el control del hardware
    cli
.system_deadlock:
    hlt
    jmp .system_deadlock
