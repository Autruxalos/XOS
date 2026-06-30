; =============================================================================
; XKERNEL — Entrada Sincronizada y Blindada
; =============================================================================
[BITS 32]
org 0x9000      ; <--- ¡CRÍTICO! Cambia este número si tu cargador usa otra dirección

_start:
    ; --- LIMPIEZA ABSOLUTA DE REGISTROS DE SEGMENTO ---
    cli                         ; Desactivar interrupciones de inmediato
    xor ax, ax                  ; Limpiar registros a 0x0000
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_top          ; Configurar una pila de 32 bits segura temporal

    ; --- REIGNICIÓN Y LIMPIEZA FÍSICA DE TABLAS DE PÁGINAS ---
    ; Forzamos a que la memoria de las tablas de páginas sea cero absoluto
    mov edi, page_table_p4
    xor eax, eax
    mov ecx, 3072               ; Limpiar las 3 tablas (P4, P3, P2) de un solo golpe
    rep stosd

    ; --- CONSTRUCCIÓN DEL ÁRBOL DE PAGINACIÓN ---
    mov eax, page_table_p3
    or eax, 0b11                ; Flags: Presente + Escritura
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11                ; Flags: Presente + Escritura
    mov [page_table_p3], eax

    mov eax, 0b10000011         ; 2MB Huge Page (Identity Mapped)
    mov [page_table_p2], eax

    ; Cargar el directorio de páginas en el registro de control CR3
    mov eax, page_table_p4
    mov cr3, eax

    ; HABILITAR PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; HABILITAR LONG MODE EN EL REGISTRO MSR EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; ACTIVAR PAGINACIÓN DE HARDWARE DEFINITIVA
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; --- SALTO MAESTRO A MODO LARGO (64-BITS) ---
    lgdt [gdt64_desc]
    jmp 0x08:xk_long_mode_entry

; =============================================================================
; ENTORNO NATIVO DE 64 BITS
; =============================================================================
[BITS 64]
xk_long_mode_entry:
    ; Configurar los selectores de datos para el espacio plano de 64 bits
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64       ; Inicializar la pila de alta memoria de 64 bits

    ; Forzar limpieza visual y pasar el control al inicializador del sistema
    call xk_clear_screen
    call exit_main_executor

.infinite_halt:
    hlt
    jmp .infinite_halt
