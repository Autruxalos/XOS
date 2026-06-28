; =============================================================================
; XBOOT - THE ADAPTIVE MULTI-ARCH BOOTLOADER (16/32/64-BIT SELECTOR)
; Syntax: NASM (Starts in 16-bit Real Mode)
; =============================================================================

bits 16
org 0x7C00

xboot_init:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl        ; Guardar unidad de disco dada por BIOS

    ; 1. DETECTAR CAPACIDADES DE LA CPU (Instrucción CPUID)
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21            ; Invertir el bit ID de la bandera
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jz .cpu_is_16bit            ; Si el bit no cambió, la CPU es de 16 bits pura

    ; Verificar si soporta Modo Largo de 64 bits
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .cpu_is_32bit            ; Si no soporta funciones extendidas, máximo es 32 bits

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           ; Verificar bit 29 (Long Mode)
    jz .cpu_is_32bit            ; Si el bit es 0, la CPU es de 32 bits

; =============================================================================
; CAMINO A: LA CPU SOPORTA 64 BITS NATIVOS
; =============================================================================
.cpu_is_64bit:
    ; Configurar paginación de 4 niveles básica para Modo Largo
    mov edi, 0x1000             ; Dirección de la PML4
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd                   ; Limpiar tablas

    mov dword [0x1000], 0x2003  ; PML4[0] -> PDPT
    mov dword [0x2000], 0x3003  ; PDPT[0] -> PD
    mov dword [0x3000], 0x0083  ; PD[0] -> Mapeo directo 2MB (Huge Page)

    mov eax, cr4
    or eax, 1 << 5              ; Activar PAE
    mov cr4, eax

    mov ecx, 0x0C000080         ; EFER MSR
    rdmsr
    or eax, 1 << 8              ; LME = 1 (Long Mode Enable)
    wrmsr

    mov eax, cr0
    or eax, 0x80000001          ; PG = 1, PE = 1
    mov cr0, eax

    lgdt [gdt64_descriptor]
    jmp 0x08:0x10040            ; Salto al Entry Point de 64 bits del Kernel

; =============================================================================
; CAMINO B: LA CPU ES MÁXIMO DE 32 BITS
; =============================================================================
.cpu_is_32bit:
    lgdt [gdt32_descriptor]
    mov eax, cr0
    or eax, 1                   ; Activar Modo Protegido (PE)
    mov cr0, eax
    jmp 0x08:0x10020            ; Salto al Entry Point de 32 bits del Kernel

; =============================================================================
; CAMINO C: LA CPU ES ANTIGUA (16 BITS PUROS)
; =============================================================================
.cpu_is_16bit:
    mov dl, [boot_drive]
    jmp 0x1000:0x0000           ; Salto al Entry Point de 16 bits del Kernel (Inicio de RAM)

; =============================================================================
; ESTRUCTURAS DE HARDWARE (GDTs) - CORREGIDO
; =============================================================================
align 8
gdt32_start:
    dq 0x0000000000000000
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
    dq 0x0000000000000000
gdt64_code:
    dq 0x00209A0000000000       ; Código de 64 bits
gdt64_data:
    dq 0x0000920000000000       ; Datos de 64 bits
gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start
