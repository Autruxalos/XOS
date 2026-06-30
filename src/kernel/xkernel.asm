; =============================================================================
; XKERNEL - Transiciones Correctas 16→32→64 bits
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
    call print_16

    ; Transición a 32 bits
    lgdt [gdt32_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:kernel_32_entry     ; Far jump

print_16:
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    ret

msg_16 db 'XOS 16-bit -> ', 0

; =============================================================================
[BITS 32]
kernel_32_entry:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, stack_top_32

    mov esi, msg_32
    call print_32

    ; Transición a 64 bits
    lgdt [gdt64_desc]
    jmp 0x18:kernel_64_entry     ; Far jump

print_32:
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    ret

msg_32 db '32-bit -> ', 0

; =============================================================================
[BITS 64]
kernel_64_entry:
    xor rax, rax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, stack_top_64

    mov rdi, 0xB8000
    mov rax, 0x1F4F1F58   ; "XO"
    stosq

    mov rsi, msg_64
    call xk_print

    jmp xk_halt

msg_64 db " 64-bit - XOS Iniciado!", 0

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
    dq 0x00CF9A000000FFFF   ; Code 32
    dq 0x00CF92000000FFFF   ; Data 32
gdt32_end:

gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start
gdt64_start:
    dq 0
    dq 0x00209A0000000000   ; Code 64
gdt64_end:

align 16
stack_bottom_32: times 512 db 0
stack_top_32:
stack_bottom_64: times 1024 db 0
stack_top_64:

; Stubs
xk_print:
    ret

; Inclusiones
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
%include "src/apps/exofetch.asm"
%include "src/drivers/exfs.asm"
