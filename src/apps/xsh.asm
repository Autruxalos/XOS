; =============================================================================
; XSH - ENTORNO INTERACTIVO MONOLÍTICO MULTI-ARQUITECTURA (XOS)
; =============================================================================

; Silenciar advertencias de relocalización absoluta cruzada de NASM
[warning -reloc-abs-word]
[warning -reloc-abs-dword]
[warning -reloc-abs-qword]

CMD_LEN equ 32                  ; Longitud máxima de comandos soportada
VGA     equ 0xB8000             ; Dirección base de memoria de video de texto
COLS    equ 80                  ; Columnas estándar por fila en pantalla

; =============================================================================
; 💻 SECCIÓN 1: INTERFAZ INTERACTIVA DE 16-BITS (MODO REAL)
; =============================================================================
[BITS 16]
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
print16.l:
    lodsb
    or al, al
    jz print16.r
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp print16.l
print16.r:
    pop si
    pop ax
    ret

readline16:
    xor cx, cx
readline16.r:
    mov ah, 0x00
    int 0x16
    cmp al, 13                  ; Enter
    je readline16.enter
    cmp al, 8                   ; Backspace
    je readline16.bs
    cmp cx, CMD_LEN-1
    jae readline16.r
    mov [buf16 + ecx], al
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp readline16.r
readline16.bs:
    jcxz readline16.r
    dec cx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp readline16.r
readline16.enter:
    mov byte [buf16 + ecx], 0
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

strcmp16:
strcmp16.l:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne strcmp16.n
    or al, al
    jz strcmp16.e
    inc si
    inc di
    jmp strcmp16.l
strcmp16.e:
    clc
    ret
strcmp16.n:
    stc
    ret

dispatch16:
    mov si, buf16
    mov di, kver
    call strcmp16
    jnc dispatch16.ver

    mov si, buf16
    mov di, kclr
    call strcmp16
    jnc dispatch16.clr

    mov si, buf16
    mov di, khlt
    call strcmp16
    jnc dispatch16.hlt

    mov si, munk
    call print16
    jmp dispatch16.done

dispatch16.ver:
    mov si, mver
    call print16
    jmp dispatch16.done
dispatch16.clr:
    mov ax, 0x0003
    int 0x10
    jmp dispatch16.done
dispatch16.hlt:
    mov si, mhlt
    call print16
    cli
    hlt
dispatch16.done:
    ret

prompt16 db "XOS_16bit:/$ ", 0
kver     db "ver", 0
kclr     db "clear", 0
khlt     db "halt", 0
mver     db "XOS Shell v1.0 (16-bit Mode)", 13, 10, 0
munk     db "Error: Comando no reconocido.", 13, 10, 0
mhlt     db "Apagando el procesador de forma segura...", 13, 10, 0
buf16    times CMD_LEN db 0

; =============================================================================
; 💻 SECCIÓN 2: INTERFAZ INTERACTIVA DE 32-BITS (MODO PROTEGIDO)
; =============================================================================
[BITS 32]
XSH32_BUF  equ 0x11000

_xsh_entry_32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

_xsh_entry_32.loop:
    mov esi, prompt32
    call print32
    call readline32
    call dispatch32
    jmp _xsh_entry_32.loop

cls32:
    mov edi, VGA
    mov ecx, 80 * 25
    mov ax, 0x0720
    rep stosw
    mov dword [sct32], 0
    ret

putch32:
    push ebx
    movzx ebx, word [sct32]
    shl ebx, 1
    add ebx, VGA
    cmp al, 10
    je putch32.ok
    mov [ebx], al
    mov byte [ebx+1], 0x0A
    inc word [sct32]
    pop ebx
    ret
putch32.ok:
    call nl32
    pop ebx
    ret

print32:
    push esi
print32.l:
    lodsb
    or al, al
    jz print32.r
    call putch32
    jmp print32.l
print32.r:
    pop esi
    ret

nl32:
    movzx eax, word [sct32]
    mov ecx, COLS
    xor edx, edx
    div ecx
    inc eax
    mul ecx
    mov [sct32], ax
    ret

prompt32 db "XOS_32bit:/$ ", 0

readline32:
    xor ecx, ecx
readline32.w:
    in al, 0x64
    test al, 1
    jz readline32.w
    in al, 0x60
    test al, 0x80
    jnz readline32.w
    cmp al, 0x1C                ; Enter
    je readline32.ent
    cmp al, 0x10                ; Escaneo básico de tecla 'Q'
    je .is_q
    jmp readline32.w
.is_q:
    mov al, 'q'
    mov [XSH32_BUF + ecx], al
    inc ecx
    call putch32
    jmp readline32.w
readline32.ent:
    mov byte [XSH32_BUF + ecx], 0
    call nl32
    ret

strcmp32:
strcmp32.l:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne strcmp32.n
    or al, al
    jz strcmp32.e
    inc esi
    inc edi
    jmp strcmp32.l
strcmp32.e:
    clc
    ret
strcmp32.n:
    stc
    ret

dispatch32:
    mov esi, XSH32_BUF
    mov edi, kver32
    call strcmp32
    jnc dispatch32.ver

    mov esi, XSH32_BUF
    mov edi, kclr32
    call strcmp32
    jnc dispatch32.clr

    mov esi, XSH32_BUF
    mov edi, khlt32
    call strcmp32
    jnc dispatch32.hlt

    mov esi, munk32
    call print32
    jmp dispatch32.done

dispatch32.ver:
    mov esi, mver32
    call print32
    jmp dispatch32.done
dispatch32.clr:
    call cls32
    jmp dispatch32.done
dispatch32.hlt:
    mov esi, mhlt32
    call print32
    cli
    hlt
dispatch32.done:
    ret

sct32       dw 400
prompt32_str db "XOS_32bit:/$ ", 0
kver32      db "ver", 0
kclr32      db "clear", 0
khlt32      db "halt", 0
mver32      db "XOS Shell v1.0 (32-bit Protected Mode)", 10, 0
munk32      db "Error: Comando no reconocido.", 10, 0
mhlt32      db "Apagando entorno de 32-bits...", 10, 0

; =============================================================================
; 💻 SECCIÓN 3: INTERFAZ INTERACTIVA DE 64-BITS (MODO LARGO)
; =============================================================================
[BITS 64]
XSH64_BUF  equ 0x12000

_xsh_entry_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

_xsh_entry_64.loop:
    mov rsi, prompt64
    call print64
    call readline64
    call dispatch64
    jmp _xsh_entry_64.loop

cls64:
    mov rdi, VGA
    mov rcx, 80 * 25
    mov ax, 0x0B20              ; Fondo negro, texto Cyan claro
    rep stosw
    mov dword [sct64], 0
    ret

putch64:
    push rbx
    movzx rbx, word [sct64]
    shl rbx, 1
    add rbx, VGA
    cmp al, 10
    je putch64.ok
    mov [rbx], al
    mov byte [rbx+1], 0x0B      ; Color Cyan estético de tu shell
    inc word [sct64]
    pop rbx
    ret
putch64.ok:
    call nl64
    pop rbx
    ret

print64:
    push rsi
print64.l:
    lodsb
    or al, al
    jz print64.r
    call putch64
    jmp print64.l
print64.r:
    pop rsi
    ret

nl64:
    movzx rax, word [sct64]
    mov rcx, COLS
    xor rdx, rdx
    div rcx
    inc rax
    mul rcx
    mov [sct64], ax
    ret

prompt64 db "XOS_64bit:/$ ", 0

readline64:
    xor rcx, rcx
readline64.w:
    in al, 0x64
    test al, 1
    jz readline64.w
    in al, 0x60
    test al, 0x80
    jnz readline64.w
    cmp al, 0x1C                ; Enter
    je readline64.ent
    cmp al, 0x26                ; Escaneo básico de tecla 'L'
    je .is_l
    jmp readline64.w
.is_l:
    mov al, 'l'
    mov [XSH64_BUF + rcx], al
    inc rcx
    call putch64
    jmp readline64.w
readline64.ent:
    mov byte [XSH64_BUF + rcx], 0
    call nl64
    ret

strcmp64:
strcmp64.l:
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne strcmp64.n              ; Corregido: error de sintaxis previo eliminado
    or al, al
    jz strcmp64.e
    inc rsi
    inc rdi
    jmp strcmp64.l
strcmp64.e:
    clc
    ret
strcmp64.n:
    stc
    ret

dispatch64:
    mov rsi, XSH64_BUF
    mov rdi, kver64
    call strcmp64
    jnc dispatch64.ver

    mov rsi, XSH64_BUF
    mov rdi, kclr64
    call strcmp64
    jnc dispatch64.clr

    mov rsi, XSH64_BUF
    mov rdi, khlt64
    call strcmp64
    jnc dispatch64.hlt

    mov rsi, munk64
    call print64
    jmp dispatch64.done

dispatch64.ver:
    mov rsi, mver64
    call print64
    jmp dispatch64.done
dispatch64.clr:
    call cls64
    jmp dispatch64.done
dispatch64.hlt:
    mov rsi, mhlt64
    call print64
    cli
    hlt
dispatch64.done:
    ret

sct64       dw 800
prompt64_str db "XOS_64bit:/$ ", 0
kver64      db "ver", 0
kclr64      db "clear", 0
khlt64      db "halt", 0
mver64      db "XOS Shell v1.0 (64-bit Long Mode)", 10, 0
munk64      db "Error: Comando no reconocido.", 10, 0
mhlt64      db "Apagando entorno nativo de 64-bits...", 10, 0
