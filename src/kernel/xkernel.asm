; =============================================================================
; XKERNEL - XOS Exokernel  [XSPEC-0004]
; =============================================================================
mov ax,0xb800
mov es,ax

mov byte [es:0],'K'
mov byte [es:1],0x0A

jmp $
 
print16:
    mov ah, 0x0E
    mov bx, 0x0007
.lp:
    lodsb
    or  al, al
    jz  .ret
    int 0x10
    jmp .lp
.ret:
    ret
 
msg_16 db 'XKERNEL 16-bit OK', 13, 10, 0
 
; -----------------------------------------------------------------------
; GDT 32-bit
; -----------------------------------------------------------------------
align 8
gdt32_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF   ; 0x08 codigo 32-bit
    dq 0x00CF92000000FFFF   ; 0x10 datos  32-bit
gdt32_end:
gdt32_ptr:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start
 
; -----------------------------------------------------------------------
; GDT 64-bit
; -----------------------------------------------------------------------
align 8
gdt64_start:
    dq 0x0000000000000000
    dq 0x00209A0000000000   ; 0x08 codigo 64-bit
    dq 0x0000920000000000   ; 0x10 datos  64-bit
gdt64_end:
gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start
 
; -----------------------------------------------------------------------
; Stacks
; -----------------------------------------------------------------------
align 16
times 512  db 0
stack_top_32:
 
align 16
times 1024 db 0
stack_top_64:
 
; =============================================================================
; KERNEL 32-BIT
; =============================================================================
[BITS 32]
 
kernel_32_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_top_32
 
    ; Habilitar PAE
    mov eax, cr4
    or  eax, (1 << 5)
    mov cr4, eax
 
    ; Tablas de paginas identidad 0-2MB en 0x1000
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 0x3000 / 4
    rep stosd
    mov dword [0x1000], 0x2003
    mov dword [0x2000], 0x3003
    mov dword [0x3000], 0x0083
    mov eax, 0x1000
    mov cr3, eax
 
    ; Activar Long Mode en EFER
    mov ecx, 0xC0000080
    rdmsr
    or  eax, (1 << 8)
    wrmsr
 
    ; Cargar GDT64 y activar paginacion
    lgdt [gdt64_ptr]
    mov eax, cr0
    or  eax, 0x80000001
    mov cr0, eax
 
    jmp 0x08:kernel_64_entry
 
; =============================================================================
; KERNEL 64-BIT
; =============================================================================
[BITS 64]
 
kernel_64_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64
 
    call xk_init_video
    call exit_main_executor
 
.halt:
    cli
    hlt
    jmp .halt
 
; =============================================================================
; VARIABLES GLOBALES (declaradas aqui para que exfs/xsh/exit las encuentren)
; =============================================================================
global cursor_pos
global readline_buf
global exfs_cur_dir_name
 
cursor_pos:        dw 0
readline_buf:      times 256 db 0
exfs_cur_dir_name: db '|', 0
                   times 127 db 0
 
; =============================================================================
; VIDEO
; =============================================================================
global xk_init_video
xk_init_video:
    push rdi
    push rcx
    push rax
    mov  rdi, 0xB8000
    mov  rcx, 80 * 25
    mov  ax,  0x0720
    rep  stosw
    mov  word [cursor_pos], 0
    pop  rax
    pop  rcx
    pop  rdi
    ret
 
; =============================================================================
; TECLADO
; =============================================================================
global xk_init_keyboard
xk_init_keyboard:
    push rax
.flush:
    in   al, 0x64
    test al, 1
    jz   .done
    in   al, 0x60
    jmp  .flush
.done:
    pop  rax
    ret
 
; =============================================================================
; SCROLL
; =============================================================================
global xk_scroll
xk_scroll:
    push rsi
    push rdi
    push rcx
    cld
    mov  rsi, 0xB8000 + 80 * 2
    mov  rdi, 0xB8000
    mov  rcx, 80 * 24
    rep  movsw
    mov  rdi, 0xB8000 + 80 * 24 * 2
    mov  rcx, 80
    mov  ax,  0x0720
    rep  stosw
    mov  word [cursor_pos], 80 * 24
    pop  rcx
    pop  rdi
    pop  rsi
    ret
 
; =============================================================================
; PUTCHAR — AL = caracter, BL = atributo color
; =============================================================================
global xk_putchar
xk_putchar:
    push rax
    push rbx
    push rcx
    push rdi
 
    cmp  al, 10
    je   .newline
    cmp  al, 13
    je   .cr
    cmp  al, 8
    je   .backspace
 
    ; Escribir en VGA
    movzx rcx, word [cursor_pos]
    cmp   rcx, 80 * 25
    jl    .write
    call  xk_scroll
    movzx rcx, word [cursor_pos]
.write:
    shl   rcx, 1
    add   rcx, 0xB8000
    mov   ah, bl
    mov   word [rcx], ax
    inc   word [cursor_pos]
    jmp   .done
 
.newline:
    movzx rax, word [cursor_pos]
    xor   rdx, rdx
    push  rbx
    mov   rbx, 80
    div   rbx
    inc   rax
    imul  rax, 80
    pop   rbx
    cmp   rax, 80 * 25
    jl    .setnl
    call  xk_scroll
    movzx rax, word [cursor_pos]
    jmp   .done
.setnl:
    mov   word [cursor_pos], ax
    jmp   .done
 
.cr:
    movzx rax, word [cursor_pos]
    xor   rdx, rdx
    push  rbx
    mov   rbx, 80
    div   rbx
    imul  rax, 80
    pop   rbx
    mov   word [cursor_pos], ax
    jmp   .done
 
.backspace:
    cmp   word [cursor_pos], 0
    je    .done
    dec   word [cursor_pos]
    movzx rcx, word [cursor_pos]
    shl   rcx, 1
    add   rcx, 0xB8000
    mov   word [rcx], 0x0720
    jmp   .done
 
.done:
    pop  rdi
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; =============================================================================
; PRINT — RSI = string, BL = color
; =============================================================================
global xk_print
xk_print:
    push rax
    push rsi
.lp:
    lodsb
    test al, al
    jz   .done
    call xk_putchar
    jmp  .lp
.done:
    pop  rsi
    pop  rax
    ret
 
; =============================================================================
; PRINTLN — RSI = string, BL = color + newline
; =============================================================================
global xk_println
xk_println:
    call xk_print
    push rax
    push rbx
    mov  al, 10
    mov  bl, 0x07
    call xk_putchar
    pop  rbx
    pop  rax
    ret
 
; =============================================================================
; READLINE — RDI = buffer destino, RCX = max chars, retorna RAX = longitud
; =============================================================================
scancode_map:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',59,39,96,0,92
    db 'z','x','c','v','b','n','m',44,46,47,0,0,0,32
    times (256 - ($ - scancode_map)) db 0
 
global xk_readline
xk_readline:
    push rbx
    push rdx
    push rdi
    push rcx
 
    xor  rdx, rdx           ; longitud = 0
 
.rd:
    in   al, 0x64
    test al, 1
    jz   .rd
    in   al, 0x60
 
    cmp  al, 0x80           ; key-up, ignorar
    jge  .rd
 
    push rbx
    lea  rbx, [rel scancode_map]
    movzx rax, al
    mov  al, [rbx + rax]
    pop  rbx
 
    test al, al
    jz   .rd
 
    cmp  al, 13
    je   .enter
    cmp  al, 8
    je   .bs
 
    cmp  rdx, rcx
    jge  .rd
    mov  [rdi], al
    inc  rdi
    inc  rdx
    mov  bl, 0x0F
    call xk_putchar
    jmp  .rd
 
.bs:
    test rdx, rdx
    jz   .rd
    dec  rdi
    dec  rdx
    push rax
    mov  al, 8
    mov  bl, 0x07
    call xk_putchar
    mov  al, ' '
    call xk_putchar
    mov  al, 8
    call xk_putchar
    pop  rax
    jmp  .rd
 
.enter:
    mov  byte [rdi], 0
    mov  rax, rdx
    push rax
    mov  al, 10
    mov  bl, 0x07
    call xk_putchar
    pop  rax
    pop  rcx
    pop  rdi
    pop  rdx
    pop  rbx
    ret
 
; =============================================================================
; STRCMP — RSI vs RDI, retorna RAX=0 si iguales
; =============================================================================
global xk_strcmp
xk_strcmp:
    push rsi
    push rdi
    push rbx
.lp:
    mov  al, [rsi]
    mov  bl, [rdi]
    cmp  al, bl
    jne  .neq
    test al, al
    jz   .eq
    inc  rsi
    inc  rdi
    jmp  .lp
.eq:
    xor  rax, rax
    pop  rbx
    pop  rdi
    pop  rsi
    ret
.neq:
    mov  rax, 1
    pop  rbx
    pop  rdi
    pop  rsi
    ret
 
; =============================================================================
; INCLUSIONES
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
%include "src/apps/exofetch.asm"
%include "src/drivers/exfs.asm"
