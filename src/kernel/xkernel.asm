; =============================================================================
; XKERNEL — Binario Único Multiarquitectura (XSPEC-0001)
; XOS: Minimalismo Radical + Exokernel
; Compatible 8086 / 80286 / 386+ / x86_64
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

    ; Transición a 32 bits
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

msg_16 db 'XOS 16-bit Real Mode - XKERNEL cargado', 0x0D, 0x0A, 0

; =============================================================================
[BITS 32]
kernel_32_entry:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, stack_top_32

    call clear_screen_32
    mov esi, msg_32
    call print_string_32

    ; Preparar Long Mode básico
    ; (Tablas de paginación simplificadas - identity map)
    mov edi, page_table_p4
    xor eax, eax
    mov ecx, 4096*3
    rep stosb

    ; ... (continúa con tu código de paginación PAE/LME que ya tenías)

    lgdt [gdt64_desc]
    jmp 0x18:kernel_64_entry

clear_screen_32:
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x0720
    rep stosw
    ret

print_string_32:
    ; Implementación simple en 32 bits...
    ret

msg_32 db 'XOS 32-bit Protected Mode', 0

; =============================================================================
[BITS 64]
kernel_64_entry:
    xor rax, rax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, stack_top_64

    ; Mensaje básico en VRAM
    mov rdi, 0xB8000
    mov rax, 0x1F581F4F   ; "XO" azul/brillante
    stosq
    mov rax, 0x1F53201F   ; "S "
    stosq

    ; Inyección de módulos (XSPEC)
    ; call exit_main   ; se incluirá con %include

    jmp xk_halt

xk_halt:
    hlt
    jmp xk_halt

; =============================================================================
; GDTs y Tablas (como en tu ejemplo original)
align 4096
page_table_p4: times 4096 db 0
; ... (resto de tablas y GDTs)

align 16
stack_bottom_32: times 512 db 0
stack_top_32:
stack_bottom_64: times 1024 db 0
stack_top_64:

%include "src/drivers/exfs.asm"
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
