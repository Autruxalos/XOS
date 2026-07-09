org 0x9000

[BITS 16]
kernel_16_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov si, msg16
    call print16
    lgdt [gdt32]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:kernel_32

print16:
.loop lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done ret
msg16 db '16->',0

[BITS 32]
kernel_32:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, stack32
    mov esi, msg32
    call print32
    lgdt [gdt64]
    jmp 0x18:kernel_64

print32:
.loop lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done ret
msg32 db '32->',0

[BITS 64]
kernel_64:
    xor rax, rax
    mov ds, ax
    mov ss, ax
    mov rsp, stack64

    mov rdi, 0xB8000
    mov rax, 0x1F581F4F
    stosq
    mov rax, 0x1F53201F
    stosq

    call exit_main

halt:
    hlt
    jmp halt

; GDTs
gdt32 dw 23, gdt32_start, 0
gdt32_start dq 0, 0xCF9A000000FFFF, 0xCF92000000FFFF

gdt64 dw 15, gdt64_start, 0
gdt64_start dq 0, 0x209A0000000000

stack32 times 512 db 0
stack64 times 1024 db 0

%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
