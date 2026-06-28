; =============================================================================
; XSH - SHELL INTERACTIVA FAT BINARY (16-BIT / 32-BIT / 64-BIT)
; =============================================================================
; Este archivo contiene el código máquina nativo para las 3 arquitecturas.
; Comparten las mismas funciones lógicas, pero usan los registros y el 
; direccionamiento de memoria correctos para cada era de procesadores.

; =============================================================================
; [ MODO REAL - 16 BITS ] -> COMPATIBILIDAD 8086
; =============================================================================
[BITS 16]

_shell_16:
    ; Configurar segmentos para Modo Real
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov word [cursor_offset], 480
    mov si, prompt_16
    call print_string_16

shell_loop_16:
    in al, 0x64
    test al, 1
    jz shell_loop_16

    in al, 0x60
    test al, 0x80
    jnz shell_loop_16

    cmp al, 0x1C                ; ENTER
    je handle_enter_16
    cmp al, 0x0E                ; BACKSPACE
    je handle_backspace_16
    cmp al, 0x39                ; ESPACIO
    je handle_space_16
    cmp al, 0x3A                
    ja shell_loop_16

    mov bx, ax
    xor bh, bh
    mov al, [scan_to_ascii + bx]
    cmp al, 0
    je shell_loop_16
    call print_char_16
    jmp shell_loop_16

handle_enter_16:
    call next_line_16
    mov si, prompt_16
    call print_string_16
    jmp shell_loop_16

handle_backspace_16:
    call do_backspace_16
    jmp shell_loop_16

handle_space_16:
    mov al, ' '
    call print_char_16
    jmp shell_loop_16

print_string_16:
.loop:
    lodsb
    cmp al, 0
    je .done
    call print_char_16
    jmp .loop
.done:
    ret

print_char_16:
    push bx
    push es
    mov bx, 0xB800              ; En 16-bits usamos segmentos para llegar a VGA
    mov es, bx
    mov bx, [cursor_offset]
    shl bx, 1
    mov byte [es:bx], al
    mov byte [es:bx+1], 0x0E
    inc word [cursor_offset]
    cmp word [cursor_offset], 2000
    jb .end
    mov word [cursor_offset], 0
.end:
    pop es
    pop bx
    ret

next_line_16:
    push ax
    push bx
    push dx
    mov ax, [cursor_offset]
    mov bx, 80
    xor dx, dx
    div bx
    inc ax
    cmp ax, 25
    jb .matrix_ok
    xor ax, ax
.matrix_ok:
    mul bx
    mov [cursor_offset], ax
    pop dx
    pop bx
    pop ax
    ret

do_backspace_16:
    push bx
    push es
    mov bx, [cursor_offset]
    cmp bx, 480
    jbe .blocked
    dec bx
    mov [cursor_offset], bx
    shl bx, 1
    mov ax, 0xB800
    mov es, ax
    mov byte [es:bx], ' '
    mov byte [es:bx+1], 0x0E
.blocked:
    pop es
    pop bx
    ret

align 16

; =============================================================================
; [ MODO PROTEGIDO - 32 BITS ] -> COMPATIBILIDAD i386
; =============================================================================
[BITS 32]

_shell_32:
    mov dword [cursor_offset], 480
    mov esi, prompt_32
    call print_string_32

shell_loop_32:
    in al, 0x64
    test al, 1
    jz shell_loop_32
    in al, 0x60
    test al, 0x80
    jnz shell_loop_32

    cmp al, 0x1C
    je handle_enter_32
    cmp al, 0x0E
    je handle_backspace_32
    cmp al, 0x39
    je handle_space_32
    cmp al, 0x3A
    ja shell_loop_32

    movzx ebx, al
    mov al, [scan_to_ascii + ebx]
    cmp al, 0
    je shell_loop_32
    call print_char_32
    jmp shell_loop_32

handle_enter_32:
    call next_line_32
    mov esi, prompt_32
    call print_string_32
    jmp shell_loop_32

handle_backspace_32:
    call do_backspace_32
    jmp shell_loop_32

handle_space_32:
    mov al, ' '
    call print_char_32
    jmp shell_loop_32

print_string_32:
.loop:
    mov al, [esi]
    cmp al, 0
    je .done
    call print_char_32
    inc esi
    jmp .loop
.done:
    ret

print_char_32:
    push ebx
    push ecx
    mov ecx, [cursor_offset]
    shl ecx, 1
    add ecx, 0xB8000            ; En 32-bits usamos memoria plana
    mov [ecx], al
    mov byte [ecx+1], 0x0A      ; Verde brillante para diferenciar 32-bits
    inc dword [cursor_offset]
    cmp dword [cursor_offset], 2000
    jb .end
    mov dword [cursor_offset], 0
.end:
    pop ecx
    pop ebx
    ret

next_line_32:
    push eax
    push ebx
    push edx
    mov eax, [cursor_offset]
    mov ebx, 80
    xor edx, edx
    div ebx
    inc eax
    cmp eax, 25
    jb .matrix_ok
    xor eax, eax
.matrix_ok:
    mul ebx
    mov [cursor_offset], eax
    pop edx
    pop ebx
    pop eax
    ret

do_backspace_32:
    push ebx
    mov ebx, [cursor_offset]
    cmp ebx, 480
    jbe .blocked
    dec ebx
    mov [cursor_offset], ebx
    shl ebx, 1
    add ebx, 0xB8000
    mov byte [ebx], ' '
    mov byte [ebx+1], 0x0A
.blocked:
    pop ebx
    ret

align 16

; =============================================================================
; [ MODO LARGO - 64 BITS ] -> COMPATIBILIDAD MODERNA (AMD64 / x86_64)
; =============================================================================
[BITS 64]

_shell_64:
    mov word [cursor_offset], 480
    lea rsi, [prompt_64]
    call print_string_64

shell_loop_64:
    in al, 0x64
    test al, 1
    jz shell_loop_64
    in al, 0x60
    test al, 0x80
    jnz shell_loop_64

    cmp al, 0x1C
    je handle_enter_64
    cmp al, 0x0E
    je handle_backspace_64
    cmp al, 0x39
    je handle_space_64
    cmp al, 0x3A
    ja shell_loop_64

    movzx rbx, al
    lea rdi, [scan_to_ascii]
    mov al, [rdi + rbx]
    cmp al, 0
    je shell_loop_64
    call print_char_64
    jmp shell_loop_64

handle_enter_64:
    call next_line_64
    lea rsi, [prompt_64]
    call print_string_64
    jmp shell_loop_64

handle_backspace_64:
    call do_backspace_64
    jmp shell_loop_64

handle_space_64:
    mov al, ' '
    call print_char_64
    jmp shell_loop_64

print_string_64:
.loop:
    lodsb
    cmp al, 0
    je .done
    call print_char_64
    jmp .loop
.done:
    ret

print_char_64:
    push rbx
    movzx rbx, word [cursor_offset]
    shl rbx, 1
    add rbx, 0xB8000
    mov [rbx], al
    mov byte [rbx+1], 0x0B      ; Cyan brillante para diferenciar 64-bits
    inc word [cursor_offset]
    cmp word [cursor_offset], 2000
    jb .end
    mov word [cursor_offset], 0
.end:
    pop rbx
    ret

next_line_64:
    push rax
    push rbx
    push rdx
    movzx rax, word [cursor_offset]
    mov rbx, 80
    xor rdx, rdx
    div rbx
    inc rax
    cmp rax, 25
    jb .matrix_ok
    xor rax, rax
.matrix_ok:
    mul rbx
    mov [cursor_offset], ax
    pop rdx
    pop rbx
    pop rax
    ret

do_backspace_64:
    push rbx
    movzx rbx, word [cursor_offset]
    cmp rbx, 480
    jbe .blocked
    dec rbx
    mov [cursor_offset], bx
    shl rbx, 1
    add rbx, 0xB8000
    mov byte [rbx], ' '
    mov byte [rbx+1], 0x0B
.blocked:
    pop rbx
    ret

align 16

; =============================================================================
; ZONA DE DATOS COMPARTIDA (SHARED MEMORY POOL)
; =============================================================================
cursor_offset dd 0

; Diferentes prompts para que sepas en qué arquitectura aterrizó el Kernel
prompt_16     db "XOS_16bit:/$ ", 0
prompt_32     db "XOS_32bit:/$ ", 0
prompt_64     db "Autruxalos@XOS_64bit:/$ ", 0

scan_to_ascii:
    db 0,  0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,  0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0,  0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
