bits 16

; =============================================================================
; MÓDULO SPRUSR — Elevación de Privilegios para XOS (Superusuario)
; Ubicación: src/apps/xsh/sprusr.asm
; =============================================================================

sprusr_main:
    pusha

    ; 1. Verificar si el usuario ya es superusuario
    cmp byte [es_sprusr], 1
    je .ya_es_root

    ; 2. Solicitar contraseña
    mov si, msg_prompt_pass
    call xsh_imprimir_cadena

    ; 3. Leer la contraseña del teclado de forma segura (con asteriscos '*')
    call sprusr_leer_password

    ; 4. Comparar la contraseña ingresada con la clave por defecto
    mov si, buffer_pass
    mov di, clave_correcta
    call xsh_comparar_cadenas
    jne .pass_incorrecto

    ; 5. Elevación concedida
    mov byte [es_sprusr], 1
    mov si, msg_exito
    call xsh_imprimir_cadena
    popa
    ret

.ya_es_root:
    mov si, msg_ya_root
    call xsh_imprimir_cadena
    popa
    ret

.pass_incorrecto:
    mov si, msg_error_pass
    call xsh_imprimir_cadena
    popa
    ret

; =============================================================================
; RUTINA DE LECTURA DE CONTRASEÑA EN MODO OCULTO (*)
; =============================================================================
sprusr_leer_password:
    mov di, buffer_pass
    mov cx, 0              ; Contador de longitud

.bucle_key:
    mov ah, 0x00
    int 0x16               ; Leer tecla desde la BIOS (AL = ASCII)

    cmp al, 13             ; Tecla ENTER
    je .fin_pass

    cmp al, 8              ; Tecla BACKSPACE
    je .borrar_pass

    cmp cx, 31             ; Límite de contraseña (32 bytes max)
    jge .bucle_key

    ; Guardar carácter real en buffer y pintar '*' en la pantalla
    stosb
    inc cx
    mov ah, 0x0E
    mov al, '*'
    int 0x10
    jmp .bucle_key

.borrar_pass:
    jcxz .bucle_key        ; Si no hay texto, ignorar
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .bucle_key

.fin_pass:
    mov byte [di], 0       ; Terminador nulo (ASCII 0)
    mov ah, 0x0E
    mov al, 13             ; Nueva línea (CR)
    int 0x10
    mov al, 10             ; Salto de línea (LF)
    int 0x10
    ret

; =============================================================================
; DATOS Y CONFIGURACIÓN DE CREDENCIALES
; =============================================================================
msg_prompt_pass db "Contrasena de sprusr: ", 0
msg_exito       db "[OK] Modo Superusuario activado (>>)", 13, 10, 0
msg_error_pass  db "[ERROR] Contrasena incorrecta.", 13, 10, 0
msg_ya_root     db "Ya tienes privilegios de sprusr (>>).", 13, 10, 0

clave_correcta  db "root", 0         ; Clave por defecto de XOS
buffer_pass     times 32 db 0
