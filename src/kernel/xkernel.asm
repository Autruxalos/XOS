; =============================================================================
; XKERNEL - CONTROLADOR DE TRANSICIONES Y NÚCLEO DE XOS
; =============================================================================

[warning -reloc-abs-word]
[warning -reloc-abs-dword]
[warning -reloc-abs-qword]

KERNEL_LOAD_ADDR equ 0x10000
XSH_LOAD_ADDR    equ 0x20000

[BITS 16]
org KERNEL_LOAD_ADDR

_kernel_start:
    ; 1. Configurar registros de segmento para Modo Real
    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    
    ; 2. [OPCIÓN A] Saltar directamente a la Shell en Modo Real (16-bit)
    ; Buscamos el vector de 16 bits en la cabecera de XSH
    mov bx, [XSH_LOAD_ADDR]
    cmp bx, 0
    je .init_protected_mode      ; Si no hay shell de 16 bits, vamos a 32 bits
    jmp XSH_LOAD_ADDR            ; Salta a _xsh_entry_16

.init_protected_mode:
    ; 3. Transición a Modo Protegido de 32-bits
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:_kernel_entry_32     ; Salto lejano para limpiar el pipeline

; =============================================================================
; ⚙️ ENTORNO DE 32-BITS (MODO PROTEGIDO)
; =============================================================================
[BITS 32]
_kernel_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Aquí el Kernel puede inicializar drivers de 32 bits si lo deseas...
    
    ; Saltar a la Shell de 32 bits usando el segundo vector de la cabecera
    mov edx, [XSH_LOAD_ADDR + 2]  ; Lee el puntero de 32 bits de XSH
    jmp edx                       ; Salta a _xsh_entry_32

    ; Si quieres ir directo a 64 bits, descomenta la línea de abajo:
    ; jmp _setup_long_mode

_setup_long_mode:
    ; Configuración de Paginación PAE para 64-bits (PML4 -> PDPT -> PD -> PT)
    ; (Aquí construirías tus tablas en memoria, ej: a partir de 0x9000)
    ; ...
    ; Activar Long Mode en EFER y pasar a 64 bits
    jmp 0x08:_kernel_entry_64

; =============================================================================
; ⚙️ ENTORNO DE 64-BITS (MODO LARGO NATIVO)
; =============================================================================
[BITS 64]
_kernel_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    
    ; Saltar a la Shell de 64 bits usando el tercer vector de la cabecera
    mov rbx, [XSH_LOAD_ADDR + 6]  ; Lee el puntero de 64 bits de XSH
    jmp rbx                       ; Salta a _xsh_entry_64

; =============================================================================
; ESTRUCTURAS DE DATOS DEL KERNEL
; =============================================================================
gdt_start:
    dq 0x0000000000000000         ; Descriptor Nulo
gdt_code:
    dq 0x00CF9A000000FFFF         ; Descriptor de Código (Segmento 0x08)
gdt_data:
    dq 0x00CF92000000FFFF         ; Descriptor de Datos (Segmento 0x10)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
