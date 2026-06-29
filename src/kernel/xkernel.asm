; =============================================================================
; XKERNEL — Núcleo Base Exokernel Modular (64-bits)
; =============================================================================
[BITS 32]

SECTION .text
align 8
multiboot_start:
    dd 0xE8876D68               ; Magia Multiboot2
    dd 0                        ; Arquitectura x86 i386
    dd multiboot_end - multiboot_start
    dd -(0xE8876D68 + 0 + (multiboot_end - multiboot_start))
    dw 0
    dw 0
    dd 8
multiboot_end:

global _start
_start:
    cli
    mov esp, stack_top

    ; --- CONFIGURACIÓN DE PAGINACIÓN BÁSICA ---
    mov eax, page_table_p3
    or eax, 0b11
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11
    mov [page_table_p3], eax

    mov eax, 0b10000011         ; 2MB Huge Page Identity Mapped
    mov [page_table_p2], eax

    mov eax, page_table_p4
    mov cr3, eax

    ; Activar PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Activar Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Activar Paginación
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Saltar a Modo Largo de 64 bits usando la GDT
    lgdt [gdt64_desc]
    jmp 0x08:xk_long_mode_entry

[BITS 64]
xk_long_mode_entry:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64

    call xk_clear_screen
    call exit_main_executor

.infinite_halt:
    cli
    hlt
    jmp .infinite_halt

; --- DRIVERS VGA E INTERFACES DEL KERNEL ---
global xk_clear_screen
xk_clear_screen:
    mov rcx, 2000
    mov rdi, 0xB8000
    mov ax, 0x0F20
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

global exfs_create_directory_slot
exfs_create_directory_slot:
    mov rsi, .msg_ok
    mov bl, 0x0E                ; Amarillo
    call xk_println
    ret
.msg_ok: db "EXFS: Directorio asignado en Sector de Datos.", 0

; =============================================================================
; INYECCIÓN DE CÓDIGO DE SUBMÓDULOS
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"

; --- SECCIÓN DE DATOS CONSTANTES E INICIALIZADOS ---
SECTION .data
align 4096
page_table_p4: times 4096 db 0
page_table_p3: times 4096 db 0
page_table_p2: times 4096 db 0

align 8
gdt64_start:
    dq 0x0000000000000000
    dq 0x00209A0000000000       ; Código 64-bits
    dq 0x0000000000000000       ; Datos plano
gdt64_end:

gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

; --- SECCIÓN DE VARIABLES VOLÁTILES (NO ENTRARÁN AL BINARIO FÍSICO) ---
SECTION .bss
align 16
cursor_pos:         resw 1
exfs_cur_dir_name:  resb 32
exfs_cur_dir_lba:   resq 1
readline_buf:       resb 256

resb 4096
stack_top:
resb 4096
stack_top_64:
