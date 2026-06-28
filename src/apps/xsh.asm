; =============================================================================
; XSH - ENTORNO INTERACTIVO MONOLÍTICO MULTI-ARQUITECTURA (XOS)
; =============================================================================

[warning -reloc-abs-word]
[warning -reloc-abs-dword]
[warning -reloc-abs-qword]

CMD_LEN equ 32                  ; Tamaño máximo de comandos
VGA     equ 0xB8000             ; Buffer de video de texto
COLS    equ 80                  ; Ancho de pantalla

; =============================================================================
; 📌 TABLA DE VECTORES DE ENTRADA (Fija en el inicio del binario en 0x20000)
; =============================================================================
[BITS 16]
org 0x0000                      ; Segmentación limpia base 0x2000:0x0000

xsh_header_vectors:
    dw _xsh_entry_16            ; [0x20000] Offset de 16-bits (2 bytes)
    dd _xsh_entry_32            ; [0x20002] Dirección absoluta plana de 32-bits (4 bytes)
    dq _xsh_entry_64            ; [0x20006] Dirección absoluta plana de 64-bits (8 bytes)

; =============================================================================
; 💻 SUB-SHELL DE 16-BITS (MODO REAL)
; =============================================================================
_xsh_entry_16:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

_xsh_entry_16.loop:
    mov si, prompt16
    call print16
    call readline16
    call dispatch16
    jmp _xsh_entry_16.loop

print16:
    push ax
    push si
.l: lodsb
    or al, al
    jz .r
    mov ah, 0x0E
    int 0x10
    jmp .l
.r: pop si
    pop ax
    ret

readline16:
    xor cx, cx
.r: mov ah, 0x00
    int 0x16
    cmp al, 13                  ; Enter
    je .enter
    cmp cx, CMD_LEN-1
    jae .r
    mov [buf16 + ecx], al
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .r
.enter:
    mov byte [buf16 + ecx], 0
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

dispatch16:
    ret

prompt16 db "XOS_16bit:/$ ", 0
buf16    times CMD_LEN db 0

; =============================================================================
; 💻 SUB-SHELL DE 32-BITS (MODO PROTEGIDO)
; =============================================================================
[BITS 32]
XSH32_BUF equ 0x22000           ; Buffer reubicado fuera del segmento de código

_xsh_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax

_xsh_entry_32.loop:
    mov esi, prompt32
    call print32
    call readline32
    jmp _xsh_entry_32.loop

putch32:
    push ebx
    movzx ebx, word [sct32]
    shl ebx, 1
    add ebx, VGA
    mov [ebx], al
    mov byte [ebx+1], 0x0A      ; Texto verde para diferenciarlo
    inc word [sct32]
    pop ebx
    ret

print32:
    push esi
.l: lodsb
    or al, al
    jz .r
    call putch32
    jmp .l
.r: pop esi
    ret

readline32:
    ; Rutina de polling del buffer del teclado 0x60
.w: in al, 0x64
    test al, 1
    jz .w
    in al, 0x60
    test al, 0x80
    jnz .w                      ; Si es un "key release" ignorar
    cmp al, 0x1C                ; Enter scan code
    je .done
    jmp .w
.done:
    ret

prompt32 db "XOS_32bit:/$ ", 0
sct32    dw 400

; =============================================================================
; 💻 SUB-SHELL DE 64-BITS (MODO LARGO)
; =============================================================================
[BITS 64]
XSH64_BUF equ 0x23000

_xsh_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax

_xsh_entry_64.loop:
    mov rsi, prompt64
    call print64
    jmp _xsh_entry_64.loop

print64:
    push rsi
.l: lodsb
    or al, al
    jz .r
    ; Salida directa a memoria de video en 64-bits
    push rbx
    movzx rbx, word [sct64]
    shl rbx, 1
    add rbx, VGA
    mov [rbx], al
    mov byte [rbx+1], 0x0B      ; Texto cyan
    inc word [sct64]
    pop rbx
    jmp .l
.r: pop rsi
    ret

prompt64 db "XOS_64bit:/$ ", 0
sct64    dw 800
