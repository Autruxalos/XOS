; =============================================================================
; EXIT - THE UNIFIED MULTI-ARCH INITIALIZATION SUBSYSTEM (16 / 32 / 64-BIT INIT)
; Syntax: NASM
; Base Mapped Address: 0x30000 (Physical RAM)
; =============================================================================

org 0x30000

; =============================================================================
; OFFSET 0x00: 16-BIT REAL MODE INITIALIZATION
; =============================================================================
bits 16
_exit_entry_16:
    mov ax, 0x0000
    mov [init_status], ax

    mov si, msg_exit_16
    call print_string_16

    jmp 0x20000                 ; Saltar a la Shell de 16-bits (Offset 0x00)

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

msg_exit_16 db '-> EXIT: 16-bit synch.', 13, 10, 0


; =============================================================================
; OFFSET 0x40 (64 bytes): 32-BIT PROTECTED MODE INITIALIZATION
; =============================================================================
times 64 - ($ - $$) db 0        ; Alineación segura a 64 bytes
bits 32
_exit_entry_32:
    mov dword [init_status], 32

    mov esi, msg_exit_32
    mov edi, 0xB8000 + 480      ; Línea 4 de la memoria de video VGA
    mov ah, 0x07
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    jmp 0x20040                 ; Saltar a la Shell de 32-bits (Offset 0x40)

msg_exit_32 db '-> EXIT: 32-bit synch.', 0


; =============================================================================
; OFFSET 0x80 (128 bytes): 64-BIT LONG MODE INITIALIZATION
; =============================================================================
times 128 - ($ - $$) db 0       ; Alineación segura a 128 bytes
bits 64
_exit_entry_64:
    mov rax, 64
    mov [init_status], rax

    mov rsi, msg_exit_64
    mov rdi, 0xB8000 + 640      ; Línea 5 de la memoria de video VGA
    mov ah, 0x0F
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:
    jmp 0x20080                 ; Saltar a la Shell de 64-bits (Offset 0x80)

msg_exit_64 db '-> EXIT: 64-bit synch.', 0

; --- VARIABLES ---
align 8
init_status: dq 0
