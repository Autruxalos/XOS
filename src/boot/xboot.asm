org 0x7C00
bits 16

inicio:
    ; 1. Salto largo para forzar CS a 0x0000 (Evita desajustes de direccionamiento de la BIOS)
    jmp 0x0000:.normalizar_entorno

.normalizar_entorno:
    ; 2. Guardar inmediatamente la unidad de arranque entregada por la BIOS en DL
    mov [unidad_arranque], dl

    ; 3. Limpiar registros de segmento para eliminar basura heredada de la BIOS
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; Configurar la pila de forma segura justo debajo del MBR

    ; 4. Activar la Línea A20 mediante la BIOS (Esencial para acceder a memoria extendida)
    mov ax, 0x2401
    int 0x15

    ; 5. Cargar el Exokernel (Sector LBA 65) usando las Extensiones INT 0x13
    mov ah, 0x42            ; Función: Lectura extendida LBA
    mov dl, [unidad_arranque]
    mov si, dap_paquete     ; Puntero al paquete de direccionamiento de disco (DAP)
    int 0x13
    jc .error_boot          ; Si el Carry Flag se activa, hubo un fallo físico de lectura

    ; 6. Salto directo al Exokernel cargado en la dirección física 0x0000:0x8000
    jmp 0x0000:0x8000

.error_boot:
    ; Rutina de emergencia: Imprime una 'E' en pantalla si el disco falla
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
    cli
    hlt
    jmp $                   ; Bucle infinito de protección

# =============================================================================
# ESTRUCTURA DE DATOS: DISK ADDRESS PACKET (DAP)
# =============================================================================
align 4
dap_paquete:
    db 0x10                 ; Tamaño del paquete DAP (Siempre 16 bytes)
    db 0x00                 ; Reservado (Siempre 0)
    dw 40                   ; Cantidad de sectores a leer (Leemos 40 sectores = ~20KB para el kernel)
    dw 0x8000               ; Offset de destino en memoria (Donde se alojará)
    dw 0x0000               ; Segmento de destino en memoria
    dq 65                   ; Sector LBA inicial del Exokernel (Coincide con el sector 65 de tu Makefile)

unidad_arranque: db 0

# =============================================================================
# FIRMA DE ARRANQUE MBR (ESTRICTAMENTE OBLIGATORIA PARA LA BIOS)
# =============================================================================
times 512 - 2 - ($ - $$) db 0
dw 0xAA55
