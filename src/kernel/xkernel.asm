; =============================================================================
; XKERNEL - Versión Mínima que Compila
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
.loop: lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done: ret

msg_16 db 'XOS 16-bit cargado', 0x0D, 0x0A, 0

; =============================================================================
[BITS 32]
kernel_32_entry:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, stack_top_32
    jmp kernel_64_entry

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
    jmp xk_halt

xk_halt:
    hlt
    jmp xk_halt

; =============================================================================
; GDTs
align 8
gdt32_desc: dw 23, gdt32_start, 0
gdt32_start: dq 0, 0x00CF9A000000FFFF, 0x00CF92000000FFFF

gdt64_desc: dw 15, gdt64_start, 0
gdt64_start: dq 0, 0x00209A0000000000

; Stacks
align 16
stack_bottom_32: times 512 db 0
stack_top_32:
stack_bottom_64: times 1024 db 0
stack_top_64:

; =============================================================================
; STUBS GLOBALES (importantes)
xk_print:
    ret

xk_println:
    call xk_print
    ret

; =============================================================================
; Inclusiones
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
%include "src/apps/exofetch.asm"
%include "src/drivers/exfs.asm"
