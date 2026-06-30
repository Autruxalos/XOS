org 0x100                       ; Formato ejecutable estándar de 16 bits
bits 16

%include "src/include/exfs.inc"

xsh_main:
    ; Mostrar banner de bienvenida
    mov si, msg_welcome
    call sys_print

.prompt_loop:
    ; Mostrar el indicador en pantalla (Prompt)
    mov si, msg_prompt
    call sys_print

    ; Leer la entrada del usuario en el buffer
    call sys_read_line

    ; Verificar si el usuario no escribió nada (Enter vacío)
    mov si, buffer_input
    cmp byte [si], 0
    je .prompt_loop

    ; --- ENRUTADOR DE COMANDOS LÓGICOS ---
    
    ; 1. Comando: show-files (Reemplaza a 'ls' o 'dir')
    mov si, buffer_input
    mov di, cmd_show_files
    call sys_compare_string
    jc .ejecutar_xfl

    ; 2. Comando: edit-file (Reemplaza a 'nano' o 'vi')
    mov si, buffer_input
    mov di, cmd_edit_file
    call sys_compare_string
    jc .ejecutar_xdt

    ; 3. Comando: show-info (Ejecuta exofetch)
    mov si, buffer_input
    mov di, cmd_show_info
    call sys_compare_string
    jc .ejecutar_exofetch

    ; 4. Comando: clear-screen (Reemplaza a 'clear' o 'cls')
    mov si, buffer_input
    mov di, cmd_clear
    call sys_compare_string
    jc .ejecutar_clear

    ; Comando no reconocido
    mov si, msg_error_cmd
    call sys_print
    jmp .prompt_loop

; =============================================================================
; SECCIÓN DE EJECUCIÓN DE APLICACIONES COMPATIBLES
; =============================================================================

.ejecutar_xfl:
    ; Llama directamente al Administrador de Archivos mapeado en memoria
    ; Si xfl.xexe está precargado en una dirección conocida, saltamos a ella
    call 0x2000:0x0000          ; Dirección de ejemplo asignada a XFL
    jmp .prompt_loop

.ejecutar_xdt:
    call 0x3000:0x0000          ; Dirección de ejemplo asignada a XDT
    jmp .prompt_loop

.ejecutar_exofetch:
    ; Nota técnica: Tu archivo exofetch.asm actual está marcado como [BITS 64].
    ; Para correrlo desde aquí, necesitarás recompilar la lógica de exofetch 
    ; en 16 bits o usar esta subrutina intermedia si ya migraste el procesador.
    call 0x4000:0x0000          
    jmp .prompt_loop

.ejecutar_clear:
    mov ax, 0x0003              ; Reinicializa el modo de texto VGA limpiando la pantalla
    int 0x10
    jmp .prompt_loop

; =============================================================================
; INFRAESTRUCTURA DE BAJO NIVEL (RUTINAS DE SISTEMA)
; =============================================================================

sys_print:
    mov ah, 0x0E
.bucle:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .bucle
.done:
    ret

sys_read_line:
    mov di, buffer_input
    xor cx, cx                  ; Contador de caracteres ingresados
.bucle_teclado:
    mov ah, 0x00
    int 0x16                    ; Capturar tecla de la BIOS

    cmp al, 13                  ; ¿Es Enter?
    je .linea_terminada

    cmp al, 8                   ; ¿Es Backspace (Borrar)?
    je .procesar_borrado

    cmp cx, 63                  ; Límite máximo del buffer (64 bytes)
    je .bucle_teclado

    ; Almacenar carácter válido y eco en pantalla
    stosb
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .bucle_teclado

.procesar_borrado:
    jcxz .bucle_teclado         ; Si el buffer está vacío, no hacer nada
    dec di
    dec cx
    mov byte [di], 0
    ; Efecto visual de borrado en la terminal
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .bucle_teclado

.linea_terminada:
    mov byte [di], 0            ; Terminar la cadena con cero absoluto
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

sys_compare_string:
    ; Compara las cadenas en SI y DI. Si son iguales, activa el Carry Flag (CF = 1)
.bucle:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .no_iguales
    or al, al                   ; ¿Llegamos al final de la cadena (0)?
    jz .iguales
    inc si
    inc di
    jmp .bucle
.no_iguales:
    clc                         ; Limpiar Carry Flag (No coincide)
    ret
.iguales:
    stc                         ; Activar Carry Flag (Coincidencia exacta)
    ret

; =============================================================================
; SECCIÓN DE TEXTO Y BUFFER RÍGIDO (LÓGICA DESCRIPTIVA)
; =============================================================================
msg_welcome     db "XOS Shell v1.0 - Entorno Bare Metal Con Nombres Logicos", 13, 10, 0
msg_prompt      db "xos_user$ ", 0
msg_error_cmd   db "Error: El comando introducido no existe.", 13, 10, 0

; Diccionario de Comandos del Sistema
cmd_show_files  db "show-files", 0
cmd_edit_file   db "edit-file", 0
cmd_show_info   db "show-info", 0
cmd_clear       db "clear-screen", 0

; Espacio reservado para los comandos futuros que mencionaste (Plantillas)
cmd_make_dir    db "make-dir", 0
cmd_remove_dir  db "remove-dir", 0

align 4
buffer_input    times 64 db 0   ; Buffer estricto de 64 bytes para comandos
