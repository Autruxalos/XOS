org 0x100                       ; Formato ejecutable plano de 16 bits (Estilo .COM)
bits 16

%include "src/include/exfs.inc"

xinstaller_inicio:
    ; 1. Limpiar pantalla para la interfaz del instalador
    mov ax, 0x0003
    int 0x10

    mov si, msg_bienvenida
    call impr_cadena

    ; 2. Detectar unidades de almacenamiento disponibles a través de la BIOS
    ; El instalador asume por defecto la unidad de disco actual proporcionada por el sistema
    ; Si se ejecuta desde un disco de rescate, el número de unidad (DL) suele ser 0x80 (Primer HDD/USB)
    mov byte [unidad_destino], 0x80 

    mov si, msg_confirmacion
    call impr_cadena

.esperar_confirmacion:
    mov ah, 0x00
    int 0x16                    ; Esperar pulsación de tecla
    cmp al, 'Y'                 ; Confirmar con 'Y' (Mayúscula)
    je .iniciar_escritura
    cmp al, 'y'                 ; Confirmar con 'y' (Minúscula)
    je .iniciar_escritura
    cmp al, 27                  ; Cancelar con ESC
    je .cancelar
    jmp .esperar_confirmacion

.iniciar_escritura:
    mov si, msg_escribiendo_boot
    call impr_cadena

    ; =============================================================================
    ; FASE 1: ESCRIBIR EL SECTOR DE ARRANQUE (XBOOT - SECTOR LÓGICO 0)
    ; =============================================================================
    mov ax, 0                   ; Sector Lógico 0 (MBR)
    mov cx, 1                   ; Cantidad: 1 sector (512 bytes)
    mov bx, buffer_xboot        ; Dirección en memoria RAM donde está precargado XBOOT
    call disco_escribir_sector
    jc .error_fatal

    ; =============================================================================
    ; FASE 2: ESCRIBIR LA TABLA DE ASIGNACIÓN (XFAT - SECTORES LÓGICOS 1 AL 32)
    ; =============================================================================
    mov si, msg_escribiendo_xfat
    call impr_cadena

    mov ax, 1                   ; Iniciar en Sector Lógico 1
    mov cx, 32                  ; La geometría EXFS reserva 32 sectores para XFAT
    mov bx, buffer_xfat         ; Dirección en memoria RAM de la estructura XFAT
    call disco_escribir_sector
    jc .error_fatal

    ; =============================================================================
    ; FASE 3: ESCRIBIR EL DIRECTORIO RAÍZ (ROOT - SECTORES LÓGICOS 33 AL 64)
    ; =============================================================================
    mov si, msg_escribiendo_root
    call impr_cadena

    mov ax, 33                  ; Iniciar en Sector Lógico 33
    mov cx, 32                  ; Reservar 32 sectores para el Root Directory
    mov bx, buffer_root         ; Dirección en memoria RAM del Directorio Raíz
    call disco_escribir_sector
    jc .error_fatal

    ; =============================================================================
    ; FASE 4: ESCRIBIR EL BLOQUE DE APLICACIONES (DATOS - SECTOR LÓGICO 65+)
    ; =============================================================================
    mov si, msg_escribiendo_apps
    call impr_cadena

    mov ax, 65                  ; Iniciar en Sector Lógico 65 (Área de datos pura)
    mov cx, 64                  ; Escribir el bloque consolidado de aplicaciones (Ajustable)
    mov bx, buffer_datos_apps   
    call disco_escribir_sector
    jc .error_fatal

.instalacion_exitosa:
    mov si, msg_exito
    call impr_cadena
    jmp .terminar

.cancelar:
    mov si, msg_cancelado
    call impr_cadena
    jmp .terminar

.error_fatal:
    mov si, msg_error
    call impr_cadena

.terminar:
    mov si, msg_reiniciar
    call impr_cadena
    mov ah, 0x00
    int 0x16                    ; Esperar tecla final antes de salir
    ret

; =============================================================================
; DRIVER DE ESCRITURA FÍSICA (BIOS INT 13h / AH=03h)
; Entrada: AX = Sector Lógico LBA, CX = Cantidad, BX = Puntero RAM origen
; =============================================================================
disco_escribir_sector:
    push ax
    push bx
    push cx
    push dx

    ; Conversión matemática lineal de LBA a direccionamiento CHS elemental de la BIOS
    mov dx, ax
    mov cx, ax
    shl cx, 6
    and cl, 0x3F
    inc cl                      ; Sector físico final en CL
    
    mov ch, dl
    shr ch, 2                   ; Cilindro físico final en CH
    
    mov dh, dl
    and dh, 0x01                ; Cabeza física final en DH
    
    mov dl, [unidad_destino]    ; Recuperar número de unidad rígida
    mov ax, 0x0301              ; AH=03h (Función Escribir), AL=01h (1 sector por ciclo)
    int 0x13                    ; Llamada de bajo nivel a la controladora

    pop dx
    pop cx
    pop bx
    pop ax
    ret                         ; Retorna con Carry Flag (CF) activo si hubo fallo físico

; =============================================================================
; CONTROL DE CADENAS DE TEXTO
; =============================================================================
impr_cadena:
    mov ah, 0x0E
.bucle:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .bucle
.done:
    ret

; =============================================================================
; TEXTOS INFORMATIVOS DE LA INTERFAZ
; =============================================================================
msg_bienvenida       db "===================================================", 13, 10
                     db "             INSTALADOR NATIVO DE XOS             ", 13, 10
                     db "===================================================", 13, 10, 0
msg_confirmacion     db "ADVERTENCIA: Se sobrescribiran las tablas de arranque.", 13, 10
                     db "Presione 'Y' para comenzar la instalacion o ESC para salir...", 13, 10, 0
msg_escribiendo_boot db " -> Escribiendo Master Boot Record (XBOOT)...", 13, 10, 0
msg_escribiendo_xfat db " -> Configurando sectores de asignacion (XFAT)...", 13, 10, 0
msg_escribiendo_root db " -> Creando estructura del Directorio Raiz...", 13, 10, 0
msg_escribiendo_apps db " -> Volcando binarios del sistema (/src/apps/)...", 13, 10, 0
msg_exito            db 13, 10, "STRICT_SUCCESS: XOS instalado correctamente.", 13, 10, 0
msg_cancelado        db 13, 10, "Instalacion cancelada por el usuario.", 13, 10, 0
msg_error            db 13, 10, "[ERROR FATAL] Fallo de hardware al escribir sectores.", 13, 10, 0
msg_reiniciar        db "Presione cualquier tecla para terminar.", 13, 10, 0

align 2
unidad_destino       db 0

; =============================================================================
; BÚFERES DE MEMORIA VIRTUAL PARA LOS COMPONENTES
; El script de empaquetado final incrustará los binarios compilados aquí
; =============================================================================
align 16
buffer_xboot:
    ; Se reserva espacio o se incluye directamente el binario
    times 512 db 0

buffer_xfat:
    times 32 * 512 db 0         ; 32 sectores limpios para la tabla XFAT

buffer_root:
    times 32 * 512 db 0         ; 32 sectores limpios para las entradas del directorio

buffer_datos_apps:
    ; Aquí es donde se concatenan xsh.xexe, xfl.xexe, xdt.xexe y exofetch.xexe
    times 64 * 512 db 0         ; Espacio de datos para el despliegue inicial
