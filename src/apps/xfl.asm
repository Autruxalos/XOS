bits 16

%include "src/include/exfs.inc"

xfl_inicio:
    ; Limpiar pantalla e inicializar cursor
    mov ax, 0x0003              ; Modo de texto 80x25
    int 0x10

    mov si, msg_titulo
    call imprimir_cadena

    ; Supongamos que el Directorio Raíz de EXFS está mapeado en la dirección DS:0x9000
    mov bx, 0x9000
    mov cx, 512                 ; Máximo 512 entradas en EXFS

.bucle_directorio:
    mov al, [bx + DIR_NOMBRE]
    cmp al, 0                   ; ¿Entrada vacía?
    je .siguiente_entrada       ; Si está vacía, saltar
    cmp al, 0xE5                ; ¿Archivo borrado?
    je .siguiente_entrada

    ; Guardar registros para no perder el hilo del bucle
    push cx
    push bx

    ; Imprimir Nombre (8 caracteres)
    mov si, bx
    add si, DIR_NOMBRE
    mov cx, 8
    call imprimir_caracteres_fijos

    ; Imprimir punto
    mov al, '.'
    call imprimir_char

    ; Imprimir Extensión (3 caracteres)
    mov si, bx
    add si, DIR_EXTENSION
    mov cx, 3
    call imprimir_caracteres_fijos

    ; Nueva línea
    mov si, msg_nueva_linea
    call imprimir_cadena

    pop bx
    pop cx

.siguiente_entrada:
    add bx, 32                 ; Avanzar 32 bytes a la siguiente estructura
    loop .bucle_directorio

.fin:
    mov si, msg_pie
    call imprimir_cadena
    
    ; Esperar tecla para salir de regreso al intérprete/kernel
    mov ah, 0x00
    int 0x16
    ret                         ; Salida limpia de la aplicación

; =============================================================================
; RUTINAS AUXILIARES DE TEXTO
; =============================================================================
imprimir_cadena:
    mov ah, 0x0E
.bucle:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .bucle
.done:
    ret

imprimir_caracteres_fijos:
    mov ah, 0x0E
.bucle:
    lodsb
    int 0x10
    loop .bucle
    ret

imprimir_char:
    mov ah, 0x0E
    int 0x10
    ret

; =============================================================================
; DATOS DE INTERFAZ TUI
; =============================================================================
msg_titulo      db "=== XFL: Administrador de Archivos EXFS ===", 13, 10, 0
msg_pie         db 13, 10, "Presione cualquier tecla para salir...", 0
msg_nueva_linea db 13, 10, 0
