org 0x7C00
bits 16

; =============================================================================
; 1. FASE DE MODO REAL (16 BITS)
; =============================================================================
fase_16_bits:
    cli                         ; Deshabilitar interrupciones inmediatamente
    xor ax, ax                  ; Garantizar segmentos en cero absoluto
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; Ubicar la pila antes del código de arranque

    ; Habilitar la línea A20 (Acceso a memoria extendida) de forma precisa
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Cargar la GDT de 32 bits básica
    lgdt [gdt32_descriptor]

    ; Activar el bit de Modo Protegido (PE) en CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Salto lejano (Far Jump) para limpiar la cola de ejecución del CPU
    jmp 0x08:fase_32_bits

; =============================================================================
; 2. FASE DE MODO PROTEGIDO (32 BITS)
; =============================================================================
bits 32
fase_32_bits:
    ; Recargar registros de datos con el descriptor de datos de 32 bits (0x10)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Preparar las tablas de paginación para el Modo Largo (64 bits)
    ; Mapearemos los primeros 2MB de memoria de forma directa (Identity Mapping)
    
    ; 1. Limpiar el espacio de las tablas (Ubicadas en 0x1000, 0x2000, 0x3000)
    mov edi, 0x1000
    mov cr3, edi                ; CR0 apuntará a la tabla PML4 en 0x1000
    xor eax, eax
    mov ecx, 3072               ; Limpiar 12KB (PML4 + PDPT + PD)
    rep stosd

    ; 2. Enlazar las tablas usando direccionamiento físico base
    ; PML4Entry[0] -> apunta a PDPT (0x2000)
    mov dword [0x1000], 0x2003  ; Presente + Lectura/Escritura
    ; PDPTEntry[0] -> apunta a PageDirectory (0x3000)
    mov dword [0x2000], 0x3003  ; Presente + Lectura/Escritura
    ; PageDirectoryEntry[0] -> Página de 2MB directa
    mov dword [0x3000], 0x0083  ; Presente + Lectura/Escritura + Bit de tamaño gigante (Page Size = 2MB)

    ; Activar el bit de PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5              ; Bit 5 = PAE
    mov cr4, eax

    ; Activar el bit de Modo Largo (LME) en el MSR de características extendidas (EFER)
    mov ecx, 0xC0000080         ; Dirección del MSR EFER
    rdmsr
    or eax, 1 << 8              ; Bit 8 = Long Mode Enable
    wrmsr

    ; Activar la paginación habilitando el bit PG en CR0
    mov eax, cr0
    or eax, 1 << 31             ; Bit 31 = Paging
    mov cr0, eax

    ; Cargar la GDT de 64 bits definitiva
    lgdt [gdt64_descriptor]

    ; Salto lejano definitivo al código de 64 bits
    jmp 0x08:fase_64_bits

; =============================================================================
; 3. FASE DE MODO LARGO (64 BITS)
; =============================================================================
bits 64
fase_64_bits:
    ; Inicializar selectores de segmento en Modo Largo (la mayoría deben ser 0)
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Pintar un carácter indicador en la esquina superior izquierda de la pantalla
    ; Dirección de la memoria de video de texto: 0xB8000
    mov rax, 0x0F4F0F580F4F580F ; Mensaje "XOS" alternado con atributos de color
    mov qword [0xB8000], rax

.bucle_kernel:
    hlt                         ; Detener el procesador de forma segura hasta recibir eventos externos
    jmp .bucle_kernel

; =============================================================================
; ESTRUCTURAS DE DATOS Y TABLAS (GDT)
; =============================================================================

align 4
gdt32_start:
    dd 0, 0                     ; Descriptor nulo
    ; Selector de código 32 bits (0x08): Base=0, Límite=0xFFFFF, Atributos comunes
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF
    ; Selector de datos 32 bits (0x10): Base=0, Límite=0xFFFFF
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF
gdt32_end:

gdt32_descriptor:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start

align 4
gdt64_start:
    dd 0, 0                     ; Descriptor nulo
    ; Selector de código 64 bits (0x08): Atributo de modo largo activo (L=1)
    dw 0, 0, 0x9A00, 0x0020
    ; Selector de datos 64 bits (0x10)
    dw 0, 0, 0x9200, 0x0000
gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

; Firma de arranque obligatoria para el sector 0 del disco
times 510-($-$$) db 0
dw 0xAA55
