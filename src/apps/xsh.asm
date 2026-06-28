; =============================================================================
; XSH - SHELL INTERACTIVA MULTI-ARQUITECTURA (ENTORNO NATIVO DE 64-BITS)
; =============================================================================

bits 64                         ; Asegura la generación de opcodes de 64-bits

_shell_start:
    ; Configurar un offset inicial para el cursor en la memoria de video VGA.
    ; Usamos 480 (Línea 6, Columna 0) para no sobreescribir los mensajes del Kernel.
    mov word [cursor_offset], 480

    ; Mostrar el prompt de bienvenida inicial
    mov rsi, prompt_msg
    call print_string

shell_loop:
    ; --- 1. POLLING DEL CONTROLADOR DE TECLADO ---
    in al, 0x64                 ; Leer el registro de estado del Status Register (Puerto 0x64)
    test al, 1                  ; Verificar el Bit 0 (Output Buffer Full)
    jz shell_loop               ; Si es 0, no hay tecla disponible; seguir esperando

    ; --- 2. LEER EL SCAN CODE REAL ---
    in al, 0x60                 ; Leer el byte de la tecla presionada (Puerto 0x60)

    ; Ignorar los "Break Codes" (cuando se suelta una tecla, el bit 7 está en 1)
    test al, 0x80
    jnz shell_loop              ; Si se soltó la tecla, ignorar y continuar el bucle

    ; --- 3. FILTRADO DE TECLAS ESPECIALES ---
    cmp al, 0x1C                ; Scan Code de la tecla ENTER
    je handle_enter

    cmp al, 0x0E                ; Scan Code de la tecla BACKSPACE
    je handle_backspace

    cmp al, 0x39                ; Scan Code de la barra ESPACIADORA
    je handle_space

    ; --- 4. TRADUCCIÓN A ASCII MEDIANTE TABLA ---
    cmp al, 0x3A                ; Limitar la lectura a nuestra tabla básica de caracteres
    ja shell_loop               ; Si el Scan Code supera el mapa, ignorar

    movzx rbx, al
    lea rdi, [scan_to_ascii]
    mov al, [rdi + rbx]         ; Buscar el carácter ASCII correspondiente
    cmp al, 0                   ; Si da 0, es una tecla no mapeada (como Shift o Ctrl)
    je shell_loop

echo_character:
    call print_char             ; Pintar el carácter ASCII en pantalla
    jmp shell_loop              ; Volver al bucle de escucha

; --- MANEJADORES DE TECLAS ESPECIALES ---

handle_enter:
    call next_line              ; Saltar de línea en la pantalla VGA
    mov rsi, prompt_msg
    call print_string           ; Volver a imprimir la línea de comandos
    jmp shell_loop

handle_backspace:
    call do_backspace           ; Retroceder y borrar el carácter físico
    jmp shell_loop

handle_space:
    mov al, ' '
    call print_char             ; Imprimir espacio en blanco común
    jmp shell_loop

; =============================================================================
; SUBRUTINAS DE VIDEO VGA NATIVAS DE 64-BITS (Dirección Física: 0xB8000)
; =============================================================================

print_string:
    ; Imprime cadenas de texto terminadas en byte 0. Puntero origen en RSI.
.loop:
    lodsb                       ; Carga el byte de [RSI] en AL e incrementa RSI
    cmp al, 0
    je .done
    call print_char
    jmp .loop
.done:
    ret

print_char:
    ; Imprime un único carácter contenido en AL en la posición actual del cursor.
    push rbx
    movzx rbx, word [cursor_offset]
    shl rbx, 1                  ; Multiplicar por 2 (Cada celda VGA ocupa 2 bytes)
    add rbx, 0xB8000            ; Base de la memoria de video de texto

    mov [rbx], al               ; Escribir el carácter ASCII
    mov byte [rbx+1], 0x0E      ; Atributo de color: Texto Amarillo, Fondo Negro

    inc word [cursor_offset]    ; Avanzar la posición del cursor global
    cmp word [cursor_offset], 2000 ; Evitar desbordar los límites de la pantalla (80x25)
    jb .end
    mov word [cursor_offset], 0 ; Reiniciar arriba si la pantalla se llena
.end:
    pop rbx
    ret

next_line:
    ; Calcula de forma matemática el inicio de la siguiente fila (múltiplos de 80)
    push rax
    push rbx
    push rdx

    movzx rax, word [cursor_offset]
    mov rbx, 80
    xor rdx, rdx
    div rbx                     ; RAX = Fila actual, RDX = Columna actual
    
    inc rax                     ; Avanzar a la siguiente fila entera
    cmp rax, 25                 ; Si excede las 25 líneas, resetear a la parte superior
    jb .matrix_ok
    xor rax, rax
.matrix_ok:
    mul rbx                     ; RAX = Siguiente Fila * 80 columnas
    mov [cursor_offset], ax     ; Guardar nueva posición base

    pop rdx
    pop rbx
    pop rax
    ret

do_backspace:
    ; Lógica segura de borrado físico en pantalla
    push rbx
    movzx rbx, word [cursor_offset]
    cmp rbx, 480                ; Restricción: No permitas borrar el texto del prompt original
    jbe .blocked
    
    dec rbx                     ; Retroceder una celda interna
    mov [cursor_offset], bx
    
    shl rbx, 1
    add rbx, 0xB8000
    mov byte [rbx], ' '         ; Sustituir el carácter viejo por un espacio vacío
    mov byte [rbx+1], 0x0E      ; Mantener el atributo visual estable
.blocked:
    pop rbx
    ret

; =============================================================================
; SECCIÓN DE DATOS Y MAPEO DE HARDWARE (SET 1 SCAN CODES)
; =============================================================================

section .data

cursor_offset dw 0              ; Variable para rastrear la celda VGA activa
prompt_msg    db "Autruxalos@XOS_64bit:/$ ", 0

; Tabla de traducción directa: Índice = Scan Code de Hardware -> Valor = ASCII
scan_to_ascii:
    db 0,  0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,  0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0,  0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
