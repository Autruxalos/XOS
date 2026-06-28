; =============================================================================
; XSH16 - SHELL INTERACTIVA NATIVA DE 16-BITS (MODO REAL / 8086)
; =============================================================================
[BITS 16]

_shell_start_16:
    ; Sincronizar segmentos de datos para Modo Real seguro
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; Cursor en la línea 6 (480 celdas de texto)
    mov word [cursor_offset], 480

    ; Mostrar prompt
    mov si, prompt_msg
    call print_string

shell_loop:
    ; Polling del controlador de teclado (Puerto de Estado 0x64)
    in al, 0x64
    test al, 1
    jz shell_loop               ; Esperar si el buffer está vacío

    ; Leer Scan Code (Puerto de Datos 0x60)
    in al, 0x60
    test al, 0x80
    jnz shell_loop              ; Ignorar si es un Break Code (soltar tecla)

    ; Teclas de control
    cmp al, 0x1C                ; ENTER
    je handle_enter
    cmp al, 0x0E                ; BACKSPACE
    je handle_backspace
    cmp al, 0x39                ; ESPACIO
    je handle_space
    cmp al, 0x3A                
    ja shell_loop               ; Ignorar si se sale del mapa básico

    ; Traducir Scan Code a ASCII
    mov bx, ax
    xor bh, bh                  ; Limpiar BH para usar BX como índice limpio
    mov al, [scan_to_ascii + bx]
    cmp al, 0
    je shell_loop

echo_character:
    call print_char
    jmp shell_loop

handle_enter:
    call next_line
    mov si, prompt_msg
    call print_string
    jmp shell_loop

handle_backspace:
    call do_backspace
    jmp shell_loop

handle_space:
    mov al, ' '
    call print_char
    jmp shell_loop

; --- SUBRUTINAS ---

print_string:
.loop:
    lodsb                       ; Carga [SI] en AL e incrementa SI
    cmp al, 0
    je .done
    call print_char
    jmp .loop
.done:
    ret

print_char:
    push bx
    push es
    mov bx, 0xB800              ; Segmento base de texto VGA en 16-bits
    mov es, bx
    mov bx, [cursor_offset]
    shl bx, 1                   ; Multiplicar por 2 (Carácter + Atributo)
    
    mov byte [es:bx], al        ; Carácter ASCII
    mov byte [es:bx+1], 0x0E    ; Color: Amarillo Brillante
    
    inc word [cursor_offset]
    cmp word [cursor_offset], 2000
    jb .end
    mov word [cursor_offset], 0
.end:
    pop es
    pop bx
    ret

next_line:
    push ax
    push bx
    push dx
    mov ax, [cursor_offset]
    mov bx, 80
    xor dx, dx
    div bx                      ; AX = Fila actual
    inc ax                      ; Avanzar fila
    cmp ax, 25
    jb .ok
    xor ax, ax
.ok:
    mul bx
    mov [cursor_offset], ax
    pop dx
    pop bx
    pop ax
    ret

do_backspace:
    push bx
    push es
    mov bx, [cursor_offset]
    cmp bx, 480
    jbe .blocked
    dec bx
    mov [cursor_offset], bx
    shl bx, 1
    mov ax, 0xB800
    mov es, ax
    mov byte [es:bx], ' '       ; Borrar visualmente
    mov byte [es:bx+1], 0x0E
.blocked:
    pop es
    pop bx
    ret

; --- DATOS ---
cursor_offset dw 0
prompt_msg    db "XOS_16bit:/$ ", 0

scan_to_ascii:
    db 0,  0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,  0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0,  0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
