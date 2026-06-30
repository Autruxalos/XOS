org 0x100                       ; Formato ejecutable estándar de 16 bits
bits 16

; Modificación de ruta relativa para la nueva estructura modular
%include "../include/exfs.inc"

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

    ; =============================================================================
    ; ENRUTADOR DE COMANDOS LÓGICOS DESCRIPTIVOS
    ; =============================================================================
    
    ; 1. Comando: show-files (Lista el directorio)
    mov si, buffer_input
    mov di, cmd_show_files
    call sys_compare_string
    jc .ejecutar_xfl

    ; 2. Comando: edit-file (Abre el editor de texto nativo)
    mov si, buffer_input
    mov di, cmd_edit_file
    call sys_compare_string
    jc .ejecutar_xdt

    ; 3. Comando: show-info (Ejecuta el visor de especificaciones del sistema)
    mov si, buffer_input
    mov di, cmd_show_info
    call sys_compare_string
    jc .ejecutar_exofetch

    ; 4. Comando: clear-screen (Limpia la terminal actual)
    mov si, buffer_input
    mov di, cmd_clear
    call sys_compare_string
    jc .ejecutar_clear

    ; Comando no reconocido
    mov si, msg_error_cmd
    call sys_print
    jmp .prompt_loop

; =============================================================================
; MANEJADORES DE SALTOS MECÁNICOS DIRECTOS
; =============================================================================

.ejecutar_xfl:
    call 0x2000:0x0000          ; Dirección de segmento asignada a XFL
    jmp .prompt_loop

.ejecutar_xdt:
    call 0x3000:0x0000          ; Dirección de segmento asignada a XDT
    jmp .prompt_loop

.ejecutar_exofetch:
    call 0x4000:0x0000          ; Dirección de segmento asignada a EXOFETCH
    jmp .prompt_loop

.ejecutar_clear:
    mov ax, 0x0003              ; Reinicializa el modo de texto VGA limpiando pantalla
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
    jcxz .bucle_teclado         ; Si el buffer está vacío, omitir accion
    dec di
    dec cx
    mov byte [di], 0
    ; Efecto visual de retroceso físico en pantalla de texto
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
    ; Compara las cadenas en SI y DI. Si coinciden, activa el Carry Flag (CF = 1)
.bucle:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .no_iguales
    or al, al                   ; ¿Final de cadena?
    jz .iguales
    inc si
    inc di
    jmp .bucle
.no_iguales:
    clc                         ; Limpiar Carry Flag
    ret
.iguales:
    stc                         ; Activar Carry Flag
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

; Reservas semánticas futuras
cmd_make_dir    db "make-dir", 0
cmd_remove_dir  db "remove-dir", 0

align 4
buffer_input    times 64 db 0   ; Buffer rígido de 64 bytes para entrada limpia
