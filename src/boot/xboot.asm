; =============================================================================
; XBOOT - CARGADOR SELECTOR Y CONFIGURADOR DE HARDWARE MULTI-ARQUITECTURA
; =============================================================================

org 0x7C00                      ; Dirección estándar de carga del MBR por la BIOS
bits 16                         ; Iniciamos en Modo Real de 16 bits

_start:
    xor ax, ax                  ; Limpiar registros de segmento
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; Configurar la pila de forma segura por debajo de la BIOS
    mov [boot_drive], dl        ; Guardar el identificador del disco de arranque dado por la BIOS

    ; --- CONTROLADOR DE DISCO: CARGAR EL MONORREPOSITORIO EN RAM ---
    mov ax, 0x1000              ; Dirección Segmento de destino (0x1000:0x0000 -> 0x10000 física)
    mov es, ax
    xor bx, bx                  ; Offset de destino = 0

    mov ah, 0x02                ; Función BIOS: Leer sectores desde el disco
    mov al, 16                  ; ESTABILIZACIÓN: Leer exactamente 16 sectores (8 KB)
    mov ch, 0                   ; Cilindro 0
    mov dh, 0                   ; Cabeza 0
    mov cl, 2                   ; Empezar en el Sector 2 (Sector 1 es el MBR)
    mov dl, [boot_drive]        ; Recuperar el disco de arranque original
    int 0x13                    ; Llamada de interrupción de bajo nivel a la BIOS
    jc disk_error               ; Si el flag de acarreo se activa, falló el hardware

    ; --- INTERROGAR CPU (CPUID) PARA DETECTAR 64-BITS ---
    pushfd                      ; Verificar si la CPU soporta la instrucción CPUID
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jz no_cpuid                 ; Si no cambia el bit 21, no hay CPUID (Procesador antiguo de 32 bits)

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb switch_to_32bit          ; No soporta funciones extendidas, ir a 32 bits

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           ; Verificar el bit de Modo Largo (Long Mode)
    jz switch_to_32bit          ; Si el bit es 0, no soporta 64 bits de forma nativa

    ; --- ENRUTAMIENTO HACIA MODO LARGO (64-BITS) ---
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Activar el bit de Modo Largo en el registro EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Activar Paginación y Modo Protegido simultáneamente
    mov eax, cr0
    or eax, 1 << 31 | 1 << 0
    mov cr0, eax

    lgdt [gdt64_descriptor]     ; Cargar la estructura de la GDT de 64 bits
    jmp 0x08:0x10080            ; SALTO LEJANO CRÍTICO: Kernel, Entry Point de 64 bits

switch_to_32bit:
    ; --- ENRUTAMIENTO HACIA MODO PROTEGIDO (32-BITS) ---
    cli                         ; Deshabilitar interrupciones
    mov eax, cr0
    or eax, 1                   ; Activar el bit de Modo Protegido (PE)
    mov cr0, eax

    lgdt [gdt32_descriptor]     ; Cargar la GDT tradicional de 32-bits
    jmp 0x08:0x10040            ; SALTO LEJANO CRÍTICO: Kernel, Entry Point de 32 bits

disk_error:
no_cpuid:
    hlt                         ; Detener la CPU ante fallos fatales de hardware
    jmp $

; =============================================================================
; ESTRUCTURAS DE HARDWARE (GDTs)
; =============================================================================
align 8
gdt32_start:
    dq 0x0000000000000000       ; Descriptor nulo obligatorio
gdt32_code:
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00
gdt32_data:
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt32_end:

gdt32_descriptor:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start

gdt64_start:
    dq 0x0000000000000000       ; Descriptor nulo obligatorio
gdt64_code:
    dq 0x00209A0000000000       ; Segmento plano de código ejecutable de 64 bits
gdt64_data:
    dq 0x0000920000000000       ; Segmento plano de datos de 64 bits
gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

; --- VARIABLES DE ENTORNO ---
boot_drive db 0x00

; --- FIRMA MÁGICA DEL MBR ---
times 510 - ($ - $$) db 0       ; Relleno de seguridad matemático estricto
dw 0xAA55                       ; Firma de disco arrancable exigida por BIOS
