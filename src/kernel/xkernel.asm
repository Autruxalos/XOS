; =============================================================================
; XKERNEL — Núcleo Base Exokernel Modular (64-bits)
; =============================================================================
[BITS 32]

; Cabecera obligatoria Multiboot2 para GRUB / QEMU MBR Trampoline
SECTION .multiboot
align 8
multiboot_start:
    dd 0xE8876D68               ; Número mágico Multiboot2
    dd 0                        ; Arquitectura: x86 Modo Protegido i386
    dd multiboot_end - multiboot_start ; Longitud de la cabecera
    dd -(0xE8876D68 + 0 + (multiboot_end - multiboot_start)) ; Checksum
    ; Etiquetas requeridas finales
    dw 0
    dw 0
    dd 8
multiboot_end:

SECTION .text
global _start
_start:
    cli                         ; Desactivar interrupciones de hardware
    mov esp, stack_top          ; Establecer puntero de pila temporal de 32 bits

    ; --- CONFIGURACIÓN DE PAGINACIÓN BÁSICA PARA MODO LARGO (64-BITS) ---
    mov eax, page_table_p3
    or eax, 0b11                ; Presente + Lectura/Escritura
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11
    mov [page_table_p3], eax

    ; Mapear de forma plana (Identity Mapping) los primeros 2 Megabytes
    mov eax, 0b10000011         ; Presente + R/W + Huge Page (2MB)
    mov [page_table_p2], eax

    ; Cargar tabla de páginas en el registro de control CR3
    mov eax, page_table_p4
    mov cr3, eax

    ; Activar PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Activar Modo Largo en el MSR EFER (Long Mode Enable)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Activar Paginación en CR0 para ingresar oficialmente al entorno de 64 bits
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Saltar usando la GDT de 64 bits al segmento de código de Modo Largo
    lgdt [gdt64_desc]
    jmp 0x08:xk_long_mode_entry

[BITS 64]
xk_long_mode_entry:
    ; Configurar selectores de segmento de datos en 0 para espacio plano
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64       ; Pila definitiva de 64 bits

    ; Inicializar pantalla VGA
    call xk_clear_screen

    ; Lanzar el Init del sistema
    call exit_main_executor

.infinite_halt:
    cli \ hlt
    jmp .infinite_halt

; --- INTERFAZ DE DRIVERS DE HARDWARE (Rutinas del Kernel Antiguo) ---

global xk_clear_screen
xk_clear_screen:
    mov rcx, 2000               ; 80 columnas * 25 filas
    mov rdi, 0xB8000
    mov ax, 0x0F20              ; Fondo negro, texto blanco, carácter espacio
    rep stosw
    mov word [cursor_pos], 0    ; Resetear posición interna
    ret

global xk_print
xk_print:
    ; Entrada: RSI = Puntero a cadena terminada en 0, BL = Atributo color
    movzx rdx, word [cursor_pos]
    shl rdx, 1
    add rdx, 0xB8000
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 10                  ; Salto de línea (\n)
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
    ; Entrada: RSI y RDI apuntando a las cadenas a comparar
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
    xor rax, rax                ; Retorna 0 si son idénticas
    ret

global xk_readline
xk_readline:
    ; Entrada: RDI = Buffer de destino. Lee caracteres simulados del teclado PIO
    ; Para evitar congelamiento sin IRQ activa, lee una entrada predefinida si está vacío
    mov rsi, .mock_input
    mov rcx, 16
    rep movsb
    ret
.mock_input: db "pwd", 0

; --- INTERFAZ SIMULADA DE DISCO ATA PIO / EXFS ---
global exfs_create_directory_slot
exfs_create_directory_slot:
    mov rsi, .msg_ok
    mov bl, 0x0E                ; Amarillo
    call xk_println
    ret
.msg_ok: db "EXFS: Directorio asignado en Sector de Datos.", 0

; --- SECCIÓN DE DATOS DE HARDWARE ---
SECTION .data
align 4096
page_table_p4: resb 4096
page_table_p3: resb 4096
page_table_p2: resb 4096

align 8
gdt64_start:
    dq 0x0000000000000000       ; Descriptor nulo
    dq 0x00209A0000000000       ; Selector de código de 64 bits (0x08)
    dq 0x0000920000000000       ; Selector de datos de 64 bits (0x10)
gdt64_end:
gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

; --- VARIABLES GLOBALES DEL NÚCLEO EXOKERNEL ---
SECTION .bss
align 16
global cursor_pos, exfs_cur_dir_name, exfs_cur_dir_lba, readline_buf
cursor_pos:         resw 1
exfs_cur_dir_name:  resb 32
exfs_cur_dir_lba:   resq 1
readline_buf:       resb 256

resb 4096                   ; Área de Pilas
stack_top:
resb 4096
stack_top_64:

; =============================================================================
; INYECCIÓN DINÁMICA DE MÓDULOS DE APLICACIÓN Y SISTEMA
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
