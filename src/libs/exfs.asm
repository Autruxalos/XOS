; =============================================================================
; COMPONENTE EXFS - GESTOR DE RUTAS NATIVAS '|'
; =============================================================================
[BITS 64]

; exfs_parse_custom_path
; Convierte una ruta como '|users|root|' en parámetros legibles aislados
; Entrada: RSI = Puntero a la cadena de texto de la ruta
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

; Inyección del comando make-dir usando tus estructuras internas del SuperBlock
exfs_create_directory_slot:
    ; Entrada: RSI = Nombre del nuevo directorio
    ; Usa el slot libre mapeado en tu función de asignación exfs_alloc_slot
    mov bl, 1                   ; Tipo: XOBJ_DIR (1)
    call exfs_make_obj
    ret
