bits 16

; =============================================================================
; MÓDULO REMOVE — Eliminación de Archivos y Directorios en EXFS
; Ubicación: src/apps/xsh/remove.asm
; =============================================================================

cmd_remove_main:
    pusha

    mov si, buffer_argumentos
    call make_saltar_espacios

    cmp byte [si], 0
    je .err_sintaxis

    ; Validar flag "-dir"
    mov di, flag_dir
    call xsh_comparar_cadenas
    je .preparar_borrado_dir

    ; Validar flag "-file"
    mov si, buffer_argumentos
    mov di, flag_file
    call xsh_comparar_cadenas
    je .preparar_borrado_file

    jmp .err_sintaxis

.preparar_borrado_dir:
    add si, 5
    jmp .buscar_y_eliminar

.preparar_borrado_file:
    add si, 6

.buscar_y_eliminar:
    call make_saltar_espacios
    cmp byte [si], 0
    je .err_sintaxis

    ; Recorrer la tabla de archivos EXFS a partir de 0x9000
    mov bx, 0x9000
    mov cx, 512

.bucle_busqueda:
    mov al, [bx]
    cmp al, 0x00                    ; Fin de entradas ocupadas
    je .no_encontrado
    cmp al, 0xE5                    ; Ya borrado previamente
    je .siguiente_entrada

    ; Comparar primeros caracteres del nombre especificado
    push si
    push bx
    mov di, bx
    mov dx, 8

.comp_nombre:
    mov al, [si]
    cmp al, 0
    je .match_nombre
    cmp al, ' '
    je .match_nombre

    mov ah, [di]
    cmp al, ah
    jne .no_coincide

    inc si
    inc di
    dec dx
    jnz .comp_nombre

.match_nombre:
    pop bx
    pop si
    ; Marcar primer byte de la entrada con 0xE5 (Eliminado en EXFS)
    mov byte [bx], 0xE5
    mov si, msg_remove_ok
    call xsh_imprimir_cadena
    popa
    ret

.no_coincide:
    pop bx
    pop si

.siguiente_entrada:
    add bx, 32                      ; Siguiente registro
    loop .bucle_busqueda

.no_encontrado:
    mov si, msg_no_encontrado
    call xsh_imprimir_cadena
    popa
    ret

.err_sintaxis:
    mov si, msg_remove_sintaxis
    call xsh_imprimir_cadena
    popa
    ret

; =============================================================================
; DATOS Y MENSAJES DE REMOVE
; =============================================================================
msg_remove_sintaxis db "Sintaxis: remove -dir <nombre> O remove -file <nombre>", 13, 10, 0
msg_remove_ok       db "[OK] Elemento eliminado de EXFS.", 13, 10, 0
msg_no_encontrado   db "[ERROR] El elemento no existe en la tabla EXFS.", 13, 10, 0
