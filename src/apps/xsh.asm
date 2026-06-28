; =============================================================================
; COMPONENTE: XSH - INTERFAZ DE COMANDOS CRUDA
; =============================================================================
[BITS 64]

xsh_interactive_loop:
.prompt_loop:
    ; Imprimir el formato de prompt requerido: |dir|$
    mov rsi, .msg_pipe
    mov bl, 0x0B                ; Cyan para las tuberías de control
    call xk_print

    mov rsi, exfs_cur_dir_name  ; Variable bss de tu kernel
    mov bl, 0x0F                ; Blanco para el nombre del directorio
    call xk_print

    mov rsi, .msg_prompt_tail
    mov bl, 0x0A                ; Verde para el símbolo de comando
    call xk_print

    ; Leer la línea de comandos usando la rutina nativa del teclado del kernel
    mov rdi, readline_buf
    mov rcx, 64                 ; Máximo 64 caracteres
    call xk_readline

    ; Procesar el comando ingresado
    call xsh_eval_input
    jmp .prompt_loop

.msg_pipe:         db "|", 0
.msg_prompt_tail:  db "|$ ", 0

xsh_eval_input:
    mov rsi, readline_buf
    
    ; Evaluar comando 'make-dir'
    mov rdi, .cmd_mkdir
    call xk_strcmp
    test rax, rax
    jz .trigger_mkdir

    ; Evaluar comando 'pwd'
    mov rdi, .cmd_pwd
    call xk_strcmp
    test rax, rax
    jz .trigger_pwd

    ; Evaluar comando 'halt'
    mov rdi, .cmd_halt
    call xk_strcmp
    test rax, rax
    jz .trigger_halt
    ret

.trigger_mkdir:
    ; Simulación de argumento (En un sistema completo leerías el token posterior)
    mov rsi, .mock_dir_name
    call exfs_create_directory_slot
    ret

.trigger_pwd:
    mov rsi, exfs_cur_dir_name
    mov bl, 0x07
    call xk_println
    ret

.trigger_halt:
    mov rsi, .msg_shutdown
    mov bl, 0x0C                ; Rojo alerta
    call xk_println
    cli \ hlt

.cmd_mkdir:      db "make-dir", 0
.cmd_pwd:        db "pwd", 0
.cmd_halt:       db "halt", 0
.mock_dir_name:  db "NUEVO-DOC", 0
.msg_shutdown:   db "XOS: Apagando procesador...", 0
