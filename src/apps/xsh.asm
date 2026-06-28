; =============================================================================
; XSH — Exokernel Shell con Sintaxis Nativa '|' [XSPEC-0006]
; =============================================================================
[BITS 64]

xsh_interactive_loop:
.prompt_loop:
    ; Imprimir la tubería inicial '|'
    mov rsi, .msg_pipe
    mov bl, 0x0B                ; Color Cyan para el control de rutas
    call xk_print

    ; Imprimir el nombre del directorio actual obtenido de la BSS del kernel
    mov rsi, exfs_cur_dir_name  
    mov bl, 0x0F                ; Blanco para el texto del directorio
    call xk_print

    ; Imprimir el cierre del prompt '|$ '
    mov rsi, .msg_prompt_tail
    mov bl, 0x0A                ; Verde para el indicador de escritura
    call xk_print

    ; Leer entrada cruda desde el búfer de teclado del kernel
    mov rdi, readline_buf
    mov rcx, 64                 
    call xk_readline

    ; Procesar y despachar comandos
    call xsh_eval_input
    jmp .prompt_loop

.msg_pipe:         db "|", 0
.msg_prompt_tail:  db "|$ ", 0

xsh_eval_input:
    mov rsi, readline_buf
    
    ; Evaluar: 'make-dir'
    mov rdi, .cmd_mkdir
    call xk_strcmp
    test rax, rax
    jz .trigger_mkdir

    ; Evaluar: 'pwd'
    mov rdi, .cmd_pwd
    call xk_strcmp
    test rax, rax
    jz .trigger_pwd

    ; Evaluar: 'halt'
    mov rdi, .cmd_halt
    call xk_strcmp
    test rax, rax
    jz .trigger_halt
    ret

.trigger_mkdir:
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
    mov bl, 0x0C                ; Rojo para advertencia de detención
    call xk_println
    cli
.halt_loop:
    hlt
    jmp .halt_loop

.cmd_mkdir:      db "make-dir", 0
.cmd_pwd:        db "pwd", 0
.cmd_halt:       db "halt", 0
.mock_dir_name:  db "NUEVO-DOC", 0
.msg_shutdown:   db "XOS: Deteniendo el procesador de forma segura...", 10, 0

; -----------------------------------------------------------------------------
; Rutina limpia de impresión VGA Texto (0xB8000)
; -----------------------------------------------------------------------------
print:
    movzx rbx, word [cursor_pos]
    shl rbx, 1
    add rbx, 0xB8000
.l: 
    lodsb
    or al, al 
    jz .d
    cmp al, 10 
    je .n
    mov [rbx], al
    mov byte [rbx+1], 0x0F
    add rbx, 2 
    inc word [cursor_pos] 
    jmp .l
.n: 
    add word [cursor_pos], 80 
    jmp .l
.d: 
    ret
