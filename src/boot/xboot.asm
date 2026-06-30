; =============================================================================
; XBOOT — Cargador de Arranque MBR Profesional en Modo LBA (16-bits Modo Real)
; =============================================================================
[BITS 16]
[ORG 0x7C00]                ; Dirección estándar de carga del MBR por la BIOS

xboot_main:
    ; --- BLINDAJE INICIAL DE ENTORNOS ---
    cli                     ; Desactivar interrupciones durante la fase crítica
    xor ax, ax              ; Limpiar registros de segmento a 0x0000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; Pila segura creciendo hacia abajo desde el MBR

    ; Guardar el identificador de la unidad de arranque entregado por la BIOS
    mov [BOOT_DRIVE], dl

    ; Limpiar pantalla (Video Modo 3 estándar)
    mov ax, 0x0003
    int 0x10

    ; Mostrar mensaje inicial
    mov si, MSG_BOOT
    call bios_print

; --- COMPROBACIÓN DE EXTENSIONES LBA ---
check_lba_extensions:
    mov ah, 0x41            ; Función: Verificar extensiones de la BIOS
    mov bx, 0x55AA          ; Valor mágico de prueba
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc .no_lba              ; Si el Flag de Acarreo (CF) se activa, no hay soporte LBA
    cmp bx, 0xAA55          ; Verificar si el valor mágico regresó invertido
    jne .no_lba
    
    ; Mostrar confirmación de Modo LBA
    mov si, MSG_LBA
    call bios_print
    jmp load_kernel_lba

.no_lba:
    mov si, MSG_ERR_LBA
    call bios_print
    jmp fault_halt

; --- CARGA DEL KERNEL MEDIANTE EXTENSIONES INT 0x13 ---
load_kernel_lba:
    mov ah, 0x42            ; Función BIOS: Lectura extendida del disco LBA
    mov dl, [BOOT_DRIVE]
    mov si, disk_packet     ; DS:SI debe apuntar a la estructura DAP
    int 0x13
    jc .disk_error          ; Si falla la lectura física, saltar al manejador de errores

    ; Confirmación de carga exitosa
    mov si, MSG_LOADED
    call bios_print

    ; --- EL SALTO MAESTRO AL KERNEL ---
    ; Se realiza un salto lejano (Far Jump) para inicializar CS a 0x0000 y saltar a 0x9000
    jmp 0x0000:0x9000

.disk_error:
    mov si, MSG_ERR_DISK
    call bios_print
    jmp fault_halt

; --- RUTINAS AUXILIARES ---
fault_halt:
    mov si, MSG_HALT
    call bios_print
.loop:
    cli
    hlt                     ; Detener el procesador de forma permanente
    jmp .loop

bios_print:
    push ax
    push bx
    mov ah, 0x0E            ; Servicio de Teletipo de la BIOS
    xor bh, bh              ; Página de video 0
    mov bl, 0x07            ; Atributo de texto estándar (Gris/Blanco)
.print_loop:
    lodsb                   ; Carga el byte apuntado por DS:SI en AL e incrementa SI
    test al, al             ; ¿Es el fin de la cadena (byte 0)?
    jz .print_done
    int 0x10                ; Llamar a la interrupción de video de la BIOS
    jmp .print_loop
.print_done:
    pop bx
    pop ax
    ret

; =============================================================================
; ESTRUCTURA FÍSICA: DISK ADDRESS PACKET (DAP)
; =============================================================================
align 4
disk_packet:
    db 0x10                 ; Tamaño del paquete DAP (Siempre 16 bytes o 0x10)
    db 0x00                 ; Reservado (Siempre 0)
    dw 32                   ; ¡CRÍTICO! Número de sectores a leer (32 sectores = 16 KB)
    dw 0x9000               ; Offset de destino en la memoria RAM
    dw 0x0000               ; Segmento de destino en la memoria RAM (0x0000:0x9000)
    dq 1                    ; LBA Inicial: Empezar en el Sector 1 (El Sector 0 es este MBR)

; =============================================================================
; SECCIÓN DE CADENAS DE TEXTO (DATOS DE CONTROL)
; =============================================================================
BOOT_DRIVE:   db 0
MSG_BOOT:     db "XOS Boot - Cargando...", 13, 10, 0
MSG_LBA:      db "Modo LBA detectado.", 13, 10, 0
MSG_LOADED:   db "Kernel cargado! Saltando...", 13, 10, 0
MSG_ERR_LBA:  db "ERROR: La BIOS no soporta extensiones LBA nativas.", 13, 10, 0
MSG_ERR_DISK: db "ERROR: Fallo critico en la lectura fisica de sectores.", 13, 10, 0
MSG_HALT:     db "Sistema detenido de forma segura.", 13, 10, 0

; --- FIRMA OBLIGATORIA DE ARRANQUE MBR MÁGICA ---
times 510 - ($ - $$) db 0   ; Rellenar con ceros exactos hasta el byte 510
dw 0xAA55                   ; Firma de arranque ejecutable por la BIOS
