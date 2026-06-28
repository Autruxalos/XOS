; =============================================================================
; XSH32 - SHELL INTERACTIVA NATIVA DE 32-BITS (MODO PROTEGIDO / i386)
; =============================================================================
[BITS 32]

_shell_start_32:
    mov dword [cursor_offset], 480
    mov esi, prompt_msg
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

    movzx ebx, al               ; Extensión segura a 32-bits para índice
    mov al, [scan_to_ascii + ebx]
    cmp al, 0
    je shell_loop

echo_character:
    call print_char
    jmp shell_loop

handle_enter:
    call next_line
    mov esi, prompt_msg
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
    mov al, [esi]
    cmp al, 0
    je .done
    call print_char
    inc esi
    jmp .loop
.done:
    ret

print_char:
    push ebx
    push ecx
    mov ecx, [cursor_offset]
    shl ecx, 1
    add ecx, 0xB8000            ; Dirección física directa (sin segmentos)
    
    mov [ecx], al
    mov byte [ecx+1], 0x0A      ; Color: Verde Brillante
    
    inc dword [cursor_offset]
    cmp dword [cursor_offset], 2000
    jb .end
    mov dword [cursor_offset], 0
.end:
    pop ecx
    pop ebx
    ret

next_line:
    push eax
    push ebx
    push edx
    mov eax, [cursor_offset]
    mov ebx, 80
    xor edx, edx
    div ebx
    inc eax
    cmp eax, 25
    jb .ok
    xor eax, eax
.ok:
    mul ebx
    mov [cursor_offset], eax
    pop edx
    pop ebx
    pop eax
    ret

do_backspace:
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

; --- DATOS ---
cursor_offset dd 0
prompt_msg    db "XOS_32bit:/$ ", 0

scan_to_ascii:
    db 0,  0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,  0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0,  0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
