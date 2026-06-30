org 0x100                       ; Formato ejecutable plano de 16 bits (Estilo .COM)
bits 16

; Cambia la ruta rota por la ruta raíz correcta:
%include "src/include/exfs.inc"

xinstaller_inicio:
    ; 1. Limpiar pantalla para la interfaz del instalador
    mov ax, 0x0003
    int 0x10

    mov si, msg_bienvenida
    call impr_cadena

    ; 2. Configurar la unidad física destino (0x80 = Primer HDD/USB en BIOS)
    mov byte [unidad_destino], 0x80 

    mov si, msg_confirmacion
    call impr_cadena

.esperar_confirmacion:
    mov ah, 0x00
    int 0x16                    ; Capturar entrada de teclado
    cmp al, 'Y'                 ; Validar confirmación
    je .iniciar_escritura
    cmp al, 'y'
    je .iniciar_escritura
    cmp al, 27                  ; Tecla ESC aborta la operación
    je .cancelar
    jmp .esperar_confirmacion

.iniciar_escritura:
    mov si, msg_escribiendo_boot
    call impr_cadena

    ; =============================================================================
    ; FASE 1: VOLCAR SECTOR DE ARRANQUE COMPATIBLE (XBOOT - LBA SECTOR 0)
    ; =============================================================================
    mov ax, 0                   ; Sector Lógico LBA 0
    mov cl, 1                   ; 1 sector de tamaño (512 bytes)
    mov bx, buffer_xboot        ; Ubicación del MBR en la RAM
    call disco_escribir_sector
    jc .error_fatal

    ; =============================================================================
    ; FASE 2: VOLCAR LA TABLA DE ASIGNACIÓN (XFAT - LBA SECTORES 1 AL 32)
    ; =============================================================================
    mov si, msg_escribiendo_xfat
    call impr_cadena

    mov ax, 1                   ; Iniciar en LBA 1
    mov cl, 32                  ; Volcar los 32 sectores dedicados
    mov bx, buffer_xfat         
    call disco_escribir_sector
    jc .error_fatal

    ; =============================================================================
    ; FASE 3: VOLCAR EL DIRECTORIO RAÍZ (ROOT - LBA SECTORES 33 AL 64)
    ; =============================================================================
    mov si, msg_escribiendo_root
    call impr_cadena

    mov ax, 33                  ; Iniciar en LBA 33
    mov cl, 32                  ; Volcar los 32 sectores del directorio
    mov bx, buffer_root         
    call disco_escribir_sector
    jc .error_fatal

    ; =============================================================================
    ; FASE 4: VOLCAR APLICACIONES CONSOLIDADAS (DATA - LBA SECTOR 65+)
    ; =============================================================================
    mov si, msg_escribiendo_apps
    call impr_cadena

    mov ax, 65                  ; Iniciar en LBA 65 (Inicio área de datos EXFS)
    mov cl, 64                  ; Volcar bloque de aplicaciones (Ajustable)
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
    int 0x16                    ; Pausa final
    ret

; =============================================================================
; DRIVER DE ESCRITURA FÍSICA LBA EXCLUSIVO PARA HARDWARE REAL
; Entrada: AX = Sector Lógico LBA, CL = Cantidad, BX = Puntero RAM origen (DS)
; =============================================================================
disco_escribir_sector:
    pusha                       ; Resguardar el mapa completo de registros

    ; Rellenar el paquete DAP de escritura
    mov [inst_dap_sector], ax
    mov [inst_dap_cantidad], cl
    mov [inst_dap_offset], bx
    mov [inst_dap_segment], ds  ; El instalador asume segmento DS como base

    mov si, inst_dap_packet     ; DS:SI apunta a la estructura DAP de escritura
    mov dl, [unidad_destino]    ; Unidad de destino (0x80)
    mov ah, 0x43                ; Función BIOS: Escritura LBA Extendida
    mov al, 0x00                ; Flag de verificación por defecto
    int 0x13                    ; Llamada nativa a la controladora

    popa                        ; Restaurar registros de forma simétrica
    ret                         ; Si falla, la BIOS activa automáticamente el Carry Flag (CF)

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
                     db "        INSTALADOR NATIVO LBA COMPATIBLE XOS       ", 13, 10
                     db "===================================================", 13, 10, 0
msg_confirmacion     db "ADVERTENCIA: Se sobreescribiran las tablas de arranque.", 13, 10
                     db "Presione 'Y' para comenzar la instalacion o ESC para salir...", 13, 10, 0
msg_escribiendo_boot db " -> Escribiendo Master Boot Record Inteligente (XBOOT)...", 13, 10, 0
msg_escribiendo_xfat db " -> Configurando sectores de asignacion por bloques (XFAT)...", 13, 10, 0
msg_escribiendo_root db " -> Creando estructura del Directorio Raiz EXFS...", 13, 10, 0
msg_escribiendo_apps db " -> Volcando binarios del sistema (/src/apps/)...", 13, 10, 0
msg_exito            db 13, 10, "STRICT_SUCCESS: XOS instalado correctamente.", 13, 10, 0
msg_cancelado        db 13, 10, "Instalacion cancelada por el usuario.", 13, 10, 0
msg_error            db 13, 10, "[ERROR FATAL] La BIOS rechazo la escritura LBA Extendida.", 13, 10, 0
msg_reiniciar        db "Presione cualquier tecla para terminar.", 13, 10, 0

align 2
unidad_destino       db 0

; =============================================================================
; ESTRUCTURA RÍGIDA: PAQUETE DAP DE ESCRITURA (16 Bytes Fijos)
; =============================================================================
align 4
inst_dap_packet:
    inst_dap_tamano     db 16   ; Tamaño fijo
                        db 0    ; Reservado
    inst_dap_cantidad   dw 0    ; Cantidad de sectores
    inst_dap_offset     dw 0    ; RAM Offset
    inst_dap_segment    dw 0    ; RAM Segmento
    inst_dap_sector     dd 0    ; LBA Destino Bajo
                        dd 0    ; LBA Destino Alto

; =============================================================================
; RESERVA DE BUFFER DE TRANSFERENCIA EN RAM
; =============================================================================
align 16
buffer_xboot:
    times 512 db 0              ; Inyección de XBOOT resultante

buffer_xfat:
    times 32 * 512 db 0         ; 32 sectores de mapeo base

buffer_root:
    times 32 * 512 db 0         ; 32 sectores para las estructuras de entradas

buffer_datos_apps:
    times 64 * 512 db 0         ; Concatenación física de xsh, xdt, xfl y exofetch
