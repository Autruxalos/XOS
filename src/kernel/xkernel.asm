; =============================================================================
; XKERNEL - CONTROLADOR DE TRANSICIONES Y NÚCLEO DE XOS (16/32/64-bits)
; =============================================================================

[warning -reloc-abs-word]
[warning -reloc-abs-dword]
[warning -reloc-abs-qword]

KERNEL_LOAD_ADDR equ 0x10000
XSH_SEGMENT      equ 0x2000     ; 0x2000:0x0000 en Modo Real mapea a 0x20000 lineal

[BITS 16]
org KERNEL_LOAD_ADDR

_kernel_start:
    ; Configurar selectores de datos para el Modo Real
    mov ax, 0x0000
    mov ds, ax
    
    ; Apuntar ES al segmento de la Shell (0x20000)
    mov ax, XSH_SEGMENT
    mov es, ax
    
    ; Leer el vector de 16 bits de la Shell (está en el offset 0 de su cabecera)
    mov bx, [es:0x0000]
    cmp bx, 0
    je .init_protected_mode      ; Si es 0, saltamos directo a inicializar 32-bits
    
    ; --- EJECUTAR SHELL EN MODO REAL (16-BITS) ---
    push XSH_SEGMENT             ; Push Segmento
    push bx                      ; Push Offset obtenido de la cabecera
    retf                         ; Salto lejano inter-segmento a la Shell 16-bits

.init_protected_mode:
    ; --- TRANSICIÓN A MODO PROTEGIDO (32-BITS) ---
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:_kernel_entry_32     ; Salto lejano clásico para blanquear el pipeline

; =============================================================================
; ⚙️ ENTORNO DE 32-BITS (MODO PROTEGIDO)
; =============================================================================
[BITS 32]
_kernel_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Leer el vector de 32 bits de la Shell (está en la dirección física 0x20002)
    mov edx, [0x20002]
    cmp edx, 0
    je .init_long_mode           ; Si no hay rutina de 32 bits, saltamos a 64-bits
    
    ; --- EJECUTAR SHELL EN MODO PROTEGIDO (32-BITS) ---
    jmp edx                      ; Salto directo absoluto de 32-bits

.init_long_mode:
    ; --- TRANSICIÓN A MODO LARGO (64-BITS) ---
    ; Aquí se inicializaría la paginación de 4 niveles (PML4, PDPT, PD, PT)...
    ; mov eax, cr4 / or eax, 1 << 5 / mov cr4, eax (Activar PAE)
    ; Enlazar tablas... En el modelo real aquí configuras tu EFER MSR y CR0 para Long Mode.
    jmp 0x08:_kernel_entry_64

; =============================================================================
; ⚙️ ENTORNO DE 64-BITS (MODO LARGO NATIVO)
; =============================================================================
[BITS 64]
_kernel_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    
    ; Leer el vector de 64 bits de la Shell (está en la dirección física 0x20006)
    mov rbx, [0x20006]
    
    ; --- EJECUTAR SHELL EN MODO LARGO (64-BITS) ---
    jmp rbx

; =============================================================================
; ESTRUCTURAS DE DATOS GDT
; =============================================================================
align 4
gdt_start:
    dq 0x0000000000000000         ; Descriptor Nulo
gdt_code:
    dq 0x00CF9A000000FFFF         ; Selector de Código Kernel 32-bits (0x08)
gdt_data:
    dq 0x00CF92000000FFFF         ; Selector de Datos Kernel 32-bits (0x10)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
