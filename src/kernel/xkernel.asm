; =============================================================================
; XKERNEL - THE UNIFIED MULTI-ARCH EXOKERNEL (16 / 32 / 64-BIT FAT KERNEL)
; Syntax: NASM
; =============================================================================

org 0x10000                     ; Dirección física base en memoria RAM

; -----------------------------------------------------------------------------
; OFFSET 0x00: PUNTO DE ENTRADA EN MODO REAL (16-BITS)
; -----------------------------------------------------------------------------
bits 16
_kernel_entry_16:
    mov si, msg_kernel_16
    call print_string_16
    jmp 0x20000                 ; Saltar a la Shell (sección 16 bits)

print_string_16:
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

msg_kernel_16 db '-> XKERNEL: 16-bit.', 13, 10, 0

; -----------------------------------------------------------------------------
; OFFSET 0x40 (64 bytes): PUNTO DE ENTRADA EN MODO PROTEGIDO (32-BITS)
; -----------------------------------------------------------------------------
times 64 - ($ - $$) db 0        ; Alineación forzada al offset 0x40
bits 32
_kernel_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov esi, msg_kernel_32
    mov edi, 0xB8000            ; Video VGA
    mov ah, 0x0F
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    jmp 0x20040                 ; Saltar a la Shell (sección 32 bits corregida)

msg_kernel_32 db '-> XKERNEL: 32-bit.', 0

; -----------------------------------------------------------------------------
; OFFSET 0x80 (128 bytes): PUNTO DE ENTRADA EN MODO LARGO (64-BITS)
; -----------------------------------------------------------------------------
times 128 - ($ - $$) db 0       ; Alineación forzada al offset 0x80
bits 64
_kernel_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov rsi, msg_kernel_64
    mov rdi, 0xB80A0            ; Segunda línea VGA
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:
    jmp 0x20080                 ; Saltar a la Shell (sección 64 bits corregida)

msg_kernel_64 db '-> XKERNEL: 64-bit.', 0
