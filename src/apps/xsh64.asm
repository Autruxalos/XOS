; =============================================================================
; XSH64 - SHELL INTERACTIVA NATIVA DE 64-BITS (LONG MODE / AMD64)
; =============================================================================
[BITS 64]

_shell_start_64:
    mov dword [cursor_offset], 480
    lea rsi, [prompt_msg]       ; Carga de dirección relativa segura en Modo Largo
    call print_string

shell_loop:
    in al, 0x64
    test al, 1
    jz shell_loop

    in al, 0x60
    test al, 0x80
    jnz shell_loop

    cmp al, 0x1C                ; ENTER
    je handle_enter
    cmp al, 0x0E                ; BACKSPACE
    je handle_backspace
    cmp al, 0x39                ; ESPACIO
    je handle_space
    cmp al, 0x3A
    ja shell_loop

    movzx rbx, al
    lea rdi, [scan_to_ascii]
    mov al, [rdi + rbx]
    cmp al, 0
    je shell_loop

echo_character:
    call print_char
    jmp shell_loop

handle_enter:
    call next_line
    lea rsi, [prompt_msg]
    call print_string
    jmp shell_loop

handle_backspace:
    call do_backspace
    jmp shell_loop

handle_space:
    mov al, ' '
    call print_char
    jmp shell_loop

; --- SUBRUTINAS ---

print_string:
.loop:
    lodsb
    cmp al, 0
    je .done
    call print_char
    jmp .loop
.done:
    ret

print_char:
    push rbx
    movzx rbx, word [cursor_offset]
    shl rbx, 1
    add rbx, 0xB8000            ; Dirección de memoria de video lineal de 64-bits
    
    mov [rbx], al
    mov byte [rbx+1], 0x0B      ; Color: Cyan Brillante (Así confirmas visualmente)
    
    inc word [cursor_offset]
    cmp word [cursor_offset], 2000
    jb .end
    mov word [cursor_offset], 0
.end:
    pop rbx
    ret

next_line:
    push rax
    push rbx
    push rdx
    movzx rax, word [cursor_offset]
    mov rbx, 80
    xor rdx, rdx
    div rbx
    inc rax
    cmp rax, 25
    jb .ok
    xor rax, rax
.ok:
    mul rbx
    mov [cursor_offset], ax
    pop rdx
    pop rbx
    pop rax
    ret

do_backspace:
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

; --- DATOS ---
cursor_offset dw 0
prompt_msg    db "Autruxalos@XOS_64bit:/$ ", 0

scan_to_ascii:
    db 0,  0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,  0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0,  0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
