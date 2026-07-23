; =============================================================================
; BÚFERES Y PARSER DE ARGUMENTOS DENTRO DE XSH
; =============================================================================

; En la rutina xsh_leer_linea, separaremos la primera palabra (comando)
; del resto del texto (argumentos)

xsh_separar_argumentos:
    mov si, buffer_linea
    mov di, buffer_comando
    mov bp, buffer_argumentos

.copiar_cmd:
    lodsb
    cmp al, ' '
    je .inicio_args
    cmp al, 0
    je .fin_cmd
    stosb
    jmp .copiar_cmd

.fin_cmd:
    mov byte [di], 0
    mov byte [bp], 0
    ret

.inicio_args:
    mov byte [di], 0

.copiar_args:
    lodsb
    mov [bp], al
    inc bp
    cmp al, 0
    jne .copiar_args
    ret

; --- EN EL EVALUADOR DE COMANDOS DE XSH ---
.evaluar_comandos:
    call xsh_separar_argumentos

    ; Evaluar "make"
    mov si, buffer_comando
    mov di, cmd_make
    call xsh_comparar_cadenas
    je .ejecutar_make

    ; Evaluar "remove"
    mov si, buffer_comando
    mov di, cmd_remove
    call xsh_comparar_cadenas
    je .ejecutar_remove

    ; ... (otros comandos: sprusr, exofetch, xdt, xfl, etc.)

.ejecutar_make:
    call cmd_make_main
    jmp .mostrar_prompt

.ejecutar_remove:
    call cmd_remove_main
    jmp .mostrar_prompt

; --- DATOS Y BÚFERES ADICIONALES ---
cmd_make            db "make", 0
cmd_remove          db "remove", 0

buffer_comando     times 32 db 0
buffer_argumentos  times 64 db 0

; --- INCLUSIÓN DE ARCHIVOS DE MÓDULOS ---
%include "src/apps/xsh/sprusr.asm"
%include "src/apps/xsh/make.asm"
%include "src/apps/xsh/remove.asm"
%include "src/apps/exofetch.asm"
%include "src/apps/xdt.asm"
%include "src/apps/xfl.asm"
