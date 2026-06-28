
; =============================================================================
; XBOOT - EXOKERNEL BOOTLOADER [XSPEC-0001]
; Arquitectura: x86 Real Mode (16-bit)
; Ensamblador:  NASM
; Cargado por:  BIOS en 0x0000:0x7C00
; Tamaño:       512 bytes exactos (MBR)
; =============================================================================
 
bits 16
org  0x7C00
 
; -----------------------------------------------------------------------------
; CONSTANTES DE DISEÑO
; -----------------------------------------------------------------------------
KERNEL_SEG      equ 0x1000      ; Segmento destino del kernel (0x10000 físico)
KERNEL_OFF      equ 0x0000      ; Offset dentro del segmento
KERNEL_SECTOR   equ 1           ; Sector LBA donde empieza XKERNEL
KERNEL_COUNT    equ 16          ; Sectores a cargar (8 KB, suficiente para inicio)
 
STACK_TOP       equ 0x7C00      ; Pila crece hacia abajo desde aquí
 
; =============================================================================
; PUNTO DE ENTRADA - XBOOT INIT
; =============================================================================
xboot_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STACK_TOP
    sti
 
    mov [boot_drive], dl        ; Guardar unidad de arranque del BIOS
 
    ; -------------------------------------------------------------------------
    ; PASO 1: Cargar XKERNEL desde disco usando BIOS INT 13h (LBA)
    ; -------------------------------------------------------------------------
    call xboot_load_kernel
 
    ; -------------------------------------------------------------------------
    ; PASO 2: Detectar capacidades de la CPU con CPUID
    ; -------------------------------------------------------------------------
    call xboot_detect_cpu       ; Resultado en AL: 0=16bit, 1=32bit, 2=64bit
 
    ; -------------------------------------------------------------------------
    ; PASO 3: Saltar al modo correcto
    ; -------------------------------------------------------------------------
    cmp al, 2
    je  .goto_64bit
    cmp al, 1
    je  .goto_32bit
 
.goto_16bit:
    ; CPU antigua de 16 bits puros — saltar directo al kernel en Real Mode
    jmp KERNEL_SEG:KERNEL_OFF
 
.goto_32bit:
    ; Cargar GDT de 32 bits y activar Protected Mode
    lgdt [gdt32_descriptor]
    mov eax, cr0
    or  eax, 1
    mov cr0, eax
    jmp 0x08:(KERNEL_SEG * 16 + KERNEL_OFF + 0x100)  ; Entry 32-bit
 
.goto_64bit:
    ; Configurar paginación mínima para Long Mode
    call xboot_setup_paging
 
    ; Activar PAE
    mov eax, cr4
    or  eax, (1 << 5)
    mov cr4, eax
 
    ; Activar Long Mode en EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or  eax, (1 << 8)
    wrmsr
 
    ; Cargar GDT de 64 bits y activar paginación + protected mode
    lgdt [gdt64_descriptor]
    mov eax, cr0
    or  eax, 0x80000001
    mov cr0, eax
 
    jmp 0x08:(KERNEL_SEG * 16 + KERNEL_OFF + 0x200)  ; Entry 64-bit
 
; =============================================================================
; XBOOT_LOAD_KERNEL — Carga XKERNEL desde disco (INT 13h LBA)
; =============================================================================
xboot_load_kernel:
    mov ax, KERNEL_SEG
    mov es, ax                  ; ES = segmento destino
 
    ; Construir DAP (Disk Address Packet) en stack
    push dword 0                ; LBA alto (32 bits superiores = 0)
    push dword KERNEL_SECTOR    ; LBA bajo
    push word  KERNEL_OFF       ; Offset en buffer
    push word  KERNEL_SEG       ; Segmento del buffer
    push word  KERNEL_COUNT     ; Sectores a leer
    push word  0x0010           ; Tamaño del DAP = 16 bytes
    mov  si, sp                 ; SI apunta al DAP
 
    mov dl, [boot_drive]
    mov ah, 0x42                ; INT 13h extendido (LBA)
    int 0x13
 
    add sp, 16                  ; Limpiar stack (DAP = 16 bytes)
    ret
 
; =============================================================================
; XBOOT_DETECT_CPU — Detecta capacidad máxima del procesador
; Retorna: AL = 0 (16-bit), 1 (32-bit), 2 (64-bit)
; =============================================================================
xboot_detect_cpu:
    ; Verificar soporte de CPUID intentando cambiar el bit ID en EFLAGS
    pushfd
    pop  eax
    mov  ecx, eax
    xor  eax, (1 << 21)
    push eax
    popfd
    pushfd
    pop  eax
    push ecx
    popfd
    xor  eax, ecx
    jz   .es_16bit              ; CPUID no soportado → CPU antigua de 16 bits
 
    ; Verificar soporte de Long Mode (64 bits)
    mov  eax, 0x80000000
    cpuid
    cmp  eax, 0x80000001
    jb   .es_32bit              ; Sin funciones extendidas → máximo 32 bits
 
    mov  eax, 0x80000001
    cpuid
    test edx, (1 << 29)         ; Bit LM (Long Mode)
    jz   .es_32bit
 
    mov  al, 2                  ; 64-bit
    ret
.es_32bit:
    mov  al, 1                  ; 32-bit
    ret
.es_16bit:
    mov  al, 0                  ; 16-bit
    ret
 
; =============================================================================
; XBOOT_SETUP_PAGING — Paginación mínima 4 niveles para Long Mode
; Tablas en 0x1000-0x4FFF (antes de donde cargamos el kernel en 0x10000)
; =============================================================================
xboot_setup_paging:
    ; Limpiar 16 KB a partir de 0x1000 para las tablas de página
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 0x1000             ; 4096 dwords = 16 KB
    rep stosd
 
    ; PML4[0] → PDPT en 0x2000
    mov dword [0x1000], 0x2003
    ; PDPT[0] → PD en 0x3000
    mov dword [0x2000], 0x3003
    ; PD[0] → Huge Page 2MB, mapeo identidad del primer 1 GB
    mov dword [0x3000], 0x0083
 
    mov eax, 0x1000
    mov cr3, eax
    ret
 
; =============================================================================
; DATOS Y ESTRUCTURAS
; =============================================================================
boot_drive  db 0x80
 
; --- GDT de 32 bits ---
align 8
gdt32_start:
    dq 0x0000000000000000       ; Descriptor nulo
gdt32_code:
    dw 0xFFFF                   ; Límite [15:0]
    dw 0x0000                   ; Base [15:0]
    db 0x00                     ; Base [23:16]
    db 10011010b                ; Acceso: ejecutable, legible, presente
    db 11001111b                ; Gran: 4KB, 32-bit, límite [19:16]=F
    db 0x00                     ; Base [31:24]
gdt32_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b                ; Acceso: datos, escribible, presente
    db 11001111b
    db 0x00
gdt32_end:
 
gdt32_descriptor:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start
 
; --- GDT de 64 bits ---
align 8
gdt64_start:
    dq 0x0000000000000000       ; Descriptor nulo
gdt64_code:
    dq 0x00209A0000000000       ; Código 64-bit: L=1, P=1, DPL=0
gdt64_data:
    dq 0x0000920000000000       ; Datos 64-bit
gdt64_end:
 
gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start
 
; =============================================================================
; PADDING Y FIRMA MBR (obligatoria: 0xAA55 en bytes 510-511)
; =============================================================================
times 510 - ($ - $$) db 0x00
dw 0xAA55
