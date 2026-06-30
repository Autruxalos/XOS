; =============================================================================
; XKERNEL — Núcleo Híbrido Multiarquitectura Unificado (16 / 32 / 64 bits)
; =============================================================================
org 0x9000

; =============================================================================
; STAGE 1: ENTORNO DE MODO REAL (16-BITS)
; =============================================================================
[BITS 16]
_start:
    ; Desactivar interrupciones durante la transición crítica de hardware
    cli                         

    ; Sincronizar selectores de datos al segmento base cero (0x0000)
    xor ax, ax                  
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, stack_top           ; Pila temporal para operaciones en 16 bits

    ; Transición hacia Modo Protegido de 32 bits
    lgdt [gdt32_desc]           ; Cargar la GDT de transición de 32 bits
    mov eax, cr0
    or eax, 1                   ; Setear el bit PE (Protected Mode Enable)
    mov cr0, eax

    ; JUMP LEJANO (Far Jump): Limpia la cola de ejecución de 16 bits y salta a 32 bits
    jmp 0x08:kernel_stage_32

; =============================================================================
; STAGE 2: ENTORNO DE MODO PROTEGIDO (32-BITS)
; =============================================================================
[BITS 32]
kernel_stage_32:
    ; Configurar los nuevos selectores de datos de 32 bits plano (GDT de transición)
    mov ax, 0x10                
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_top          ; Reasignar la pila en el entorno de 32 bits

    ; --- REIGNICIÓN Y LIMPIEZA FÍSICA DE TABLAS DE PÁGINAS ---
    mov edi, page_table_p4
    xor eax, eax
    mov ecx, 3072               ; Limpiar las 3 tablas de un solo golpe (3 * 1024 dwords)
    rep stosd

    ; --- CONSTRUCCIÓN DEL ÁRBOL DE PAGINACIÓN DE 64 BITS ---
    mov eax, page_table_p3
    or eax, 0b11                ; Flags: Presente + Escritura
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11                ; Flags: Presente + Escritura
    mov [page_table_p3], eax

    mov eax, 0b10000011         ; 2MB Huge Page (Identity Mapped)
    mov [page_table_p2], eax

    ; Cargar el directorio de páginas raíz en el registro de control CR3
    mov eax, page_table_p4
    mov cr3, eax

    ; HABILITAR PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; HABILITAR LONG MODE EN EL REGISTRO MSR EFER (Extended Feature Enable Register)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8              ; Activar bit LME (Long Mode Enable)
    wrmsr

    ; ACTIVAR PAGINACIÓN DE HARDWARE DEFINITIVA EN CR0
    mov eax, cr0
    or eax, 1 << 31             ; Activar bit PG (Paging)
    mov cr0, eax

    ; --- JUMP DEFINITIVO A MODO LARGO (64-BITS) ---
    lgdt [gdt64_desc]           ; Cargar la GDT definitiva de 64 bits
    jmp 0x18:kernel_stage_64    ; Saltar usando el Selector de Código de Modo Largo

; =============================================================================
; STAGE 3: ENTORNO NATIVO DE 64 BITS
; =============================================================================
[BITS 64]
kernel_stage_64:
    ; Inicializar selectores de datos en cero plano para arquitectura de 64 bits
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64       ; Pila definitiva de 64 bits en alta memoria

    ; Forzar limpieza visual de pantalla e iniciar el ejecutor del sistema
    call xk_clear_screen
    call exit_main_executor

.infinite_halt:
    hlt
    jmp .infinite_halt

; =============================================================================
; INCLUSIÓN DE MÓDULOS DE APLICACIÓN Y SISTEMA (COMPATIBILIDAD XSPEC)
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"

; =============================================================================
; DRIVERS VGA Y FUNCIONES DEL NÚCLEO (64-BITS NATIVO)
; =============================================================================
global xk_clear_screen
xk_clear_screen:
    mov rcx, 2000
    mov rdi, 0xB8000
    mov ax, 0x0F20              ; Espacio vacío con atributo por defecto
    rep stosw
    mov word [cursor_pos], 0
    ret

global xk_print
xk_print:
    movzx rdx, word [cursor_pos]
    shl rdx, 1
    add rdx, 0xB8000
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 10
    je .newline
    mov [rdx], al
    mov [rdx+1], bl
    add rdx, 2
    inc word [cursor_pos]
    jmp .loop
.newline:
    add word [cursor_pos], 80
    movzx rdx, word [cursor_pos]
    shl rdx, 1
    add rdx, 0xB8000
    jmp .loop
.done:
    ret

global xk_println
xk_println:
    call xk_print
    add word [cursor_pos], 80
    ret

global xk_strcmp
xk_strcmp:
.loop:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc rsi
    inc rdi
    jmp .loop
.not_equal:
    mov rax, 1
    ret
.equal:
    xor rax, rax
    ret

global xk_readline
xk_readline:
    mov rsi, .mock_input
    mov rdi, readline_buf
    mov rcx, 4
    rep movsd
    ret
.mock_input: db "pwd", 0, 0

; =============================================================================
; ESTRUCTURAS DE HARDWARE COMBINADAS (TABLAS Y DESCRIPTORES GDT)
; =============================================================================
align 4096
page_table_p4: times 4096 db 0
page_table_p3: times 4096 db 0
page_table_p2: times 4096 db 0

align 8
; --- GDT Temporal de Transición (32-bits) ---
gdt32_start:
    dq 0x0000000000000000       ; Descriptor Nulo
    dq 0x00CF9A000000FFFF       ; Selector de Código de 32 bits (0x08)
    dq 0x00CF92000000FFFF       ; Selector de Datos de 32 bits (0x10)
gdt32_end:
gdt32_desc:
    dw gdt32_end - gdt32_start - 1
    dq gdt32_start

; --- GDT Definitiva de Modo Largo (64-bits) ---
gdt64_start:
    dq 0x0000000000000000       ; Descriptor Nulo
    dq 0x0000000000000000       ; Reservado
    dq 0x0000000000000000       ; Reservado
    dq 0x00209A0000000000       ; Selector de Código de 64 bits (0x18)
gdt64_end:
gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

; --- VARIABLES GLOBALES DEL SISTEMA ---
align 16
cursor_pos:         dw 0
exfs_cur_dir_name:  times 32 db 0
exfs_cur_dir_lba:   dq 0
readline_buf:       times 256 db 0

; --- PILAS DE EJECUCIÓN ---
times 1024 db 0
stack_top:                      ; Pila de 16/32 bits base
times 2048 db 0
stack_top_64:                   ; Pila nativa de 64 bits
