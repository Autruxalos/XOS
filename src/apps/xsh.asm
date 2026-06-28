; =============================================================================
; XSH - THE UNIFIED MULTI-ARCH SHELL (ESTRUCTURA CORREGIDA)
; Syntax: NASM
; Mapped Base Address: 0x10400 (Sector 3 en RAM)
; =============================================================================

; =============================================================================
; OFFSET 0x00: INTERFAZ DE 16 BITS
; =============================================================================
bits 16
_xsh_entry_16:
    mov si, msg_xsh_16
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .halt
    int 0x10
    jmp .loop
.halt:
    hlt
    jmp .halt

msg_xsh_16 db 'Autruxalos@XOS_16bit:/$ ', 0


; =============================================================================
; OFFSET 0x40 (64 bytes): INTERFAZ DE 32 BITS
; =============================================================================
times 64 - ($ - $$) db 0        ; Alineación estricta al offset 0x40 del Sector 3
bits 32
_xsh_entry_32:
    mov esi, msg_xsh_32
    mov edi, 0xB8000 + 160      ; Tercera línea de pantalla VGA
    mov ah, 0x0A                ; Color: Verde Shell clásica
.loop:
    lodsb
    cmp al, 0
    je .halt
    mov [edi], ax
    add edi, 2
    jmp .loop
.halt:
    hlt
    jmp .halt

msg_xsh_32 db 'Autruxalos@XOS_32bit:/$ ', 0


; =============================================================================
; OFFSET 0x80 (128 bytes): INTERFAZ DE 64 BITS
; =============================================================================
times 128 - ($ - $$) db 0       ; Alineación estricta al offset 0x80 del Sector 3
bits 64
_xsh_entry_64:
    mov rsi, msg_xsh_64
    mov rdi, 0xB8000 + 320      ; Cuarta línea de pantalla VGA
    mov ah, 0x0B                ; Color: Cyan Shell moderna
.loop:
    lodsb
    cmp al, 0
    je .halt
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.halt:
    hlt
    jmp .halt

msg_xsh_64 db 'Autruxalos@XOS_64bit:/$ ', 0

; ALINEACIÓN GEOMÉTRICA MANDATORIA: Cierra el Sector 3 de forma limpia
times 512 - ($ - $$) db 0
