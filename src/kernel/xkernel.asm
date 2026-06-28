; =============================================================================
; XKERNEL - THE UNIFIED MULTI-ARCH EXOKERNEL (ORDEN RECONSTRUIDO)
; Syntax: NASM
; Base Mapped Address: 0x10000
; =============================================================================

org 0x10000                     

; -----------------------------------------------------------------------------
; OFFSET 0x00: PUNTO DE ENTRADA EN MODO REAL (16-BITS)
; -----------------------------------------------------------------------------
bits 16
_kernel_entry_16:
    mov si, msg_kernel_16
    call print_string_16
    jmp 0x10200                 ; SALTO CORREGIDO: Ir al Subsistema Init (Sector 2)

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
times 64 - ($ - $$) db 0        
bits 32
_kernel_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov esi, msg_kernel_32
    mov edi, 0xB8000            ; Primera línea VGA
    mov ah, 0x0F
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    jmp 0x10240                 ; SALTO CORREGIDO: Init de 32-bits (Offset 0x40 del Sector 2)

msg_kernel_32 db '-> XKERNEL: 32-bit.', 0

; -----------------------------------------------------------------------------
; OFFSET 0x80 (128 bytes): PUNTO DE ENTRADA EN MODO LARGO (64-BITS)
; -----------------------------------------------------------------------------
times 128 - ($ - $$) db 0       
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
    jmp 0x10280                 ; SALTO CORREGIDO: Init de 64-bits (Offset 0x80 del Sector 2)

msg_kernel_64 db '-> XKERNEL: 64-bit.', 0

; ALINEACIÓN GEOMÉTRICA MANDATORIA
times 512 - ($ - $$) db 0       ; Forzar a que xkernel mida exactamente 1 sector
