; =============================================================================
; XKERNEL Mínimo Viable - XOS (Compila Limpio)
; =============================================================================
org 0x9000

[BITS 16]
kernel_16_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov si, msg_16
    call print_string_16

    lgdt [gdt32_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:kernel_32_entry

print_string_16:
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    ret

msg_16 db 'XOS 16-bit - XKERNEL cargado', 0x0D, 0x0A, 0

; =============================================================================
[BITS 32]
kernel_32_entry:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, stack_top_32

    call clear_screen_32
    jmp kernel_64_entry   ; Salto directo simplificado

clear_screen_32:
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x0720
    rep stosw
    ret

; =============================================================================
[BITS 64]
kernel_64_entry:
    xor rax, rax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, stack_top_64

    mov rdi, 0xB8000
    mov rax, 0x1F581F4F
    stosq
    mov rax, 0x1F53201F
    stosq

    call exit_main_executor

xk_halt:
    hlt
    jmp xk_halt

; =============================================================================
; GDTs
align 8
gdt32_desc:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start
gdt32_start:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt32_end:

gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start
gdt64_start:
    dq 0
    dq 0x00209A0000000000
gdt64_end:

; Stacks
align 16
stack_bottom_32: times 512 db 0
stack_top_32:
stack_bottom_64: times 1024 db 0
stack_top_64:

; =============================================================================
; STUBS para evitar errores
xk_print:
    ret
xk_println:
    ret
xk_init_video:
    ret
xk_init_keyboard:
    ret

; =============================================================================
; Inclusiones (solo una vez)
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
%include "src/apps/exofetch.asm"
%include "src/drivers/exfs.asm"
