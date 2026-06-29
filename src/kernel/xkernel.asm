; =============================================================================
; XKERNEL — Núcleo Estabilizado Lineal (64-bits)
; =============================================================================
[BITS 32]
org 0x9000      ; Alineación exacta con la carga de XBOOT

_start:
    ; --- BLINDAJE INICIAL DE SEGMENTOS DE 32 BITS ---
    cli                         ; Desactivar interrupciones por completo
    mov ax, 0x0000              ; Asegurar entornos planos en Modo Real/Protegido inicial
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_top          ; Apuntar la pila temporal de 32 bits

    ; --- REIGNICIÓN Y LIMPIEZA DINÁMICA DE TABLAS DE PÁGINAS ---
    ; Nos aseguramos de que las tablas estén en cero absoluto antes de mapear
    mov edi, page_table_p4
    xor eax, eax
    mov ecx, 3072               ; 1024 * 3 (Limpiar las 3 tablas completas de un tiro)
    rep stosd

    ; --- MAREO DE MEMORIA FÍSICA DIRECTA ---
    mov eax, page_table_p3
    or eax, 0b11                ; Presente + Escritura (Flags de Hardware)
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11                ; Presente + Escritura
    mov [page_table_p3], eax

    mov eax, 0b10000011         ; 2MB Huge Page, Presente, R/W
    mov [page_table_p2], eax

    ; Cargar el directorio de páginas en el registro físico CR3
    mov eax, page_table_p4
    mov cr3, eax

    ; Habilitar PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Activar el bit de Modo Largo (LME) en el registro de modelo específico (MSR) EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Activar Paginación y Modo Protegido definitivo en CR0
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; --- EL SALTO CUÁNTICO A MODO LARGO (64-BITS) ---
    lgdt [gdt64_desc]
    jmp 0x08:xk_long_mode_entry

; =============================================================================
; ENTORNO NATIVO DE 64 BITS
; =============================================================================
[BITS 64]
xk_long_mode_entry:
    ; Inicializar selectores de datos para arquitectura de 64 bits plana
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64       ; Pila definitiva de 64 bits en alta memoria

    ; Forzar limpieza visual y llamada al ejecutor de inicialización
    call xk_clear_screen
    call exit_main_executor

.infinite_halt:
    hlt
    jmp .infinite_halt
