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
org 0x0000                      ; Suponiendo segmentación limpia base 0x2000:0x0000

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
    cmp al, 13
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
    mov al, 13 \ int 0x10 \ mov al, 10 \ int 0x10
    ret

dispatch16:
    ; (Tu lógica de strcmp16 / comandos para 16-bits aquí...)
    ret

prompt16 db "XOS_16bit:/$ ", 0
buf16    times CMD_LEN db 0

; =============================================================================
; 💻 SUB-SHELL DE 32-BITS (MODO PROTEGIDO)
; =============================================================================
[BITS 32]
XSH32_BUF equ 0x22000           ; Buffer reubicado de forma segura fuera del código

_xsh_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax

_xsh_entry_32.loop:
    mov esi, prompt32
    call print32
    call readline32
    ; call dispatch32
    jmp _xsh_entry_32.loop

putch32:
    push ebx                    ; Corregido: ya no es 'bpt'
    movzx ebx, word [sct32]
    shl ebx, 1
    add ebx, VGA
    mov [ebx], al
    mov byte [ebx+1], 0x0A      ; Atributo de texto verde
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
    ; Lógica de polling de teclado IN AL, 0x60 sin bloqueos de interrupción...
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
    ; call readline64; =============================================================================
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
org 0x0000                      ; Suponiendo segmentación limpia base 0x2000:0x0000

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
    cmp al, 13
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
    mov al, 13 \ int 0x10 \ mov al, 10 \ int 0x10
    ret

dispatch16:
    ; (Tu lógica de strcmp16 / comandos para 16-bits aquí...)
    ret

prompt16 db "XOS_16bit:/$ ", 0
buf16    times CMD_LEN db 0

; =============================================================================
; 💻 SUB-SHELL DE 32-BITS (MODO PROTEGIDO)
; =============================================================================
[BITS 32]
XSH32_BUF equ 0x22000           ; Buffer reubicado de forma segura fuera del código

_xsh_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax

_xsh_entry_32.loop:
    mov esi, prompt32
    call print32
    call readline32
    ; call dispatch32
    jmp _xsh_entry_32.loop

putch32:
    push ebx                    ; Corregido: ya no es 'bpt'
    movzx ebx, word [sct32]
    shl ebx, 1
    add ebx, VGA
    mov [ebx], al
    mov byte [ebx+1], 0x0A      ; Atributo de texto verde
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
    ; Lógica de polling de teclado IN AL, 0x60 sin bloqueos de interrupción...
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
    ; call readline64
    jmp _xsh_entry_64.loop

print64:
    push rsi
.l: lodsb
    or al, al
    jz .r
    ; Rutina de impresión de caracteres a video en 64 bits...
    jmp .l
.r: pop rsi
    ret

prompt64 db "XOS_64bit:/$ ", 0
    jmp _xsh_entry_64.loop

print64:
    push rsi
.l: lodsb
    or al, al
    jz .r
    ; Rutina de impresión de caracteres a video en 64 bits...
    jmp .l
.r: pop rsi
    ret

prompt64 db "XOS_64bit:/$ ", 0
