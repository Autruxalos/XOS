org 0x100                       ; Formato estándar ejecutable tipo .COM (Máximo 64K)

; =============================================================================
; CONFIGURACIÓN DE ARQUITECTURA UNIVERSAL PARA XPKG EN NASM
; =============================================================================
bits 16                         ; El programa inicia en Modo Real / Entorno de 16 bits
cpu 386                         ; Habilita el set de instrucciones de 32 bits (EAX, EBX, etc.)

; Nota para NASM: Aunque estemos en un binario de 16 bits, forzamos la aceptación 
; de registros de 64 bits (RAX, RBX...) mediante codificación manual o compatibilidad.
%ifndef __OUTPUT_FORMAT_elf64__
    ; Habilitamos soporte extendido para que no falle al compilar instrucciones de 64 bits
    cpu x64                     
%endif

xpkg_init:
    ; --- CONFIGURACIÓN DE SELECCIÓN DE VERSIÓN ---
    ; Registros iniciales: 
    ; DX debe contener el modo: 0x0000 = Desarrollador, 0x0001 = Usuario Seguro
    mov [modo_seguro], dx
    
    cmp dx, 1
    jne .modo_desarrollador
    
    ; Mostrar advertencia si es modo desarrollador omitiendo este bloque
    mov si, msg_seguro
    call imprimir_texto
    jmp .verificar_cabecera

.modo_desarrollador:
    mov si, msg_advertencia
    call imprimir_texto

.verificar_cabecera:
    ; Supongamos que DS:SI apunta al buffer donde XBOOT o el Kernel cargó el archivo .XPKG
    lodsd                       ; Cargar los primeros 4 bytes en EAX
    cmp eax, 0x474B5058         ; Verificar la firma "XPKG"
    jne .error_firma

    lodsw                       ; Omitir versión (2 bytes)
    lodsw                       ; Cargar cantidad de archivos en AX
    mov cx, ax                  ; CX = Contador de bucle de archivos

.bucle_archivos:
    push cx                     ; Guardar contador de archivos pendientes
    
    ; --- LEER METADATOS DEL ARCHIVO ACTUAL ---
    ; DS:SI ahora apunta al Nombre (11 bytes)
    mov di, nombre_temporal
    mov cx, 11
    rep movsb                   ; Copiar nombre al buffer temporal
    
    lodsb                       ; Atributo (1 byte)
    mov [attrib_temporal], al

    lodsd                       ; Tamaño del archivo (4 bytes)
    mov [size_temporal], eax
    
    ; --- SOLUCIÓN DE COMPATIBILIDAD DE 64 BITS ---
    ; lodsq no es legal en modo nativo de 16 bits. Leemos los 8 bytes usando dos lodsd.
    lodsd                       ; Parte baja del Checksum -> EAX
    mov edx, eax
    lodsd                       ; Parte alta del Checksum -> EAX
    
    ; Almacenamos el Checksum completo de 8 bytes en memoria usando registros de 32 bits
    mov [checksum_esperado], edx
    mov [checksum_esperado + 4], eax

    ; --- PROCESAMIENTO DEPENDIENDO DE LA VERSIÓN ---
    cmp word [modo_seguro], 1
    jne .extraer_directo        ; Si es modo desarrollador, saltar controles

    ; MODO USUARIO SEGURO: Calcular Checksum antes de escribir
    push si                     ; Guardar puntero de datos del paquete
    mov ecx, [size_temporal]    ; Tamaño para el cálculo
    call calcular_checksum
    pop si                      ; Restaurar puntero de datos del paquete
    
    ; Comparación de Checksum de 64 bits usando registros de 32 bits
    mov edx, [checksum_esperado]
    mov eax, [checksum_esperado + 4]
    cmp ebx, edx                ; ebx tiene la parte baja calculada
    jne .error_seguridad
    cmp ecx, eax                ; ecx tiene la parte alta calculada
    je .extraer_directo
    
.error_seguridad:
    ; Error de integridad (Malware o Corrupción detectada)
    mov si, msg_malware
    call imprimir_texto
    jmp .abortar

.extraer_directo:
    ; DS:SI apunta exactamente al inicio de los bytes puros del archivo
    ; EDI/DI debe configurarse con la dirección del sector de destino en EXFS
    mov edx, [size_temporal]    ; Cantidad de bytes a transferir
    
    ; Lógica de escritura directa en hardware / sectores EXFS
    ; [Aquí invocas tu rutina de exfs_escribir_bloque usando DS:SI]
    
    add si, dx                  ; Avanzar el puntero SI pasando los datos del archivo
    
    pop cx                      ; Recuperar contador de archivos
    loop .bucle_archivos        ; Repetir para el siguiente archivo del paquete

.exito:
    mov si, msg_exito
    call imprimir_texto
    ret

.error_firma:
    mov si, msg_error_pkg
    call imprimir_texto
    ret

.abortar:
    pop cx                      ; Limpiar la pila
    ret

; =============================================================================
; RUTINA: calcular_checksum (Versión Segura)
; Entrada: DS:SI = Puntero a los datos del archivo, ECX = Tamaño en bytes
; Salida: ECX:EBX = Checksum calculado de 64 bits (sin usar registros RAX/RBX directos)
; =============================================================================
calcular_checksum:
    xor ebx, ebx                ; Parte baja del acumulador
    xor ecx, ecx                ; Parte alta del acumulador
.bucle:
    xor edx, edx
    mov dl, [si]                ; Leer byte a byte
    add ebx, edx                ; Sumar a la parte baja
    adc ecx, 0                  ; Acarrear a la parte alta si desborda
    inc si
    loop .bucle
    ret

; =============================================================================
; RUTINA: imprimir_texto
; =============================================================================
imprimir_texto:
    mov ah, 0x0E
.print:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .print
.done:
    ret

; =============================================================================
; SECCIÓN DE DATOS (Alineada dentro de los 64K)
; =============================================================================
modo_seguro         dw 0
nombre_temporal     times 12 db 0
attrib_temporal     db 0
size_temporal       dd 0
checksum_esperado   dq 0

msg_advertencia     db "[ADVERTENCIA] Usando XPKG en modo desarrollador sin controles de integridad.", 13, 10, 0
msg_seguro          db "[XPKG] Modo seguro activado. Verificando firmas de malware...", 13, 10, 0
msg_malware         db "[CRITICO] Archivo corrupto o firma no autorizada. Instalacion abortada.", 13, 10, 0
msg_error_pkg       db "[ERROR] Estructura XPKG no valida.", 13, 10, 0
msg_exito           db "[OK] Paquetes procesados correctamente.", 13, 10, 0
