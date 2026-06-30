; =============================================================================
; XKERNEL — Núcleo Exokernel Unificado (Corregido y Estabilizado)
; =============================================================================
org 0x9000

; =============================================================================
; STAGE 1: ENTORNO DE MODO REAL (16-BITS)
; =============================================================================
[BITS 16]
_start:
    cli                         ; Desactivar interrupciones críticas inmediatamente

    ; Sincronizar registros de segmento a cero absoluto (Entorno Plano Inicial)
    xor ax, ax                  
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, stack_top           ; Pila temporal de 16/32 bits

    ; Cargar la Tabla Global de Descriptores Unificada (GDT)
    lgdt [gdt_desc]

    ; Activar el bit de Modo Protegido (PE) en el Registro de Control CR0
    mov eax, cr0
    or eax, 1                   
    mov cr0, eax

    ; JUMP LEJANO (Far Jump): Fuerza a la CPU a cambiar a Modo Protegido de 32 bits.
    ; El selector 0x08 apunta al Descriptor de Código de 32 bits en nuestra GDT.
    jmp 0x08:kernel_stage_32

; =============================================================================
; STAGE 2: ENTORNO DE MODO PROTEGIDO (32-BITS)
; =============================================================================
[BITS 32]
kernel_stage_32:
    ; Recargar los selectores de datos con el segmento de datos de 32 bits (0x10)
    mov ax, 0x10                
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_top          ; Confirmar la pila en el entorno de 32 bits

    ; --- LIMPIEZA DE MEMORIA PARA TABLAS DE PÁGINAS ---
    mov edi, page_table_p4
    xor eax, eax
    mov ecx, 3072               ; Limpiar P4, P3 y P2 (3 * 1024 dwords)
    rep stosd

    ; --- CONSTRUCCIÓN DEL ÁRBOL DE PAGINACIÓN DE MODO LARGO ---
    mov eax, page_table_p3
    or eax, 0b11                ; Flags de Hardware: Presente + Escritura
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11                ; Flags de Hardware: Presente + Escritura
    mov [page_table_p3], eax

    mov eax, 0b10000011         ; Huge Page de 2MB mapeada por identidad
    mov [page_table_p2], eax

    ; Cargar la dirección física de la PML4 (P4) en el registro CR3
    mov eax, page_table_p4
    mov cr3, eax

    ; Activar PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Habilitar Long Mode en el Registro de Modelo Específico (MSR) EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8              ; Activar bit LME (Long Mode Enable)
    wrmsr

    ; Activar Paginación de Hardware definitiva en CR0
    mov eax, cr0
    or eax, 1 << 31             ; Activar bit PG (Paging)
    mov cr0, eax

    ; --- JUMP LEJANO DEFINITIVO A MODO LARGO (64-BITS) ---
    ; El selector 0x18 apunta al Descriptor de Código de 64 bits en nuestra GDT.
    jmp 0x18:kernel_stage_64

; =============================================================================
; STAGE 3: ENTORNO NATIVO DE 64 BITS (EXOKERNEL NUCLEUS)
; =============================================================================
[BITS 64]
kernel_stage_64:
    ; Inicializar selectores de datos en modo plano nativo de 64 bits
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64       ; Pila definitiva de 64 bits en alta memoria

    ; Limpiar buffer visual e iniciar ejecutor primario
    call xk_clear_screen
    call exit_main_executor

.infinite_halt:
    hlt
    jmp .infinite_halt

; =============================================================================
; INCLUSIÓN DE SUBMÓDULOS (COMPATIBILIDAD XSPEC)
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"

; =============================================================================
; DRIVERS VGA Y CONTROL VISUAL (64-BITS)
; =============================================================================
global xk_clear_screen
xk_clear_screen:
    mov rcx, 2000
    mov rdi, 0xB8000
    mov ax, 0x0F20              ; Espacio vacío, color gris estándar
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
; ESTRUCTURAS DE HARDWARE UNIFICADAS (TABLAS DE PÁGINAS Y GDT GLOBAL)
; =============================================================================
align 4096
page_table_p4: times 4096 db 0
page_table_p3: times 4096 db 0
page_table_p2: times 4096 db 0

align 8
; --- TABLA GLOBAL DE DESCRIPTORES (GDT UNIFICADA) ---
; Una sola estructura limpia evita colisiones de punteros en binarios planos.
gdt_start:
    dq 0x0000000000000000       ; [0x00] Descriptor Nulo
    dq 0x00CF9A000000FFFF       ; [0x08] Código de 32 bits (Base=0, Límite=4GB)
    dq 0x00CF92000000FFFF       ; [0x10] Datos de 32 bits (Base=0, Límite=4GB)
    dq 0x00209A0000000000       ; [0x18] Código de 64 bits (Modo Largo Nativo)
gdt_end:

gdt_desc:
    dw gdt_end - gdt_start - 1
    dq gdt_start

; --- VARIABLES GLOBALES ---
align 16
cursor_pos:         dw 0
exfs_cur_dir_name:  times 32 db 0
exfs_cur_dir_lba:   dq 0
readline_buf:       times 256 db 0

; --- PILAS DE EXECUCIÓN ---
times 1024 db 0
stack_top:                      ; Pila compartida para 16/32 bits
times 2048 db 0
stack_top_64:                   ; Pila nativa definitiva para 64 bits
