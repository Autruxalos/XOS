org 0x100
bits 16

xdt_inicio:
    ; Configurar modo de texto y limpiar pantalla
    mov ax, 0x0003
    int 0x10

    ; Pintar barra de estado superior estilo nano
    mov si, msg_banner
    call xdt_imprimir_barra

    ; Ubicar el cursor en la línea 2, columna 0 para empezar a escribir
    mov ah, 0x02
    mov bh, 0                    ; Página de video 0
    mov dh, 1                    ; Fila 1 (segunda línea)
    mov dl, 0                    ; Columna 0
    int 0x10

.bucle_editor:
    ; Leer carácter del teclado (Bloqueante)
    mov ah, 0x00
    int 0x16                    ; Devuelve ASCII en AL, ScanCode en AH

    cmp al, 27                  ; ¿Es la tecla ESC?
    je .salir

    cmp al, 13                  ; ¿Es ENTER?
    je .procesar_enter

    ; Imprimir el carácter en pantalla de forma normal
    mov ah, 0x0E
    int 0x10
    jmp .bucle_editor

.procesar_enter:
    ; Retorno de carro y salto de línea manual para mantener consistencia
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    jmp .bucle_editor

.salir:
    ; Limpiar pantalla antes de devolver el control
    mov ax, 0x0003
    int 0x10
    ret

; =============================================================================
; RUTINAS DE TEXTO PARA XDT
; =============================================================================
xdt_imprimir_barra:
    ; Imprime texto con atributos de color invertido (Negro sobre Gris/Blanco)
    mov ah, 0x09
    mov bh, 0
    mov cx, 80                  ; Pintar fondo en toda la línea horizontal
    mov bl, 0x70                ; Atributo: Fondo gris, letras negras
    mov al, ' '
    int 0x10

    ; Escribir el texto encima de la barra pintada
    mov ah, 0x0E
.bucle:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .bucle
.done:
    ret

msg_banner db " XDT v1.0 - Editor Minimalista  |  Presione ESC para Salir", 0
