; =============================================================================
; XKERNEL - NÚCLEO CENTRAL DE INICIALIZACIÓN MULTI-MODO (XOS)
; =============================================================================

[warning -reloc-abs-word]
[warning -reloc-abs-dword]
[warning -reloc-abs-qword]

KERNEL_LOAD_ADDR equ 0x10000     ; Dirección física de carga (64 KB)
XSH_SEGMENT      equ 0x2000      ; Segmento base que apunta a 0x20000 (128 KB)

; =============================================================================
; 🟩 ETAPA 1: MODO REAL (16-BITS) - Configuración Inicial y Selección
; =============================================================================
[BITS 16]
org KERNEL_LOAD_ADDR

_kernel_entry_16:
    ; Configurar los registros de segmento base para Modo Real
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x9000               ; Definir un stack seguro en Modo Real

    ; Consultar la tabla de vectores EXFS / XSH usando segmentación limpia
    mov ax, XSH_SEGMENT
    mov es, ax
    mov bx, [es:0x0000]          ; Lee el vector de 16 bits de la Shell (Offset 0)

    ; Decisión arquitectónica: ¿Saltamos a la Shell de 16-bits o escalamos?
    cmp bx, 0
    je .escalar_a_32_bits        ; Si el vector es 0, el usuario quiere modo protegido
    
    ; Salto lejano (Far Jump) seguro a la sub-shell de 16 bits
    push XSH_SEGMENT
    push bx
    retf

.escalar_a_32_bits:
    ; Desactivar interrupciones de hardware antes de cambiar el modo de la CPU
    cli
    
    ; Cargar la Tabla del Descriptor Global (GDT)
    lgdt [gdt_descriptor]
    
    ; Activar el bit de Modo Protegido (PE) en el registro de control CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Salto lejano de 32 bits para limpiar el pipeline de ejecución de 16 bits
    jmp 0x08:_kernel_entry_32

; =============================================================================
; 🟦 ETAPA 2: MODO PROTEGIDO (32-BITS) - Inicialización de Memoria Plana
; =============================================================================
[BITS 32]
_kernel_entry_32:
    ; Actualizar todos los selectores de datos con el descriptor de datos (0x10)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000             ; Mover el stack a una zona alta de 32 bits

    ; Leer el vector de 32 bits de la cabecera XSH (Dirección física 0x20002)
    mov edx, [0x20002]
    cmp edx, 0
    je .escalar_a_64_bits        ; Si es 0, escalamos al modo largo nativo

    ; Saltar a la sub-shell de 32 bits de XSH
    jmp edx

.escalar_a_64_bits:
    ; 1. Configurar Paginación (Requisito obligatorio de hardware para 64-bits)
    ; Aquí el kernel limpia y escribe las tablas PML4, PDPT, PD en memoria...
    
    ; 2. Activar PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 3. Cargar la dirección de la tabla PML4 en CR3
    ; mov eax, 0x9000 ---> Dirección base de tus tablas de página
    ; mov cr3, eax

    ; 4. Activar el bit de Long Mode (LME) en el MSR EFER (Extended Feature Enable)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; 5. Activar Paginación en CR0 para activar oficialmente Long Mode
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Salto lejano de 64 bits a la sección nativa
    jmp 0x08:_kernel_entry_64

; =============================================================================
; 🟪 ETAPA 3: MODO LARGO (64-BITS) - Entorno Nativo de Máximo Rendimiento
; =============================================================================
[BITS 64]
_kernel_entry_64:
    ; En 64 bits los segmentos ds, es, ss son obsoletos (son 0), los limpiamos
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Leer el vector de 64 bits de la cabecera XSH (Dirección física 0x20006)
    mov rbx, [0x20006]
    
    ; Saltar directamente al prompt de 64 bits de la Shell
    jmp rbx

; =============================================================================
; 📊 ESTRUCTURAS DE DATOS CONTROLADAS DEL KERNEL
; =============================================================================
align 4
gdt_start:
    dq 0x0000000000000000         ; Descriptor Nulo (Obligatorio)
gdt_code:
    dq 0x00CF9A000000FFFF         ; Selector de Código de 32-bits (0x08)
gdt_data:
    dq 0x00CF92000000FFFF         ; Selector de Datos de 32-bits (0x10)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1    ; Límite de la GDT
    dd gdt_start                  ; Dirección física base de la GDT
