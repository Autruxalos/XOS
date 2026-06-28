; =============================================================================
; XKERNEL - EXOKERNEL PRINCIPAL [XSPEC-0004]
; Arquitectura: x86 multi-modo (16 / 32 / 64-bit)
; Ensamblador:  NASM
; Cargado por:  XBOOT en segmento 0x1000 (fisico 0x10000)
;
; MAPA DE ENTRY POINTS (offsets desde el inicio del binario):
;   +0x000 -> _xk_entry_16  (16-bit Real Mode)
;   +0x100 -> _xk_entry_32  (32-bit Protected Mode)
;   +0x200 -> _xk_entry_64  (64-bit Long Mode)
;
; XBOOT debe saltar a:
;   16-bit: jmp 0x1000:0x0000
;   32-bit: jmp (0x10000 + 0x100)  = 0x10100
;   64-bit: jmp (0x10000 + 0x200)  = 0x10200
; =============================================================================

; =============================================================================
; BLOQUE 16-BIT (offset 0x000 - 0x0FF)
; =============================================================================
bits 16
org 0x0000

_xk_entry_16:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000

    ; Modo video texto 80x25
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Imprimir banner
    mov si, msg_k16
    mov ah, 0x0E
    mov bx, 0x000A              ; Color verde
.print16:
    lodsb
    test al, al
    jz   .done16
    int  0x10
    jmp  .print16
.done16:
    ; Saltar a EXIT (cargado en 0x8000 fisico = seg 0x0800:0x0000)
    jmp 0x0800:0x0000

msg_k16 db 0x0D, 0x0A
        db '[XKERNEL] 16-bit OK - Iniciando EXIT...', 0x0D, 0x0A, 0

times 0x100 - ($-$$) db 0x00   ; Padding al offset 0x100

; =============================================================================
; BLOQUE 32-BIT (offset 0x100 - 0x1FF)
; =============================================================================
bits 32

_xk_entry_32:
    mov ax, 0x10                ; Selector datos GDT32
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Limpiar pantalla VGA
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax,  0x0720
    rep stosw

    ; Imprimir banner
    mov esi, msg_k32
    mov edi, 0xB8000
    mov ah,  0x0A               ; Atributo verde
.print32:
    lodsb
    test al, al
    jz   .done32
    mov  [edi], ax
    add  edi, 2
    jmp  .print32
.done32:
    ; Saltar a EXIT 32-bit (fisico 0x8100)
    jmp 0x8100

msg_k32 db '[XKERNEL] 32-bit OK - Iniciando EXIT...', 0

times 0x200 - ($-$$) db 0x00   ; Padding al offset 0x200

; =============================================================================
; BLOQUE 64-BIT (offset 0x200 - ...)
; =============================================================================
bits 64

_xk_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Limpiar pantalla VGA
    mov rdi, 0xB8000
    mov rcx, 80*25
    mov ax,  0x0720
    rep stosw

    ; Imprimir banner
    mov rsi, msg_k64
    mov rdi, 0xB8000
    mov ah,  0x0B               ; Atributo cyan
.print64:
    lodsb
    test al, al
    jz   .done64
    mov  word [rdi], ax
    add  rdi, 2
    jmp  .print64
.done64:
    ; Saltar a EXIT 64-bit (fisico 0x8200)
    mov rax, 0x8200
    jmp rax

msg_k64 db '[XKERNEL] 64-bit OK - Iniciando EXIT...', 0
