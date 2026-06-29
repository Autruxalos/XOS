; =============================================================================
; XBOOT — Cargador de Arranque MBR Optimizado y Estabilizado (16-bits Modo Real)
; =============================================================================
[BITS 16]
[ORG 0x7C00]                ; Dirección estándar de carga del MBR en la BIOS

; --- PUNTO DE ENTRADA GENERAL ---
xboot_main:
    cli                     ; Desactivar interrupciones durante la configuración crítica
    xor ax, ax              ; Limpiar registros de segmento a valores seguros (0x0000)
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; Establecer la pila justo debajo del cargador de arranque

    ; Guardar el identificador del disco de arranque entregado por la BIOS
    mov [BOOT_DRIVE], dl

    ; Limpiar la pantalla usando interrupciones de la BIOS
    mov ax, 0x03
    int 0x10

    ; Mostrar mensaje de diagnóstico inicial
    mov si, MSG_LOADING
    call bios_print_string

; --- CARGA DINÁMICA DEL KERNEL DESDE EL DISCO (INT 0x13) ---
load_kernel:
    mov bx, 0x9000          ; ES:BX = 0x0000:0x9000 (Dirección destino del Kernel en RAM)
    
    mov ah, 0x02            ; Función BIOS: Leer sectores del disco
    mov al, 32              ; ¡CRÍTICO! Leer 32 sectores (16 KB) para que el Kernel no se corte
    mov ch, 0x00            ; Cilindro 0
    mov dh, 0x00            ; Cabeza 0
    mov cl, 0x02            ; Empezar en el Sector 2 (El Sector 1 contiene este MBR)
    mov dl, [BOOT_DRIVE]    ; Unidad de almacenamiento origen
    int 0x13                ; Llamar a los servicios de disco de la BIOS
    jc .disk_error          ; Si el flag de acarreo se activa, hubo un fallo físico de lectura

    ; Verificar si efectivamente se leyeron sectores
    cmp al, 0
    jz .disk_error

    ; Mostrar mensaje de éxito en la lectura
    mov si, MSG_LOAD_OK
    call bios_print_string

    ; Saltar directamente al inicio de tu `src/kernel/xkernel.asm` cargado en 0x9000
    jmp 0x0000:0x9000

.disk_error:
    mov si, MSG_ERROR
    call bios_print_string
.halt:
    cli
    hlt
    jmp .halt

; --- RUTINAS AUXILIARES EN MODO REAL ---
bios_print_string:
    push ax
    push bx
    mov ah, 0x0E            ; Modo Teletipo de la BIOS
    xor bh, bh              ; Página de video 0
    mov bl, 0x07            ; Atributo de texto estándar
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    pop bx
    pop ax
    ret

; --- SECCIÓN DE CONSTANTES Y VARIABLES STAGE 1 ---
BOOT_DRIVE:  db 0
MSG_LOADING: db "XOS: Cargando sectores de almacenamiento desde disco...", 13, 10, 0
MSG_LOAD_OK: db "XOS: Kernel mapeado en RAM en offset 0x9000. Saltando...", 13, 10, 0
MSG_ERROR:   db "XOS: CRITICAL BOOT ERROR: Fallo al leer sectores MBR.", 13, 10, 0

; --- FIRMA OBLIGATORIA DE ARRANQUE DE LA BIOS ---
times 510 - ($ - $$) db 0   ; Rellenar con ceros binarios exactos hasta el byte 510
dw 0xAA55                   ; Firma mágica de arranque (Sectores legibles por MBR/BIOS)
