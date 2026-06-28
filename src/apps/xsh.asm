; =============================================================================
; XSH - EXOKERNEL SHELL [XSPEC-0006]
; Cargado en 0x20000 fisico
; ENTRY POINTS:
;   +0x000 -> _xsh_entry_16
;   +0x100 -> _xsh_entry_32
;   +0x200 -> _xsh_entry_64
; Comandos: ver, clear, halt
; Prompt: |
; =============================================================================

CMD_LEN equ 64

; =============================================================================
; XSH 16-BIT
; =============================================================================
bits 16
org 0x0000

_xsh_entry_16:
.loop:
    mov si, prompt16
    call print16
    mov di, buf16
    call readline16
    call dispatch16
    jmp .loop

print16:
    mov ah, 0x0E
    mov bx, 0x000A
.l: lodsb
    test al, al
    jz   .r
    int  0x10
    jmp  .l
.r: ret

readline16:
    mov cx, CMD_LEN-1
.r: mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je  .enter
    cmp al, 0x08
    je  .bs
    jcxz .r
    stosb
    dec cx
    mov ah, 0x0E
    mov bx, 0x000F
    int 0x10
    jmp .r
.bs:
    cmp di, buf16
    je  .r
    dec di
    inc cx
    mov ah, 0x0E
    mov bx, 0x000F
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .r
.enter:
    xor al, al
    stosb
    mov ah, 0x0E
    mov bx, 0x000F
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

strcmp16:           ; SI vs DI -> ZF si iguales
.l: mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .n
    test al, al
    jz  .e
    inc si
    inc di
    jmp .l
.e: ret
.n: or al, 1
    ret

dispatch16:
    mov si, buf16
    cmp byte [si], 0
    je  .done

    mov di, kver
    call strcmp16
    je  .ver
    mov si, buf16
    mov di, kclr
    call strcmp16
    je  .clr
    mov si, buf16
    mov di, khlt
    call strcmp16
    je  .hlt
    mov si, munk
    call print16
    jmp .done
.ver: mov si, mver
    call print16
    jmp .done
.clr: mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp .done
.hlt: mov si, mhlt
    call print16
    cli
    hlt
.done: ret

prompt16  db 0x0D, 0x0A, '| ', 0
kver      db 'ver', 0
kclr      db 'clear', 0
khlt      db 'halt', 0
mver      db 'XSH v0.1 [16-bit] | XOS Exokernel | Sin POSIX. Sin GNU.', 0x0D, 0x0A, 0
munk      db 'XSH: desconocido', 0x0D, 0x0A, 0
mhlt      db 'XOS: detenido.', 0x0D, 0x0A, 0
buf16     times CMD_LEN db 0

times 0x200 - ($-$$) db 0x00   ; Padding bloque 16-bit (512 bytes)

; =============================================================================
; XSH 32-BIT
; =============================================================================
bits 32

XSH32_CURX equ 0x7000
XSH32_CURY equ 0x7004
XSH32_BUF  equ 0x7010
VGA        equ 0xB8000
COLS       equ 80

_xsh_entry_32:
    mov dword [XSH32_CURX], 0
    mov dword [XSH32_CURY], 2   ; Empezar en linea 2
    call cls32
.loop:
    call prompt32
    mov  edi, XSH32_BUF
    call readline32
    call dispatch32
    jmp  .loop

cls32:
    mov edi, VGA
    mov ecx, COLS*25
    mov ax,  0x0720
    rep stosw
    ret

putch32:  ; AL=char AH=attr
    push eax
    push ebx
    mov  ebx, [XSH32_CURY]
    imul ebx, COLS
    add  ebx, [XSH32_CURX]
    lea  ebx, [VGA + ebx*2]
    mov  [ebx], ax
    inc  dword [XSH32_CURX]
    cmp  dword [XSH32_CURX], COLS
    jl   .ok
    mov  dword [XSH32_CURX], 0
    inc  dword [XSH32_CURY]
.ok:
    pop ebx
    pop eax
    ret

print32:  ; ESI=str, color verde
    push eax
    mov ah, 0x0A
.l: lodsb
    test al, al
    jz  .r
    call putch32
    jmp .l
.r: pop eax
    ret

nl32:
    mov dword [XSH32_CURX], 0
    inc dword [XSH32_CURY]
    ret

prompt32:
    mov esi, prompt32_str
    call print32
    ret

readline32:
    mov ecx, CMD_LEN-1
.w: in   al, 0x64
    test al, 1
    jz   .w
    in   al, 0x60
    cmp  al, 0x80
    jge  .w
    push ebx
    lea  ebx, [sct32]
    xlat
    pop  ebx
    test al, al
    jz   .w
    cmp  al, 0x0D
    je   .ent
    test ecx, ecx
    jz   .w
    push eax
    stosb
    dec  ecx
    mov  ah, 0x0F
    call putch32
    pop  eax
    jmp  .w
.ent:
    xor al, al
    stosb
    call nl32
    ret

strcmp32: ; ESI vs EDI
.l: mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .n
    test al, al
    jz  .e
    inc esi
    inc edi
    jmp .l
.e: ret
.n: or al, 1
    ret

dispatch32:
    mov esi, XSH32_BUF
    cmp byte [esi], 0
    je  .done
    mov edi, kver32
    call strcmp32
    je  .ver
    mov esi, XSH32_BUF
    mov edi, kclr32
    call strcmp32
    je  .clr
    mov esi, XSH32_BUF
    mov edi, khlt32
    call strcmp32
    je  .hlt
    mov esi, munk32
    call print32
    call nl32
    jmp .done
.ver: mov esi, mver32
    call print32
    call nl32
    jmp .done
.clr: call cls32
    jmp .done
.hlt: mov esi, mhlt32
    call print32
    cli
    hlt
.done: ret

sct32:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',';',39,96,0,92
    db 'z','x','c','v','b','n','m',',','.','/',0,0,0,' '
    times (256-($ - sct32)) db 0

prompt32_str db '| ', 0
kver32       db 'ver', 0
kclr32       db 'clear', 0
khlt32       db 'halt', 0
mver32       db 'XSH v0.1 [32-bit] | XOS Exokernel | Sin POSIX. Sin GNU.', 0
munk32       db 'XSH: desconocido', 0
mhlt32       db 'XOS: detenido.', 0

times 0x600 - ($-$$) db 0x00   ; Padding bloque 32-bit (1536 bytes)

; =============================================================================
; XSH 64-BIT
; =============================================================================
bits 64

XSH64_CURX equ 0x7100
XSH64_CURY equ 0x7108
XSH64_BUF  equ 0x7110

_xsh_entry_64:
    mov qword [XSH64_CURX], 0
    mov qword [XSH64_CURY], 2
    call cls64
.loop:
    call prompt64
    mov  rdi, XSH64_BUF
    call readline64
    call dispatch64
    jmp  .loop

cls64:
    mov rdi, VGA
    mov rcx, COLS*25
    mov ax,  0x0720
    rep stosw
    ret

putch64:
    push rax
    push rbx
    mov  rbx, [XSH64_CURY]
    imul rbx, COLS
    add  rbx, [XSH64_CURX]
    lea  rbx, [VGA + rbx*2]
    mov  word [rbx], ax
    inc  qword [XSH64_CURX]
    cmp  qword [XSH64_CURX], COLS
    jl   .ok
    mov  qword [XSH64_CURX], 0
    inc  qword [XSH64_CURY]
.ok:
    pop rbx
    pop rax
    ret

print64:
    push rax
    mov ah, 0x0A
.l: lodsb
    test al, al
    jz  .r
    call putch64
    jmp .l
.r: pop rax
    ret

nl64:
    mov qword [XSH64_CURX], 0
    inc qword [XSH64_CURY]
    ret

prompt64:
    mov rsi, prompt64_str
    call print64
    ret

readline64:
    mov rcx, CMD_LEN-1
.w: in   al, 0x64
    test al, 1
    jz   .w
    in   al, 0x60
    cmp  al, 0x80
    jge  .w
    push rbx
    lea  rbx, [rel sct64]
    xlat
    pop  rbx
    test al, al
    jz   .w
    cmp  al, 0x0D
    je   .ent
    test rcx, rcx
    jz   .w
    push rax
    stosb
    dec  rcx
    mov  ah, 0x0F
    call putch64
    pop  rax
    jmp  .w
.ent:
    xor al, al
    stosb
    call nl64
    ret

strcmp64:
.l: mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .n
    test al, al
    jz  .e
    inc rsi
    inc rdi
    jmp .l
.e: ret
.n: or al, 1
    ret

dispatch64:
    mov rsi, XSH64_BUF
    cmp byte [rsi], 0
    je  .done
    mov rdi, kver64
    call strcmp64
    je  .ver
    mov rsi, XSH64_BUF
    mov rdi, kclr64
    call strcmp64
    je  .clr
    mov rsi, XSH64_BUF
    mov rdi, khlt64
    call strcmp64
    je  .hlt
    mo; =============================================================================
; XSH - EXOKERNEL SHELL [XSPEC-0006]
; Cargado en 0x20000 fisico
; ENTRY POINTS:
;   +0x000 -> _xsh_entry_16
;   +0x100 -> _xsh_entry_32
;   +0x200 -> _xsh_entry_64
; Comandos: ver, clear, halt
; Prompt: |
; =============================================================================

CMD_LEN equ 64

; =============================================================================
; XSH 16-BIT
; =============================================================================
bits 16
org 0x0000

_xsh_entry_16:
.loop:
    mov si, prompt16
    call print16
    mov di, buf16
    call readline16
    call dispatch16
    jmp .loop

print16:
    mov ah, 0x0E
    mov bx, 0x000A
.l: lodsb
    test al, al
    jz   .r
    int  0x10
    jmp  .l
.r: ret

readline16:
    mov cx, CMD_LEN-1
.r: mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je  .enter
    cmp al, 0x08
    je  .bs
    jcxz .r
    stosb
    dec cx
    mov ah, 0x0E
    mov bx, 0x000F
    int 0x10
    jmp .r
.bs:
    cmp di, buf16
    je  .r
    dec di
    inc cx
    mov ah, 0x0E
    mov bx, 0x000F
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .r
.enter:
    xor al, al
    stosb
    mov ah, 0x0E
    mov bx, 0x000F
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

strcmp16:           ; SI vs DI -> ZF si iguales
.l: mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .n
    test al, al
    jz  .e
    inc si
    inc di
    jmp .l
.e: ret
.n: or al, 1
    ret

dispatch16:
    mov si, buf16
    cmp byte [si], 0
    je  .done

    mov di, kver
    call strcmp16
    je  .ver
    mov si, buf16
    mov di, kclr
    call strcmp16
    je  .clr
    mov si, buf16
    mov di, khlt
    call strcmp16
    je  .hlt
    mov si, munk
    call print16
    jmp .done
.ver: mov si, mver
    call print16
    jmp .done
.clr: mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp .done
.hlt: mov si, mhlt
    call print16
    cli
    hlt
.done: ret

prompt16  db 0x0D, 0x0A, '| ', 0
kver      db 'ver', 0
kclr      db 'clear', 0
khlt      db 'halt', 0
mver      db 'XSH v0.1 [16-bit] | XOS Exokernel | Sin POSIX. Sin GNU.', 0x0D, 0x0A, 0
munk      db 'XSH: desconocido', 0x0D, 0x0A, 0
mhlt      db 'XOS: detenido.', 0x0D, 0x0A, 0
buf16     times CMD_LEN db 0

times 0x200 - ($-$$) db 0x00   ; Padding bloque 16-bit (512 bytes)

; =============================================================================
; XSH 32-BIT
; =============================================================================
bits 32

XSH32_CURX equ 0x7000
XSH32_CURY equ 0x7004
XSH32_BUF  equ 0x7010
VGA        equ 0xB8000
COLS       equ 80

_xsh_entry_32:
    mov dword [XSH32_CURX], 0
    mov dword [XSH32_CURY], 2   ; Empezar en linea 2
    call cls32
.loop:
    call prompt32
    mov  edi, XSH32_BUF
    call readline32
    call dispatch32
    jmp  .loop

cls32:
    mov edi, VGA
    mov ecx, COLS*25
    mov ax,  0x0720
    rep stosw
    ret

putch32:  ; AL=char AH=attr
    push eax
    push ebx
    mov  ebx, [XSH32_CURY]
    imul ebx, COLS
    add  ebx, [XSH32_CURX]
    lea  ebx, [VGA + ebx*2]
    mov  [ebx], ax
    inc  dword [XSH32_CURX]
    cmp  dword [XSH32_CURX], COLS
    jl   .ok
    mov  dword [XSH32_CURX], 0
    inc  dword [XSH32_CURY]
.ok:
    pop ebx
    pop eax
    ret

print32:  ; ESI=str, color verde
    push eax
    mov ah, 0x0A
.l: lodsb
    test al, al
    jz  .r
    call putch32
    jmp .l
.r: pop eax
    ret

nl32:
    mov dword [XSH32_CURX], 0
    inc dword [XSH32_CURY]
    ret

prompt32:
    mov esi, prompt32_str
    call print32
    ret

readline32:
    mov ecx, CMD_LEN-1
.w: in   al, 0x64
    test al, 1
    jz   .w
    in   al, 0x60
    cmp  al, 0x80
    jge  .w
    push ebx
    lea  ebx, [sct32]
    xlat
    pop  ebx
    test al, al
    jz   .w
    cmp  al, 0x0D
    je   .ent
    test ecx, ecx
    jz   .w
    push eax
    stosb
    dec  ecx
    mov  ah, 0x0F
    call putch32
    pop  eax
    jmp  .w
.ent:
    xor al, al
    stosb
    call nl32
    ret

strcmp32: ; ESI vs EDI
.l: mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .n
    test al, al
    jz  .e
    inc esi
    inc edi
    jmp .l
.e: ret
.n: or al, 1
    ret

dispatch32:
    mov esi, XSH32_BUF
    cmp byte [esi], 0
    je  .done
    mov edi, kver32
    call strcmp32
    je  .ver
    mov esi, XSH32_BUF
    mov edi, kclr32
    call strcmp32
    je  .clr
    mov esi, XSH32_BUF
    mov edi, khlt32
    call strcmp32
    je  .hlt
    mov esi, munk32
    call print32
    call nl32
    jmp .done
.ver: mov esi, mver32
    call print32
    call nl32
    jmp .done
.clr: call cls32
    jmp .done
.hlt: mov esi, mhlt32
    call print32
    cli
    hlt
.done: ret

sct32:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',';',39,96,0,92
    db 'z','x','c','v','b','n','m',',','.','/',0,0,0,' '
    times (256-($ - sct32)) db 0

prompt32_str db '| ', 0
kver32       db 'ver', 0
kclr32       db 'clear', 0
khlt32       db 'halt', 0
mver32       db 'XSH v0.1 [32-bit] | XOS Exokernel | Sin POSIX. Sin GNU.', 0
munk32       db 'XSH: desconocido', 0
mhlt32       db 'XOS: detenido.', 0

times 0x600 - ($-$$) db 0x00   ; Padding bloque 32-bit (1536 bytes)

; =============================================================================
; XSH 64-BIT
; =============================================================================
bits 64

XSH64_CURX equ 0x7100
XSH64_CURY equ 0x7108
XSH64_BUF  equ 0x7110

_xsh_entry_64:
    mov qword [XSH64_CURX], 0
    mov qword [XSH64_CURY], 2
    call cls64
.loop:
    call prompt64
    mov  rdi, XSH64_BUF
    call readline64
    call dispatch64
    jmp  .loop

cls64:
    mov rdi, VGA
    mov rcx, COLS*25
    mov ax,  0x0720
    rep stosw
    ret

putch64:
    push rax
    push rbx
    mov  rbx, [XSH64_CURY]
    imul rbx, COLS
    add  rbx, [XSH64_CURX]
    lea  rbx, [VGA + rbx*2]
    mov  word [rbx], ax
    inc  qword [XSH64_CURX]
    cmp  qword [XSH64_CURX], COLS
    jl   .ok
    mov  qword [XSH64_CURX], 0
    inc  qword [XSH64_CURY]
.ok:
    pop rbx
    pop rax
    ret

print64:
    push rax
    mov ah, 0x0A
.l: lodsb
    test al, al
    jz  .r
    call putch64
    jmp .l
.r: pop rax
    ret

nl64:
    mov qword [XSH64_CURX], 0
    inc qword [XSH64_CURY]
    ret

prompt64:
    mov rsi, prompt64_str
    call print64
    ret

readline64:
    mov rcx, CMD_LEN-1
.w: in   al, 0x64
    test al, 1
    jz   .w
    in   al, 0x60
    cmp  al, 0x80
    jge  .w
    push rbx
    lea  rbx, [rel sct64]
    xlat
    pop  rbx
    test al, al
    jz   .w
    cmp  al, 0x0D
    je   .ent
    test rcx, rcx
    jz   .w
    push rax
    stosb
    dec  rcx
    mov  ah, 0x0F
    call putch64
    pop  rax
    jmp  .w
.ent:
    xor al, al
    stosb
    call nl64
    ret

strcmp64:
.l: mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .n
    test al, al
    jz  .e
    inc rsi
    inc rdi
    jmp .l
.e: ret
.n: or al, 1
    ret

dispatch64:
    mov rsi, XSH64_BUF
    cmp byte [rsi], 0
    je  .done
    mov rdi, kver64
    call strcmp64
    je  .ver
    mov rsi, XSH64_BUF
    mov rdi, kclr64
    call strcmp64
    je  .clr
    mov rsi, XSH64_BUF
    mov rdi, khlt64
    call strcmp64
    je  .hlt
    mov rsi, munk64
    call print64
    call nl64
    jmp .done
.ver: mov rsi, mver64
    call print64
    call nl64
    jmp .done
.clr: call cls64
    jmp .done
.hlt: mov rsi, mhlt64
    call print64
    cli
    hlt
.done: ret

sct64:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',';',39,96,0,92
    db 'z','x','c','v','b','n','m',',','.','/',0,0,0,' '
    times (256-($ - sct64)) db 0

prompt64_str db '| ', 0
kver64       db 'ver', 0
kclr64       db 'clear', 0
khlt64       db 'halt', 0
mver64       db 'XSH v0.1 [64-bit] | XOS Exokernel | Sin POSIX. Sin GNU.', 0
munk64       db 'XSH: desconocido', 0
mhlt64       db 'XOS: detenido.', 0v rsi, munk64
    call print64
    call nl64
    jmp .done
.ver: mov rsi, mver64
    call print64
    call nl64
    jmp .done
.clr: call cls64
    jmp .done
.hlt: mov rsi, mhlt64
    call print64
    cli
    hlt
.done: ret

sct64:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',';',39,96,0,92
    db 'z','x','c','v','b','n','m',',','.','/',0,0,0,' '
    times (256-($ - sct64)) db 0

prompt64_str db '| ', 0
kver64       db 'ver', 0
kclr64       db 'clear', 0
khlt64       db 'halt', 0
mver64       db 'XSH v0.1 [64-bit] | XOS Exokernel | Sin POSIX. Sin GNU.', 0
munk64       db 'XSH: desconocido', 0
mhlt64       db 'XOS: detenido.', 0
