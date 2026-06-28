; =============================================================================
; XKERNEL - THE UNIFIED MULTI-ARCH EXOKERNEL
; =============================================================================

org 0x10000                     

; --- MODO REAL (16-BITS) ---
bits 16
_kernel_entry_16:
    mov si, msg_kernel_16
    call print_string_16
    jmp 0x20000                 

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

; --- MODO PROTEGIDO (32-BITS) ---
times 64 - ($ - $$) db 0        ; Desplazamiento fijo al offset 0x40
bits 32
_kernel_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov esi, msg_kernel_32
    mov edi, 0xB8000            
    mov ah, 0x0F
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    jmp 0x20040                 

msg_kernel_32 db '-> XKERNEL: 32-bit.', 0

; --- MODO LARGO (64-BITS) ---
times 128 - ($ - $$) db 0       ; Desplazamiento fijo al offset 0x80
bits 64
_kernel_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov rsi, msg_kernel_64
    mov rdi, 0xB80A0            
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:
    jmp 0x20080                 

msg_kernel_64 db '-> XKERNEL: 64-bit.', 0

; RELLENO ESTRATÉGICO DE ALINEACIÓN SEGMENTADA:
; Forzamos a que el binario de xkernel mida exactamente 512 bytes 
; para que el comando cat coloque a EXFS exactamente en la siguiente frontera limpia de la RAM.
times 512 - ($ - $$) db 0
