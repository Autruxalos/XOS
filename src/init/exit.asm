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
    ; 1. Clear 16-bit environment variables or flags
    mov ax, 0x0000
    mov [init_status], ax

    ; 2. Print initialization status using BIOS
    mov si, msg_exit_16
    call print_string_16

    ; 3. Hand over execution directly to the 16-bit Shell (MAPPED AT 0x20000)
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

msg_exit_16 db '-> EXIT: Environment synchronized (16-bit).', 13, 10, 0


; =============================================================================
; OFFSET 0x20: 32-BIT PROTECTED MODE INITIALIZATION
; =============================================================================
times 32 - ($ - $$) db 0        ; Strict alignment block to hit offset 0x20
bits 32
_exit_entry_32:
    ; 1. Mark status as 32-bit active
    mov dword [init_status], 32

    ; 2. Print status message directly to VGA Text Memory (Line 5)
    mov esi, msg_exit_32
    mov edi, 0xB8000 + 480      ; 80 chars * 2 bytes * 3 lines down
    mov ah, 0x07                ; Color: Light Gray
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    ; 3. Hand over execution directly to the 32-bit Shell (MAPPED AT 0x20020)
    jmp 0x20020

msg_exit_32 db '-> EXIT: Environment synchronized (32-bit Protected Mode).', 0


; =============================================================================
; OFFSET 0x40: 64-BIT LONG MODE INITIALIZATION
; =============================================================================
times 64 - ($ - $$) db 0        ; Strict alignment block to hit offset 0x40
bits 64
_exit_entry_64:
    ; 1. Mark status as 64-bit active using extended RAX registers
    mov rax, 64
    mov [init_status], rax

    ; 2. Print status message directly to VGA Text Memory (Line 6)
    mov rsi, msg_exit_64
    mov rdi, 0xB8000 + 640      ; 80 chars * 2 bytes * 4 lines down
    mov ah, 0x0F                ; Color: Bright White
.loop:
    lodsb
    cmp al, 0
    je .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:
    ; 3. Hand over execution directly to the 64-bit Shell (MAPPED AT 0x20040)
    jmp 0x20040

msg_exit_64 db '-> EXIT: Environment synchronized (64-bit Long Mode Nativo).', 0

; =============================================================================
; GLOBAL FIXED STORAGE DATA (Accessible by any mode)
; =============================================================================
align 8
init_status: dq 0               ; 8-byte variable holding initialization token
