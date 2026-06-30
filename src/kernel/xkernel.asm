; =============================================================================
; XKERNEL - EL EXOKERNEL DE XOS (CORREGIDO)
; =============================================================================

; Como el bootloader salta a 0x1000:0x0000, la dirección física base es 0x10000.
; Usamos ORG 0x0000 porque usaremos el segmento CS = 0x1000 para direccionamiento relativo de 16 bits.
org 0x0000
bits 16

fase_16_bits:
    cli                         ; Deshabilitar interrupciones inmediatamente
    
    ; Establecer los segmentos apuntando al segmento de carga del Kernel (0x1000)
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    
    ; Configurar una pila completamente limpia y alejada en 0x0000:0x7C00
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Habilitar la línea A20 (Acceso a memoria extendida)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Calcular la dirección física real de la GDT en base a donde estamos (0x10000)
    ; Para evitar registrar offsets rotos en Modo Real, ajustamos el descriptor dinámicamente:
    mov eax, gdt32_start
    add eax, 0x10000            ; Convertir offset relativo a dirección física de 32 bits
    mov [gdt32_descriptor_fisico + 2], eax

    ; Cargar la GDT usando el descriptor corregido con dirección física real
    lgdt [gdt32_descriptor_fisico]

    ; Activar el bit de Modo Protegido (PE) en CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Salto lejano (Far Jump) usando el selector de código de 32 bits (0x08)
    ; Nota: Como pasamos a modo plano de 32 bits, el offset debe ser la dirección física real (0x10000 + fase_32_bits)
    jmp 0x08:(0x10000 + fase_32_bits)

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
    ; 1. Limpiar el espacio de las tablas (Ubicadas en 0x1000, 0x2000, 0x3000)
    mov edi, 0x1000
    mov cr3, edi                ; CR3 apuntará a la tabla PML4 en 0x1000
    xor eax, eax
    mov ecx, 3072               ; Limpiar 12KB (PML4 + PDPT + PD)
    rep stosd

    ; 2. Enlazar las tablas usando direccionamiento físico base
    mov dword [0x1000], 0x2003  ; PML4Entry[0] -> PDPT (0x2000)
    mov dword [0x2000], 0x3003  ; PDPTEntry[0] -> PageDirectory (0x3000)
    mov dword [0x3000], 0x0083  ; PageDirectoryEntry[0] -> Página gigante de 2MB directa

    ; Activar el bit de PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5              
    mov cr4, eax

    ; Activar el bit de Modo Largo (LME) en el MSR EFER
    mov ecx, 0xC0000080         
    rdmsr
    or eax, 1 << 8              
    wrmsr

    ; Activar la paginación habilitando el bit PG en CR0
    mov eax, cr0
    or eax, 1 << 31             
    mov cr0, eax

    ; Calcular y cargar la GDT de 64 bits con su dirección física real
    mov eax, gdt64_start
    add eax, 0x10000
    mov [gdt64_descriptor_fisico + 2], eax
    lgdt [gdt64_descriptor_fisico]

    ; Salto lejano definitivo al código de 64 bits
    jmp 0x08:(0x10000 + fase_64_bits)

; =============================================================================
; 3. FASE DE MODO LARGO (64 BITS)
; =============================================================================
bits 64
fase_64_bits:
    ; Inicializar selectores de segmento en Modo Largo
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Pintar "XOS" en la esquina superior izquierda de la pantalla de video (0xB8000)
    mov rax, 0x0F4F0F580F4F580F 
    mov qword [0xB8000], rax

.bucle_kernel:
    hlt                         
    jmp .bucle_kernel

; =============================================================================
; ESTRUCTURAS DE DATOS Y TABLAS (GDT)
; =============================================================================

align 4
gdt32_start:
    dd 0, 0                     ; Descriptor nulo
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF ; Código 32 bits (0x08)
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF ; Datos 32 bits (0x10)
gdt32_end:

gdt32_descriptor_fisico:
    dw gdt32_end - gdt32_start - 1
    dd 0                        ; Se rellenará dinámicamente en tiempo de ejecución

align 4
gdt64_start:
    dd 0, 0                     ; Descriptor nulo
    dw 0, 0, 0x9A00, 0x0020     ; Código 64 bits (0x08)
    dw 0, 0, 0x9200, 0x0000     ; Datos 64 bits (0x10)
gdt64_end:

gdt64_descriptor_fisico:
    dw gdt64_end - gdt64_start - 1
    dd 0                        ; Se rellenará dinámicamente en tiempo de ejecución

; =============================================================================
; ¡ELIMINADAS LAS DIRECTIVAS TIMES Y LA FIRMA 0xAA55 DE AQUÍ!
; El Kernel puede medir lo que necesite de manera libre.
; =============================================================================
