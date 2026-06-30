; =============================================================================
; EXFS DRIVER - GESTOR DE RUTAS Y OBJETOS
; =============================================================================
[BITS 64]

; exfs_parse_custom_path
; Convierte una ruta como '|users|root|' aislando los nombres.
; ADVERTENCIA: RSI debe apuntar a un buffer en la RAM (.bss), NO a una 
; constante en .text, ya que esta función modifica la cadena original.
global exfs_parse_custom_path
exfs_parse_custom_path:
    push rsi
    push rax
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, '|'
    jne .loop
    
    ; Sustituir el carácter pipe por un cero binario para delimitar el token
    mov byte [rsi-1], 0
    jmp .loop
.done:
    pop rax
    pop rsi
    ret

; Inyección del comando make-dir
global exfs_create_directory_slot
exfs_create_directory_slot:
    ; Entrada: RSI = Puntero al nombre del nuevo directorio
    ; Preparar los registros para crear el objeto en memoria
    
    mov bl, XOBJ_TYPE_DIR       ; Tipo 1 (Directorio)
    ; call exfs_make_obj        ; (Descomentar cuando implementemos esta función)
    
    ; Simulamos un retorno exitoso temporalmente
    xor rax, rax
    ret
