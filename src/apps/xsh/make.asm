bits 16

; =============================================================================
; MÓDULO MAKE — Creación de Archivos y Directorios en EXFS
; Ubicación: src/apps/xsh/make.asm
; =============================================================================

cmd_make_main:
    pusha

    ; Verificar si la cadena recibida tiene argumento (espera: "-dir <nombre>" o "-file <nombre>")
    mov si, buffer_argumentos
    call make_saltar_espacios

    cmp byte [si], 0
    je .err_sintaxis

    ; Validar flag "-dir"
    mov di, flag_dir
    call xsh_comparar_cadenas
    je .crear_directorio

    ; Validar flag "-file"
    mov si, buffer_argumentos
    mov di, flag_file
    call xsh_comparar_cadenas
    je .crear_archivo

    jmp .err_sintaxis

.crear_directorio:
    mov byte [tipo_elemento], 1    ; 1 = Directorio
    add si, 5                       ; Avanzar pasado "-dir "
    jmp .procesar_nombre

.crear_archivo:
    mov byte [tipo_elemento], 0    ; 0 = Archivo
    add si, 6                       ; Avanzar pasado "-file "

.procesar_nombre:
    call make_saltar_espacios
    cmp byte [si], 0
    je .err_sintaxis

    ; Buscar entrada libre en la tabla EXFS (RAM 0x9000)
    mov bx, 0x9000
    mov cx, 512                     ; Máximo 512 entradas

.buscar_slot:
    mov al, [bx]
    cmp al, 0x00                    ; ¿Entrada vacía?
    je .slot_encontrado
    cmp al, 0xE5                    ; ¿Entrada libre por borrado?
    je .slot_encontrado

    add bx, 32                      ; Siguiente entrada de 32 bytes
    loop .buscar_slot

    ; Si no hay espacio en la tabla
    mov si, msg_exfs_lleno
    call xsh_imprimir_cadena
    popa
    ret

.slot_encontrado:
    ; Escribir el nombre (hasta 8 caracteres padded con espacios)
    mov di, bx
    mov dx, 8                       ; Máximo 8 bytes para el nombre

.copiar_nombre:
    lodsb
    cmp al, 0
    je .rellenar_espacios
    cmp al, '.'
    je .rellenar_espacios
    cmp al, ' '
    je .rellenar_espacios

    stosb
    dec dx
    jnz .copiar_nombre
    jmp .fin_nombre

.rellenar_espacios:
    mov al, ' '
.loop_pad:
    stosb
    dec dx
    jnz .loop_pad

.fin_nombre:
    ; Si es directorio, extensión "DIR", si no "TXT" (o personalizada)
    cmp byte [tipo_elemento], 1
    je .ext_dir
    
    ; Extensión para archivo normal
    mov byte [bx + 8], 'T'
    mov byte [bx + 9], 'X'
    mov byte [bx + 10], 'T'
    jmp .exito

.ext_dir:
    mov byte [bx + 8], 'D'
    mov byte [bx + 9], 'I'
    mov byte [bx + 10], 'R'

.exito:
    mov si, msg_make_ok
    call xsh_imprimir_cadena
    popa
    ret

.err_sintaxis:
    mov si, msg_make_sintaxis
    call xsh_imprimir_cadena
    popa
    ret

; --- Auxiliar para saltar espacios iniciales ---
make_saltar_espacios:
.loop:
    cmp byte [si], ' '
    jne .fin
    inc si
    jmp .loop
.fin:
    ret

; =============================================================================
; DATOS Y MENSAJES DE MAKE
; =============================================================================
flag_dir          db "-dir", 0
flag_file         db "-file", 0
tipo_elemento     db 0              ; 0 = File, 1 = Dir

msg_make_sintaxis db "Sintaxis: make -dir <nombre> O make -file <nombre>", 13, 10, 0
msg_make_ok       db "[OK] Elemento creado correctamente en EXFS.", 13, 10, 0
msg_exfs_lleno    db "[ERROR] No hay entradas libres en el directorio EXFS.", 13, 10, 0
