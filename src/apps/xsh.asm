bits 16
org 0x7000                  ; Dirección de carga de XSH en Modo Real

xsh_inicio:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x6FFF          ; Pila ubicada justo debajo de XSH
    sti

    ; Limpiar pantalla al iniciar
    mov ax, 0x0003
    int 0x10

.mostrar_prompt:
    ; Verificar si somos superusuario (es_sprusr == 1)
    cmp byte [es_sprusr], 1
    je .prompt_root

    ; Prompt de usuario estándar: &>> 
    mov si, msg_prompt_user
    jmp .imprimir_prompt

.prompt_root:
    ; Prompt de superusuario: >> 
    mov si, msg_prompt_root

.imprimir_prompt:
    call xsh_imprimir_cadena
    
    ; Leer comando de la consola
    call xsh_leer_linea

    ; Verificar comando vacío (Enter directo)
    mov si, buffer_linea
    cmp byte [si], 0
    je .mostrar_prompt

    ; --- EVALUACIÓN DE COMANDOS MODULARES ---
    
    ; 1. Comando: exofetch
    mov si, buffer_linea
    mov di, cmd_exofetch
    call xsh_comparar_cadenas
    je .ejecutar_exofetch

    ; 2. Comando: xdt (Editor de Texto)
    mov si, buffer_linea
    mov di, cmd_xdt
    call xsh_comparar_cadenas
    je .ejecutar_xdt

    ; 3. Comando: xfl (Gestor de Archivos)
    mov si, buffer_linea
    mov di, cmd_xfl
    call xsh_comparar_cadenas
    je .ejecutar_xfl

    ; 4. Comando: sprusr (Elevar privilegios a root)
    mov si, buffer_linea
    mov di, cmd_sprusr
    call xsh_comparar_cadenas
    je .ejecutar_sprusr

    ; 5. Comando: exit_sprusr (Volver a usuario normal)
    mov si, buffer_linea
    mov di, cmd_exit_sprusr
    call xsh_comparar_cadenas
    je .ejecutar_exit_sprusr

    ; Comando no encontrado
    mov si, msg_error_cmd
    call xsh_imprimir_cadena
    jmp .mostrar_prompt

.ejecutar_exofetch:
    call exofetch_main
    jmp .mostrar_prompt

.ejecutar_xdt:
    call xdt_inicio
    jmp .mostrar_prompt

.ejecutar_xfl:
    call xfl_inicio
    jmp .mostrar_prompt

.ejecutar_sprusr:
    mov byte [es_sprusr], 1
    mov si, msg_sprusr_ok
    call xsh_imprimir_cadena
    jmp .mostrar_prompt

.ejecutar_exit_sprusr:
    mov byte [es_sprusr], 0
    jmp .mostrar_prompt

; =============================================================================
; RUTINAS AUXILIARES DE XSH
; =============================================================================
xsh_imprimir_cadena:
    mov ah, 0x0E
.bucle:
    lodsb
    or al, al
    jz .fin
    int 0x10
    jmp .bucle
.fin:
    ret

xsh_leer_linea:
    mov di, buffer_linea
    mov cx, 0              ; Contador de caracteres

.bucle_tecla:
    mov ah, 0x00
    int 0x16               ; Leer tecla (AL = ASCII)

    cmp al, 13             ; Tecla ENTER
    je .fin_lectura

    cmp al, 8              ; Tecla BACKSPACE
    je .borrar_caracter

    cmp cx, 63             ; Límite de búfer (64 bytes)
    jge .bucle_tecla

    ; Guardar carácter e imprimir en pantalla
    stosb
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .bucle_tecla

.borrar_caracter:
    jcxz .bucle_tecla      ; Si el búfer está vacío, ignorar
    dec di
    dec cx
    ; Retroceder cursor en pantalla, imprimir espacio y retroceder de nuevo
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .bucle_tecla

.fin_lectura:
    mov byte [di], 0       ; Terminador nulo
    mov ah, 0x0E
    mov al, 13             ; CR
    int 0x10
    mov al, 10             ; LF
    int 0x10
    ret

xsh_comparar_cadenas:
.bucle_comp:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .diferentes
    or al, al
    jz .iguales
    inc si
    inc di
    jmp .bucle_comp
.diferentes:
    mov ax, 1
    ret
.iguales:
    xor ax, ax
    ret

; =============================================================================
; DATOS Y COMANDOS DE XSH
; =============================================================================
es_sprusr        db 0                   ; Estado: 0 = Usuario, 1 = Root (sprusr)
msg_prompt_user  db "&>> ", 0
msg_prompt_root  db ">> ", 0
msg_error_cmd    db "Comando no reconocido.", 13, 10, 0
msg_sprusr_ok    db "Modo Superusuario (sprusr) activado.", 13, 10, 0

cmd_exofetch     db "exofetch", 0
cmd_xdt          db "xdt", 0
cmd_xfl          db "xfl", 0
cmd_sprusr       db "sprusr", 0
cmd_exit_sprusr  db "exit", 0

buffer_linea     times 64 db 0

; Incluir los módulos de las aplicaciones
%include "src/apps/xsh/exofetch.asm"
%include "src/apps/xdt.asm"
%include "src/apps/xfl.asm"
