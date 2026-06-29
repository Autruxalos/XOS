
; =============================================================================
; XKERNEL - XOS Exokernel  [XSPEC-0004]
; Correccion principal:
;   - GDT correctamente formada (dq en vez de dw/dq mezclados)
;   - Far jump 16->32 con selector correcto
;   - Far jump 32->64 con GDT64 cargada ANTES del salto
;   - kernel_64_entry no puede seguir inmediatamente al codigo 32-bit
;     sin un far jump que flushee el pipeline y active Long Mode
; =============================================================================
[BITS 16]
org 0x9000
 
kernel_16_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x8000          ; pila 16-bit alejada del kernel
 
    mov si, msg_16
    call print16
    call print16_newline
 
    ; -------------------------------------------------------
    ; Subir a 32-bit Protected Mode
    ; -------------------------------------------------------
    lgdt [gdt32_ptr]
 
    mov eax, cr0
    or  eax, 1
    mov cr0, eax
 
    ; Far jump: flushea pipeline, activa PM, selector 0x08 = codigo 32-bit
    jmp 0x08:kernel_32_entry
 
; --- print16: imprime DS:SI via BIOS ---
print16:
    mov ah, 0x0E
    mov bx, 0x0007
.lp:
    lodsb
    or  al, al
    jz  .done
    int 0x10
    jmp .lp
.done:
    ret
 
print16_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret
 
msg_16 db 'XKERNEL 16-bit OK', 0
 
; -----------------------------------------------------------------------
; GDT de 32-bit
; Formato correcto: cada descriptor es exactamente 8 bytes (dq)
; -----------------------------------------------------------------------
align 8
gdt32_start:
    dq 0x0000000000000000   ; 0x00: descriptor nulo
    dq 0x00CF9A000000FFFF   ; 0x08: codigo 32-bit, base=0, limite=4GB, DPL=0
    dq 0x00CF92000000FFFF   ; 0x10: datos  32-bit, base=0, limite=4GB, DPL=0
gdt32_end:
 
gdt32_ptr:
    dw gdt32_end - gdt32_start - 1     ; limite
    dd gdt32_start                      ; base (32-bit)
 
; -----------------------------------------------------------------------
; GDT de 64-bit
; -----------------------------------------------------------------------
align 8
gdt64_start:
    dq 0x0000000000000000   ; 0x00: descriptor nulo
    dq 0x00209A0000000000   ; 0x08: codigo 64-bit (L=1, P=1, DPL=0)
    dq 0x0000920000000000   ; 0x10: datos  64-bit
gdt64_end:
 
gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start                      ; base 64-bit — IMPORTANTE: dq no dd
 
; -----------------------------------------------------------------------
; Stacks
; -----------------------------------------------------------------------
align 16
times 512 db 0
stack_top_32:               ; pila de 32-bit crece hacia abajo desde aqui
 
align 16
times 1024 db 0
stack_top_64:               ; pila de 64-bit crece hacia abajo desde aqui
 
; =============================================================================
; KERNEL 32-BIT
; =============================================================================
[BITS 32]
 
kernel_32_entry:
    ; Configurar segmentos de datos con selector 0x10
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, stack_top_32
 
    ; -------------------------------------------------------
    ; Habilitar PAE (necesario para Long Mode)
    ; -------------------------------------------------------
    mov eax, cr4
    or  eax, (1 << 5)       ; PAE bit
    mov cr4, eax
 
    ; -------------------------------------------------------
    ; Construir tabla de paginas minima (identidad 0-2MB)
    ; en 0x1000 (zona libre, debajo del bootloader)
    ; PML4[0] -> PDPT en 0x2000
    ; PDPT[0] -> PD   en 0x3000
    ; PD[0]   -> Huge page 2MB identidad (bit PS=1)
    ; -------------------------------------------------------
    ; Limpiar 12 KB desde 0x1000
    mov edi, 0x1000
    xor eax, eax
    mov ecx, (0x3000 / 4)
    rep stosd
 
    mov dword [0x1000], 0x00002003  ; PML4[0] -> 0x2000, presente+rw
    mov dword [0x2000], 0x00003003  ; PDPT[0] -> 0x3000, presente+rw
    mov dword [0x3000], 0x00000083  ; PD[0]   -> 2MB huge, presente+rw+PS
 
    mov eax, 0x1000
    mov cr3, eax
 
    ; -------------------------------------------------------
    ; Activar Long Mode en EFER MSR (0xC0000080)
    ; -------------------------------------------------------
    mov ecx, 0xC0000080
    rdmsr
    or  eax, (1 << 8)       ; LME bit
    wrmsr
 
    ; -------------------------------------------------------
    ; Cargar GDT de 64-bit y activar paginacion
    ; El puntero gdt64_ptr tiene base como dq (8 bytes)
    ; pero lgdt en 32-bit solo lee 6 bytes — esta bien
    ; -------------------------------------------------------
    lgdt [gdt64_ptr]
 
    mov eax, cr0
    or  eax, 0x80000001     ; PG + PE
    mov cr0, eax
 
    ; Far jump a 64-bit: selector 0x08 del GDT64
    jmp 0x08:kernel_64_entry
 
; =============================================================================
; KERNEL 64-BIT
; =============================================================================
[BITS 64]
 
kernel_64_entry:
    ; Configurar segmentos 64-bit
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack_top_64
 
    ; Limpiar pantalla VGA (80x25 celdas, atributo 0x07 = gris sobre negro)
    mov rdi, 0xB8000
    mov rcx, 80 * 25
    mov ax,  0x0720
    rep stosw
 
    ; Banner de inicio
    mov rsi, msg_banner
    mov rbx, 0xB8000
    call vga_print
 
    ; Ir a EXIT (que llama a XSH)
    call exit_main_executor
 
.halt:
    cli
    hlt
    jmp .halt
 
; -----------------------------------------------------------------------
; vga_print — escribe string RSI en VGA, posicion RBX, atributo 0x0A
; -----------------------------------------------------------------------
vga_print:
    push rax
    push rbx
    push rsi
.lp:
    lodsb
    test al, al
    jz   .done
    cmp  al, 10             ; newline
    je   .newline
    mov  ah, 0x0A           ; atributo verde
    mov  word [rbx], ax
    add  rbx, 2
    jmp  .lp
.newline:
    ; Calcular inicio de siguiente linea (cada linea = 80*2 = 160 bytes)
    ; Calcular offset actual, redondear a siguiente multiplo de 160
    mov  rax, rbx
    sub  rax, 0xB8000
    xor  rdx, rdx
    mov  rcx, 160
    div  rcx               ; rax = linea actual, rdx = offset en linea
    inc  rax               ; siguiente linea
    imul rax, 160
    add  rax, 0xB8000
    mov  rbx, rax
    jmp  .lp
.done:
    pop  rsi
    pop  rbx
    pop  rax
    ret
 
; Stubs de impresion (seran implementados por EXIT/XSH)
global xk_print
global xk_println
 
xk_print:
    call vga_print
    ret
 
xk_println:
    call vga_print
    ; Agregar newline manual — simplificado para v0.1
    ret
 
msg_banner:
    db 10
    db 'XOS Exokernel v0.1 [x86-64]', 10
    db 'Sin POSIX. Sin UNIX. Sin GNU.', 10
    db 'Iniciando EXIT...', 10, 0
 
; =============================================================================
; Inclusiones — EXIT, XSH, drivers
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
%include "src/apps/exofetch.asm"
%include "src/drivers/exfs.asm"
