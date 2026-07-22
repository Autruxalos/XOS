; =============================================================================
; XKERNEL — XOS Exokernel [XSPEC-0004]  v0.1
; Arquitectura:  x86-64 Long Mode
; Ensamblador:   NASM
; Entrada:       GRUB Multiboot2 (32-bit protected mode)
; Carga física:  1 MB (0x100000)
;
; GRUB nos entrega en 32-bit protected mode con A20 activo.
; Subimos a 64-bit, inicializamos VGA + teclado + EXFS, y llamamos a XSH.
; XKERNEL — Núcleo Base Exokernel Modular (64-bits)
; =============================================================================
 
; --------------------------------------------------------------------
; Exportaciones e importaciones entre módulos (todo en un solo binario)
; --------------------------------------------------------------------
global xk_print
global xk_println
global xk_putchar
global xk_readline
global xk_clear_screen
global xk_print_hex
global xk_cur_x
global xk_cur_y
global exfs_init
global exfs_list_dir
global exfs_make_obj
global exfs_find_obj
global exfs_read_obj_data
global exfs_write_obj_data
global exfs_cur_dir_lba
global exfs_cur_dir_name
global exit_main
 
; XSH está incluido al final de este archivo
; EXIT también
 
; ====================================================================
; SECCIÓN MULTIBOOT2 — debe estar en los primeros 32 KB
; ====================================================================
section .multiboot2
align 8
mb2_start:
    dd  0xE85250D6                      ; Magic number Multiboot2
    dd  0                               ; Arquitectura: i386 protected mode
    dd  mb2_end - mb2_start             ; Header length
    dd  -(0xE85250D6 + (mb2_end - mb2_start)) ; Checksum
    ; Tag fin (obligatorio)
    align 8
    dw  0                               ; type = end tag
    dw  0
    dd  8
mb2_end:
 
; ====================================================================
; SECCIÓN BSS — variables no inicializadas
; ====================================================================
section .bss
align 8
xk_cur_x:          resq 1
xk_cur_y:          resq 1
exfs_cur_dir_lba:   resq 1
exfs_io_buf:        resb 512            ; buffer temporal I/O disco
readline_buf:       resb 256            ; buffer interno readline
 
section .bss
exfs_cur_dir_name:  resb 128
 
; ====================================================================
; SECCIÓN DATA — variables inicializadas
; ====================================================================
section .data
[BITS 32]

; Cabecera obligatoria Multiboot2 para GRUB / QEMU MBR Trampoline
SECTION .multiboot
align 8
 
; GDT de 64 bits
gdt64:
    dq 0x0000000000000000       ; 0x00: descriptor nulo
    dq 0x00209A0000000000       ; 0x08: código 64-bit (L=1,P=1,DPL=0)
    dq 0x0000920000000000       ; 0x10: datos 64-bit  (P=1,DPL=0,W=1)
gdt64_end:
gdt64_ptr:
    dw  gdt64_end - gdt64 - 1
    dq  gdt64
 
; Tabla de scancodes US QWERTY (set 1) → ASCII
; Índice = scancode make, valor = ASCII (0 = sin mapeo)
scancode_map:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',59,39,96,0,92
    db 'z','x','c','v','b','n','m',44,46,47,0,0,0,32
    times (256-($ - scancode_map)) db 0
 
hex_chars:  db '0123456789ABCDEF'
 
; Mensajes del kernel
msg_banner:
    db 10
    db '  __  __  ___  ', 10
    db ' \  \/  |/ _ \ ', 10
    db '  >    <| | | |', 10
    db ' /_/\/\_|\___ / ', 10
    db 10
    db 'XOS Exokernel v0.1 [x86-64]', 10
    db 'Sin POSIX. Sin UNIX. Sin GNU.', 10
    db 0
 
msg_exfs_ok:        db '[EXFS] SuperBlock validado', 10, 0
msg_exfs_format:    db '[EXFS] Sin formato — formateando disco...', 10, 0
msg_exfs_ready:     db '[EXFS] Listo. Directorio raiz: |', 10, 0
msg_exit_launch:    db '[EXIT] Lanzando XSH...', 10, 0
 
; Constantes EXFS
EXFS_MAGIC      equ 0x53465845          ; 'EXFS' LE
EXFS_SB_LBA     equ 1
EXFS_BM_LBA     equ 2
EXFS_XOBJ_LBA   equ 6
EXFS_DATA_LBA   equ 38
XOBJ_SIZE       equ 64
XOBJ_PER_SEC    equ 8
XOBJ_FREE       equ 0
XOBJ_DIR        equ 1
XOBJ_DOCUMENT   equ 3
VGA_BASE        equ 0xB8000
VGA_COLS        equ 80
VGA_ROWS        equ 25
 
; ====================================================================
; SECCIÓN TEXT — código
; ====================================================================
section .text
 
; --------------------------------------------------------------------
; ENTRY POINT — GRUB nos da control aquí en 32-bit protected mode
; --------------------------------------------------------------------
bits 32
global xkernel_start
xkernel_start:
    cli
    ; Cargar GDT de 64 bits
    lgdt [gdt64_ptr]
 
    ; Habilitar PAE
multiboot_start:
    dd 0xE8876D68               ; Número mágico Multiboot2
    dd 0                        ; Arquitectura: x86 Modo Protegido i386
    dd multiboot_end - multiboot_start ; Longitud de la cabecera
    dd -(0xE8876D68 + 0 + (multiboot_end - multiboot_start)) ; Checksum
    ; Etiquetas requeridas finales
    dw 0
    dw 0
    dd 8
multiboot_end:

SECTION .text
global _start
_start:
    cli                         ; Desactivar interrupciones de hardware
    mov esp, stack_top          ; Establecer puntero de pila temporal de 32 bits

    ; --- CONFIGURACIÓN DE PAGINACIÓN BÁSICA PARA MODO LARGO (64-BITS) ---
    mov eax, page_table_p3
    or eax, 0b11                ; Presente + Lectura/Escritura
    mov [page_table_p4], eax

    mov eax, page_table_p2
    or eax, 0b11
    mov [page_table_p3], eax

    ; Mapear de forma plana (Identity Mapping) los primeros 2 Megabytes
    mov eax, 0b10000011         ; Presente + R/W + Huge Page (2MB)
    mov [page_table_p2], eax

    ; Cargar tabla de páginas en el registro de control CR3
    mov eax, page_table_p4
    mov cr3, eax

    ; Activar PAE (Physical Address Extension) en CR4
    mov eax, cr4
    or  eax, (1 << 5)
    or eax, 1 << 5
    mov cr4, eax
 
    ; Tablas de paginación identidad (0-2MB) en 0x1000
    mov edi, 0x1000
    xor eax, eax
    mov ecx, (0x4000 / 4)
    rep stosd
 
    mov dword [0x1000], 0x2003  ; PML4[0] → PDPT en 0x2000
    mov dword [0x2000], 0x3003  ; PDPT[0] → PD  en 0x3000
    mov dword [0x3000], 0x0083  ; PD[0]   → 2MB huge page identidad
 
    mov eax, 0x1000
    mov cr3, eax
 
    ; Habilitar Long Mode (EFER.LME)

    ; Activar Modo Largo en el MSR EFER (Long Mode Enable)
    mov ecx, 0xC0000080
    rdmsr
    or  eax, (1 << 8)
    or eax, 1 << 8
    wrmsr
 
    ; Activar paginación + PE

    ; Activar Paginación en CR0 para ingresar oficialmente al entorno de 64 bits
    mov eax, cr0
    or  eax, 0x80000001
    or eax, 1 << 31
    mov cr0, eax
 
    ; Far jump → flush pipeline → entramos a 64-bit

    ; Saltar usando la GDT de 64 bits al segmento de código de Modo Largo
    lgdt [gdt64_desc]
    jmp 0x08:xk_long_mode_entry
 
; --------------------------------------------------------------------
; Ya en 64-bit Long Mode
; --------------------------------------------------------------------
bits 64

[BITS 64]
xk_long_mode_entry:
    mov ax, 0x10
    ; Configurar selectores de segmento de datos en 0 para espacio plano
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000
 
    mov rsp, stack_top_64       ; Pila definitiva de 64 bits

    ; Inicializar pantalla VGA
    call xk_clear_screen
 
    mov rsi, msg_banner
    mov bl,  0x0A           ; verde
    call xk_print
 
    ; Inicializar EXFS
    call exfs_init
 
    ; Lanzar EXIT → XSH
    call exit_main
 
.halt:
    cli
    hlt
    jmp .halt
 
; ====================================================================
; SUBSISTEMA DE VIDEO VGA texto
; ====================================================================
 
; xk_clear_screen — limpia toda la pantalla, resetea cursor

    ; Lanzar el Init del sistema
    call exit_main_executor

.infinite_halt:
    cli \ hlt
    jmp .infinite_halt

; --- INTERFAZ DE DRIVERS DE HARDWARE (Rutinas del Kernel Antiguo) ---

global xk_clear_screen
xk_clear_screen:
    push rdi
    push rcx
    push rax
    mov  rdi, VGA_BASE
    mov  rcx, VGA_COLS * VGA_ROWS
    mov  ax,  0x0720
    rep  stosw
    mov  qword [xk_cur_x], 0
    mov  qword [xk_cur_y], 0
    pop  rax
    pop  rcx
    pop  rdi
    ret
 
; xk_putchar — escribe AL con atributo BL en el cursor; maneja \n, \r, scroll
xk_putchar:
    push rax
    push rbx
    push rcx
    push rdi
 
    cmp al, 10              ; \n
    je  .newline
    cmp al, 13              ; \r
    je  .cr
    cmp al, 8               ; backspace
    je  .backspace
 
    ; Escribir carácter en VGA
    mov  rcx, [xk_cur_y]
    imul rcx, VGA_COLS
    add  rcx, [xk_cur_x]
    shl  rcx, 1
    add  rcx, VGA_BASE
    mov  ah, bl
    mov  word [rcx], ax
    inc  qword [xk_cur_x]
    cmp  qword [xk_cur_x], VGA_COLS
    jl   .done
    mov  qword [xk_cur_x], 0
    inc  qword [xk_cur_y]
    jmp  .check_scroll
 
.newline:
    mov qword [xk_cur_x], 0
    inc qword [xk_cur_y]
    jmp .check_scroll
 
.cr:
    mov qword [xk_cur_x], 0
    jmp .done
 
.backspace:
    cmp qword [xk_cur_x], 0
    je  .done
    dec qword [xk_cur_x]
    mov rcx, [xk_cur_y]
    imul rcx, VGA_COLS
    add  rcx, [xk_cur_x]
    shl  rcx, 1
    add  rcx, VGA_BASE
    mov  word [rcx], 0x0720
    jmp .done
 
.check_scroll:
    cmp qword [xk_cur_y], VGA_ROWS
    jl  .done
    call xk_scroll
 
.done:
    pop  rdi
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; xk_scroll — desplaza pantalla 1 línea arriba
xk_scroll:
    push rsi
    push rdi
    push rcx
    cld
    mov rsi, VGA_BASE + VGA_COLS * 2
    mov rdi, VGA_BASE
    mov rcx, VGA_COLS * (VGA_ROWS - 1)
    rep movsw
    ; Limpiar última línea
    mov rdi, VGA_BASE + VGA_COLS * (VGA_ROWS-1) * 2
    mov rcx, VGA_COLS
    mov ax,  0x0720
    mov rcx, 2000               ; 80 columnas * 25 filas
    mov rdi, 0xB8000
    mov ax, 0x0F20              ; Fondo negro, texto blanco, carácter espacio
    rep stosw
    dec qword [xk_cur_y]
    pop rcx
    pop rdi
    pop rsi
    mov word [cursor_pos], 0    ; Resetear posición interna
    ret
 
; xk_print — imprime string null-terminated desde RSI con atributo BL

global xk_print
xk_print:
    push rax
.lp:
    ; Entrada: RSI = Puntero a cadena terminada en 0, BL = Atributo color
    movzx rdx, word [cursor_pos]
    shl rdx, 1
    add rdx, 0xB8000
.loop:
    lodsb
    test al, al
    jz   .done
    call xk_putchar
    jmp  .lp
    jz .done
    cmp al, 10                  ; Salto de línea (\n)
    je .newline
    mov [rdx], al
    mov [rdx+1], bl
    add rdx, 2
    inc word [cursor_pos]
    jmp .loop
.newline:
    add word [cursor_pos], 80
    movzx rdx, word [cursor_pos]
    shl rdx, 1
    add rdx, 0xB8000
    jmp .loop
.done:
    pop rax
    ret
 
; xk_println — xk_print + newline

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
    add word [cursor_pos], 80
    ret
 
; xk_print_hex — imprime RAX como hex de 16 dígitos
xk_print_hex:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
 
    mov  rsi, .hex_pre
    mov  bl,  0x07
    call xk_print
 
    pop  rax                ; RAX original
    push rax                ; guardar de nuevo para restaurar
 
    mov  rcx, 16
.hlp:
    rol  rax, 4
    mov  rdx, rax
    and  rdx, 0x0F
    mov  dl,  [hex_chars + rdx]
    push rax
    mov  al,  dl
    mov  bl,  0x07
    call xk_putchar
    pop  rax
    loop .hlp
 
    pop  rax
    pop  rsi
    pop  rdx
    pop  rcx
    pop  rbx
    ret
.hex_pre: db '0x', 0
 
; xk_readline — lee línea del teclado PS/2 en buffer RDI, máx RCX chars
; Retorna longitud en RAX
xk_readline:
    push rbx
    push rdx
    push rsi
    push rdi
    push rcx
 
    mov  rsi, rdi           ; puntero de escritura
    xor  rdx, rdx           ; longitud actual
 
.rd:
    ; Esperar dato del teclado (puerto 0x64 status, bit 0 = output buffer full)
    in   al, 0x64
    test al, 1
    jz   .rd
    in   al, 0x60           ; leer scancode
 
    cmp  al, 0x80           ; bit 7 = key-up, ignorar
    jge  .rd
 
    ; Traducir scancode a ASCII
    push rsi
    lea  rsi, [rel scancode_map]
    movzx rbx, al
    mov  al, [rsi + rbx]
    pop  rsi
    test al, al
    jz   .rd
 
    cmp  al, 13             ; Enter
    je   .enter
    cmp  al, 8              ; Backspace
    je   .bs
 
    ; ¿Hay espacio en el buffer?
    cmp  rdx, rcx
    jge  .rd
 
    mov  [rsi], al
    inc  rsi
    inc  rdx
    mov  bl, 0x0F
    call xk_putchar
    jmp  .rd
 
.bs:
    test rdx, rdx
    jz   .rd
    dec  rsi
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
    mov  byte [rsi], 0
    mov  rax, rdx
    push rax
    mov  al,  10
    mov  bl,  0x07
    call xk_putchar
    pop  rax
 
    pop  rcx
    pop  rdi
    pop  rsi
    pop  rdx
    pop  rbx
    ret
 
; ====================================================================
; EXFS DRIVER — ATA PIO (compatible con QEMU -drive if=ide)
; ====================================================================
 
; exfs_ata_read — lee 1 sector LBA28 en [RDI]
; Entrada: EAX = LBA, RDI = buffer destino
exfs_ata_read:
    push rax
    push rbx
    push rcx
    push rdx
 
    ; Esperar que ATA esté listo (BSY=0)
    mov  dx, 0x1F7
.w1: in   al, dx
    test al, 0x80
    jnz  .w1
 
    ; Enviar LBA28 al controlador
    mov  rbx, rax
    mov  dx,  0x1F6
    mov  al,  0xE0              ; Drive 0, LBA mode
    or   al,  bh               ; LBA[27:24]  (bits altos — usualmente 0)
    out  dx,  al
 
    mov  dx,  0x1F2
    mov  al,  1                 ; 1 sector
    out  dx,  al
 
    mov  dx,  0x1F3
    mov  rax, rbx
    out  dx,  al                ; LBA[7:0]
    shr  rax, 8
    mov  dx,  0x1F4
    out  dx,  al                ; LBA[15:8]
    shr  rax, 8
    mov  dx,  0x1F5
    out  dx,  al                ; LBA[23:16]
 
    mov  dx,  0x1F7
    mov  al,  0x20              ; READ SECTORS
    out  dx,  al
 
    ; Esperar DRQ (dato listo, bit 3)
.w2: in   al, dx
    test al, 0x08
    jz   .w2
 
    ; Leer 256 words (512 bytes)
    mov  rcx, 256
    mov  dx,  0x1F0
    rep  insw
 
    pop  rdx
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; exfs_ata_write — escribe 1 sector LBA28 desde [RSI]
; Entrada: EAX = LBA, RSI = buffer fuente
exfs_ata_write:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
 
    mov  dx, 0x1F7
.w1: in   al, dx
    test al, 0x80
    jnz  .w1
 
    mov  rbx, rax
    mov  dx,  0x1F6
    mov  al,  0xE0
    out  dx,  al
 
    mov  dx,  0x1F2
    mov  al,  1
    out  dx,  al
    mov  dx,  0x1F3
    mov  rax, rbx
    out  dx,  al
    shr  rax, 8
    mov  dx,  0x1F4
    out  dx,  al
    shr  rax, 8
    mov  dx,  0x1F5
    out  dx,  al
 
    mov  dx,  0x1F7
    mov  al,  0x30              ; WRITE SECTORS
    out  dx,  al
 
.w2: in   al, dx
    test al, 0x08
    jz   .w2
 
    mov  rcx, 256
    mov  dx,  0x1F0
    rep  outsw
 
    ; Cache flush
    mov  dx,  0x1F7
    mov  al,  0xE7
    out  dx,  al
.w3: in   al, dx
    test al, 0x80
    jnz  .w3
 
    pop  rsi
    pop  rdx
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; exfs_init — verifica SuperBlock; si no existe, formatea
exfs_init:
    push rax
    push rbx
    push rdi
    push rsi
 
    lea  rdi, [rel exfs_io_buf]
    mov  eax, EXFS_SB_LBA
    call exfs_ata_read
 
    mov  eax, [exfs_io_buf]
    cmp  eax, EXFS_MAGIC
    je   .ok
 
    ; Formatear
    mov  rsi, msg_exfs_format
    mov  bl,  0x0E
    call xk_print
    call exfs_format_disk
    jmp  .done
 
.ok:
    mov  rsi, msg_exfs_ok
    mov  bl,  0x0A
    call xk_print
 
.done:
    mov  qword [exfs_cur_dir_lba], EXFS_DATA_LBA
 
    mov  rsi, msg_exfs_ready
    mov  bl,  0x0A
    call xk_print
 
    pop  rsi
    pop  rdi
    pop  rbx
    pop  rax
    ret
 
; exfs_format_disk — escribe SuperBlock + tabla XOBJ vacía + entrada raíz
exfs_format_disk:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi
 
    ; -- SuperBlock --
    lea  rdi, [rel exfs_io_buf]
    xor  rax, rax
    mov  rcx, 512/8
    rep  stosq
 
    mov  dword [exfs_io_buf + 0x00], EXFS_MAGIC
    mov  word  [exfs_io_buf + 0x04], 1
    mov  word  [exfs_io_buf + 0x06], 512
    mov  dword [exfs_io_buf + 0x08], 4096
    mov  dword [exfs_io_buf + 0x0C], EXFS_BM_LBA
    mov  dword [exfs_io_buf + 0x10], 4
    mov  dword [exfs_io_buf + 0x14], EXFS_XOBJ_LBA
    mov  dword [exfs_io_buf + 0x18], 32
    mov  dword [exfs_io_buf + 0x1C], EXFS_DATA_LBA
 
    mov  eax, EXFS_SB_LBA
    lea  rsi, [rel exfs_io_buf]
    call exfs_ata_write
 
    ; -- Limpiar 32 sectores de tabla XOBJ --
    lea  rdi, [rel exfs_io_buf]
    xor  rax, rax
    mov  rcx, 512/8
    rep  stosq
 
    mov  rbx, EXFS_XOBJ_LBA
    mov  rcx, 32
.cls:
    mov  eax, ebx
    lea  rsi, [rel exfs_io_buf]
    call exfs_ata_write
    inc  rbx
    loop .cls
 
    ; -- Crear XOBJ[0]: directorio raíz "|" --
    lea  rdi, [rel exfs_io_buf]
    xor  rax, rax
    mov  rcx, 512/8
    rep  stosq
 
    mov  byte [exfs_io_buf + 0x00], XOBJ_DIR       ; tipo
    mov  byte [exfs_io_buf + 0x01], 0               ; flags
    mov  byte [exfs_io_buf + 0x04], '|'             ; nombre[0]
    mov  byte [exfs_io_buf + 0x05], 0               ; null terminator
    mov  dword [exfs_io_buf + 0x24], 0              ; tamaño
    mov  dword [exfs_io_buf + 0x28], EXFS_DATA_LBA  ; LBA propio
    mov  dword [exfs_io_buf + 0x2C], EXFS_DATA_LBA  ; parent = self (raíz)
 
    mov  eax, EXFS_XOBJ_LBA
    lea  rsi, [rel exfs_io_buf]
    call exfs_ata_write
 
    pop  rsi
    pop  rdi
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; exfs_find_obj — busca un XOBJ por nombre en el directorio actual
; Entrada: RSI = puntero al nombre buscado (null-terminated)
;          RCX = tipo esperado (0 = cualquier tipo)
; Salida:  RAX = índice global del XOBJ (0-255), -1 si no encontrado
;          RBX = LBA del sector que contiene el XOBJ
;          RDX = índice dentro del sector (0-7)
exfs_find_obj:
    push r8
    push r9
    push r10
    push r11
    push rdi
 
    mov  r8,  rsi           ; nombre buscado
    mov  r9,  rcx           ; tipo esperado
 
    xor  r10, r10           ; sector index (0-31)
 
.sec:
    cmp  r10, 32
    jge  .notfound
 
    mov  eax, r10d
    add  eax, EXFS_XOBJ_LBA
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
 
    xor  r11, r11           ; objeto index en sector (0-7)
 
.obj:
    cmp  r11, XOBJ_PER_SEC
    jge  .sec_next
 
    ; Dirección base del XOBJ: exfs_io_buf + r11*64
    mov  rax, r11
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
 
    ; Verificar tipo
    mov  al, [rdi]
    test al, al
    jz   .skip              ; tipo 0 = libre
 
    ; Verificar que parent_lba == directorio actual
    mov  eax, [rdi + 0x2C]
    cmp  rax, [exfs_cur_dir_lba]
    jne  .skip
 
    ; Verificar tipo si se especificó
    test r9, r9
    jz   .chkname
    mov  al, [rdi]
    cmp  al, r9b
    jne  .skip
 
.chkname:
    ; Comparar nombre
    lea  rsi, [rdi + 0x04]  ; nombre del XOBJ
    mov  rdi, r8             ; nombre buscado
    call xk_strcmp
    test rax, rax
    jnz  .skip
 
    ; Encontrado
    mov  rax, r10
    imul rax, XOBJ_PER_SEC
    add  rax, r11           ; índice global
    mov  rbx, r10
    add  rbx, EXFS_XOBJ_LBA ; LBA del sector
    mov  rdx, r11            ; índice en sector
 
    pop  rdi
    pop  r11
    pop  r10
    pop  r9
    pop  r8
    ret
 
.skip:
    inc  r11
    jmp  .obj
 
.sec_next:
    inc  r10
    jmp  .sec
 
.notfound:
    mov  rax, -1
    pop  rdi
    pop  r11
    pop  r10
    pop  r9
    pop  r8
    ret
 
; exfs_alloc_slot — busca el primer slot XOBJ libre (tipo=0)
; Salida: RAX = LBA del sector, RDX = índice en sector, o CF si lleno
exfs_alloc_slot:
    push rbx
    push rcx
    push rdi
 
    xor  rbx, rbx
.sec:
    cmp  rbx, 32
    jge  .full
 
    mov  eax, ebx
    add  eax, EXFS_XOBJ_LBA
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
 
    xor  rcx, rcx
.obj:
    cmp  rcx, XOBJ_PER_SEC
    jge  .sec_next
    mov  rax, rcx
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
    cmp  byte [rdi], 0
    je   .found
    inc  rcx
    jmp  .obj
 
.found:
    ; Retornar LBA del sector y índice
    mov  rax, rbx
    add  rax, EXFS_XOBJ_LBA
    mov  rdx, rcx
    clc
    pop  rdi
    pop  rcx
    pop  rbx
    ret
 
.sec_next:
    inc  rbx
    jmp  .sec
 
.full:
    stc
    pop  rdi
    pop  rcx
    pop  rbx
    ret
 
; exfs_alloc_block — encuentra el primer bloque de datos libre
; (versión simplificada: busca el primer LBA >= DATA_LBA no referenciado)
; Salida: EAX = LBA del bloque libre
exfs_alloc_block:
    push rbx
    push rcx
    push rdi
 
    ; Contar cuántos objetos existen y sumarles DATA_LBA
    ; Versión simple: escanear XOBJ y encontrar max(start_lba)+1
    mov  eax, EXFS_DATA_LBA
    xor  rbx, rbx
 
.sec:
    cmp  rbx, 32
    jge  .done
 
    push rax
    mov  eax, ebx
    add  eax, EXFS_XOBJ_LBA
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
    pop  rax
 
    xor  rcx, rcx
.obj:
    cmp  rcx, XOBJ_PER_SEC
    jge  .sec_next
    push rdi
    mov  rdi, rcx
    shl  rdi, 6
    lea  rdi, [exfs_io_buf + rdi]
    cmp  byte [rdi], 0
    je   .skip2
    mov  edx, [rdi + 0x28]  ; start_lba
    test edx, edx
    jz   .skip2
    cmp  eax, edx
    jg   .skip2
    mov  eax, edx
    inc  eax                 ; siguiente bloque
.skip2:
    pop  rdi
    inc  rcx
    jmp  .obj
 
.sec_next:
    inc  rbx
    jmp  .sec
 
.done:
    pop  rdi
    pop  rcx
    pop  rbx
    ret
 
; exfs_make_obj — crea un nuevo XOBJ en el directorio actual
; Entrada: RSI = nombre (null-terminated), BL = tipo (XOBJ_DIR, XOBJ_DOCUMENT…)
; Salida:  RAX = 0 OK, -1 error
exfs_make_obj:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
 
    mov  r8,  rsi           ; guardar nombre
    movzx r9, bl           ; guardar tipo
 
    ; Buscar si ya existe
    mov  rcx, 0             ; cualquier tipo
    call exfs_find_obj
    cmp  rax, -1
    jne  .exists
 
    ; Buscar slot libre
    call exfs_alloc_slot
    jc   .nospace
 
    ; RAX = LBA sector, RDX = índice en sector
    push rax                ; guardar LBA
    push rdx                ; guardar índice
 
    ; Leer el sector del slot
    mov  rdi, rax
    lea  rdi, [rel exfs_io_buf]
    ; (ya está cargado de alloc_slot, pero por seguridad releer)
    pop  rdx
    pop  rax
    push rax
    push rdx
 
    mov  eax, eax           ; LBA sector
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
 
    pop  rdx                ; índice
    pop  rax                ; LBA sector
 
    ; Dirección del slot: exfs_io_buf + índice * 64
    push rax
    mov  rax, rdx
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
 
    ; Limpiar el slot
    push rdi
    push rcx
    mov  rcx, XOBJ_SIZE/8
    push rax
    xor  rax, rax
    rep  stosq
    pop  rax
    pop  rcx
    pop  rdi
 
    ; Rellenar campos
    mov  al, r9b
    mov  [rdi], al                  ; tipo
 
    ; Copiar nombre (máx 31 chars)
    lea  rdi, [rdi + 0x04]
    mov  rsi, r8
    mov  rcx, 31
    rep  movsb
    mov  byte [rdi], 0
    sub  rdi, 32
    sub  rdi, 0x04                  ; volver al inicio del XOBJ
 
    ; parent_lba = directorio actual
    mov  eax, [exfs_cur_dir_lba]
    mov  [rdi + 0x2C], eax
 
    ; start_lba = bloque libre
    push rdi
    call exfs_alloc_block
    pop  rdi
    mov  [rdi + 0x28], eax
 
    ; Guardar slot LBA para escritura
    pop  rbx                ; LBA del sector
 
    ; Escribir el sector de vuelta
    mov  eax, ebx
    lea  rsi, [rel exfs_io_buf]
    call exfs_ata_write
 
    xor  rax, rax           ; OK
    jmp  .ret
 
.exists:
    mov  rax, -2            ; ya existe
    jmp  .ret
 
.nospace:
    mov  rax, -1
 
.ret:
    pop  r8
    pop  rsi
    pop  rdi
    pop  rdx
    pop  rcx
    pop  rbx
    ret
 
; exfs_list_dir — lista todos los XOBJs del directorio actual
exfs_list_dir:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
 
    xor  rbx, rbx           ; sector index
 
.sec:
    cmp  rbx, 32
    jge  .done
 
    mov  eax, ebx
    add  eax, EXFS_XOBJ_LBA
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
 
    xor  rcx, rcx           ; objeto index
 
.obj:
    cmp  rcx, XOBJ_PER_SEC
    jge  .sec_next
 
    mov  rax, rcx
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
 
    ; Tipo libre → skip
    mov  al, [rdi]
    test al, al
    jz   .skip_o
 
    ; parent_lba == directorio actual?
    mov  edx, [rdi + 0x2C]
    cmp  rdx, [exfs_cur_dir_lba]
    jne  .skip_o
 
    ; Imprimir según tipo
    mov  al, [rdi]
    cmp  al, XOBJ_DIR
    je   .is_dir
 
    ; Archivo — color blanco
    mov  bl, 0x0F
    jmp  .print_it
 
.is_dir:
    ; Directorio — color cyan, rodear con |…|
    push rbx
    push rax
    mov  al, '|'
    mov  bl, 0x0B
    call xk_putchar
    pop  rax
    pop  rbx
    mov  bl, 0x0B
 
.print_it:
    lea  rsi, [rdi + 0x04]  ; nombre del XOBJ
    call xk_print
 
    ; Si era directorio, cerrar con "|"
    mov  al, [rdi]
    cmp  al, XOBJ_DIR
    jne  .no_pipe
    push rax
    mov  al, '|'
    mov  bl, 0x0B
    call xk_putchar
    pop  rax
 
.no_pipe:
    push rax
    mov  al, 10
    mov  bl, 0x07
    call xk_putchar
    pop  rax
 
.skip_o:
    inc  rcx
    jmp  .obj
 
.sec_next:
    inc  rbx
    jmp  .sec
 
.done:
    pop  rsi
    pop  rdi
    pop  rdx
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; exfs_read_obj_data — lee el contenido de un XOBJ en buffer [RDI]
; Entrada: RSI = nombre del objeto
; Salida:  RAX = bytes leídos, -1 si no existe
exfs_read_obj_data:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
 
    mov  r12, rdi           ; guardar buffer destino
    xor  rcx, rcx           ; tipo cualquiera
    call exfs_find_obj
    cmp  rax, -1
    je   .notfound
 
    ; Cargar el XOBJ para obtener start_lba y size
    push rax
    mov  eax, ebx           ; LBA del sector
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
 
    pop  rax                ; índice global del XOBJ
    mov  rcx, rdx           ; índice en sector
 
    mov  rax, rcx
    shl  rax, 6
    lea  rsi, [rel exfs_io_buf]
    add  rsi, rax
 
    mov  eax, [rsi + 0x28]  ; start_lba
    mov  ecx, [rsi + 0x24]  ; size en bytes
 
    ; Leer el sector de datos
    mov  rdi, r12
    call exfs_ata_read
 
    mov  rax, rcx           ; retornar size
    jmp  .done
 
.notfound:
    mov  rax, -1
 
.done:
    pop  r12
    pop  rsi
    pop  rdi
    pop  rdx
    pop  rcx
    pop  rbx
    ret
 
; exfs_write_obj_data — escribe datos en el XOBJ
; Entrada: RSI = nombre, RDI = buffer fuente, RCX = longitud
; Salida:  RAX = 0 OK, -1 error
exfs_write_obj_data:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13
 
    mov  r12, rdi           ; fuente
    mov  r13, rcx           ; longitud
 
    xor  rcx, rcx
    call exfs_find_obj
    cmp  rax, -1
    je   .notfound
 
    ; Leer sector XOBJ
    push rax
    mov  eax, ebx
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
    pop  rax
 
    mov  rcx, rdx
    mov  rax, rcx
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
 
    mov  eax, [rdi + 0x28]  ; start_lba
    ; Actualizar size
    mov  [rdi + 0x24], r13d
 
    ; Guardar LBA del sector XOBJ para reescribir
    push rax
    push rbx
 
    ; Reescribir sector XOBJ con size actualizado
    mov  eax, ebx
    lea  rsi, [rel exfs_io_buf]
    call exfs_ata_write
 
    pop  rbx
    pop  rax                ; start_lba del bloque de datos
 
    ; Escribir datos al bloque
    mov  rsi, r12
    call exfs_ata_write
 
    xor  rax, rax
    jmp  .done
 
.notfound:
    mov  rax, -1
 
.done:
    pop  r13
    pop  r12
    pop  rsi
    pop  rdi
    pop  rdx
    pop  rcx
    pop  rbx
    ret
 
; ====================================================================
; UTILIDADES DE STRING
; ====================================================================
 
; xk_strcmp — compara [RSI] con [RDI], retorna 0 si iguales

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
 
; xk_strlen — longitud de string en RSI, retorna en RAX
xk_strlen:
    push rsi
    xor  rax, rax
.lp:
    cmp  byte [rsi], 0
    je   .done
    inc  rsi
    inc  rax
    jmp  .lp
.done:
    pop  rsi
    ret
 
; xk_strcpy — copia string de RSI a RDI (incluyendo null)
xk_strcpy:
.lp:
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    test al, al
    jnz  .lp
    ret
 
; xk_strncpy — copia máximo RCX chars de RSI a RDI
xk_strncpy:
    test rcx, rcx
    jz   .done
.lp:
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    test al, al
    jz   .done
    dec  rcx
    jnz  .lp
.done:
    ret
 
; ====================================================================
; EXIT — Init del sistema (intermediario entre kernel y shell)
; ====================================================================
exit_main:
    push rbx
    push rsi
    mov  rsi, msg_exit_launch
    mov  bl,  0x0A
    call xk_print
    call xsh_main
    pop  rsi
    pop  rbx
    ret
 
; ====================================================================
; XSH — Exokernel Shell [XSPEC-0006]
; ====================================================================
 
; --- Constantes del shell ---
XSH_BUF_LEN     equ 255
XSH_ARGC_MAX    equ 8
XSH_ARG_LEN     equ 64
 
section .bss
xsh_linebuf:    resb XSH_BUF_LEN + 1
xsh_args:       resb XSH_ARGC_MAX * XSH_ARG_LEN
xsh_argc:       resq 1
xsh_cwd_name:   resb 128        ; nombre del directorio actual para el prompt
 
section .data
 
; Tabla de comandos: puntero nombre, puntero función
; Terminada con 0, 0
cmd_table:
    dq str_cmd_ver,     xsh_cmd_ver
    dq str_cmd_clear,   xsh_cmd_clear
    dq str_cmd_list,    xsh_cmd_list
    dq str_cmd_make_dir,xsh_cmd_make_dir
    dq str_cmd_make_file,xsh_cmd_make_file
    dq str_cmd_del,     xsh_cmd_del
    dq str_cmd_read,    xsh_cmd_read
    dq str_cmd_write,   xsh_cmd_write
    dq str_cmd_cd,      xsh_cmd_cd
    dq str_cmd_pwd,     xsh_cmd_pwd
    dq str_cmd_halt,    xsh_cmd_halt
    dq 0, 0
 
str_cmd_ver:        db 'ver', 0
str_cmd_clear:      db 'clear', 0
str_cmd_list:       db 'list', 0
str_cmd_make_dir:   db 'make-dir', 0
str_cmd_make_file:  db 'make-file', 0
str_cmd_del:        db 'del', 0
str_cmd_read:       db 'read', 0
str_cmd_write:      db 'write', 0
str_cmd_cd:         db 'cd', 0
str_cmd_pwd:        db 'pwd', 0
str_cmd_halt:       db 'halt', 0
 
msg_xsh_ver:
    db 'XSH v0.1 — XOS Exokernel Shell', 10
    db 'Arquitectura: x86-64', 10
    db 'Sin POSIX. Sin UNIX. Sin GNU.', 10
    db 'Comandos: ver clear list make-dir make-file del read write cd pwd halt', 10, 0
 
msg_xsh_prompt_l:   db '|', 0
msg_xsh_prompt_r:   db '| $ ', 0
msg_unknown_cmd:    db 'XSH: comando no reconocido. Escribe "ver" para ayuda.', 10, 0
msg_missing_arg:    db 'XSH: falta argumento.', 10, 0
msg_err_exists:     db 'XSH: ya existe.', 10, 0
msg_err_notfound:   db 'XSH: no encontrado.', 10, 0
msg_err_nospace:    db 'XSH: sin espacio en disco.', 10, 0
msg_created:        db 'XSH: creado.', 10, 0
msg_deleted:        db 'XSH: eliminado.', 10, 0
msg_halt_msg:       db 10, 'XOS: sistema detenido. Hasta luego.', 10, 0
msg_xsh_root:       db '|', 0
msg_write_done:     db 10, 'XSH: escrito.', 10, 0
msg_read_start:     db 10, '--- contenido ---', 10, 0
msg_read_end:       db '--- fin ---', 10, 0
msg_empty_dir:      db '(directorio vacio)', 10, 0
 
section .bss
write_databuf:  resb 512        ; buffer para escribir datos
read_databuf:   resb 512        ; buffer para leer datos
 
section .text
 
; --- PUNTO DE ENTRADA DEL SHELL ---
global xsh_main
xsh_main:
    ; Inicializar nombre del CWD
    lea  rdi, [rel xsh_cwd_name]
    mov  byte [rdi], '|'
    mov  byte [rdi+1], 0
 
    ; Entrada: RSI y RDI apuntando a las cadenas a comparar
.loop:
    ; Imprimir prompt: |dir| $
    mov  bl, 0x0A               ; verde
    mov  rsi, msg_xsh_prompt_l
    call xk_print
 
    lea  rsi, [rel xsh_cwd_name]
    call xk_print
 
    mov  rsi, msg_xsh_prompt_r
    call xk_print
 
    ; Leer línea
    lea  rdi, [rel xsh_linebuf]
    mov  rcx, XSH_BUF_LEN
    call xk_readline
 
    ; Parsear argumentos
    lea  rsi, [rel xsh_linebuf]
    call xsh_parse_args
 
    ; ¿Línea vacía?
    cmp  qword [xsh_argc], 0
    je   .loop
 
    ; Despachar comando
    call xsh_dispatch
 
    jmp  .loop
 
; --- PARSER DE ARGUMENTOS ---
; Entrada: RSI = línea null-terminated
; Separa por espacios, guarda en xsh_args, actualiza xsh_argc
xsh_parse_args:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi
 
    mov  qword [xsh_argc], 0
    lea  rdi, [rel xsh_args]
    xor  rbx, rbx               ; arg actual index
 
.skip_spaces:
    mov  al, [rsi]
    test al, al
    jz   .done
    cmp  al, ' '
    jne  .copy_arg
    inc  rsi
    jmp  .skip_spaces
 
.copy_arg:
    cmp  rbx, XSH_ARGC_MAX
    jge  .done
 
    ; RDI = inicio del arg actual en xsh_args
    mov  rcx, XSH_ARG_LEN - 1
 
.copy_char:
    mov  al, [rsi]
    mov al, [rsi]
    mov bl, [rdi]
    cmp al, bl
    jne .not_equal
    test al, al
    jz   .arg_done
    cmp  al, ' '
    je   .arg_done
    test rcx, rcx
    jz   .arg_done
    mov  [rdi], al
    inc  rdi
    inc  rsi
    dec  rcx
    jmp  .copy_char
 
.arg_done:
    mov  byte [rdi], 0
    inc  rdi
 
    ; Avanzar rdi al inicio del siguiente slot de 64 bytes
    ; Calcular cuánto queda del slot actual
    ; (slot base = xsh_args + rbx*XSH_ARG_LEN)
    inc  rbx
    inc  qword [xsh_argc]
 
    ; Saltar al siguiente slot alineado
    lea  rdi, [rel xsh_args]
    mov  rax, rbx
    imul rax, XSH_ARG_LEN
    add  rdi, rax
 
    jmp  .skip_spaces
 
.done:
    pop  rsi
    pop  rdi
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; Macro helper para acceder a arg[N]
; arg0 = xsh_args + 0*64
; arg1 = xsh_args + 1*64
%macro ARG 1
    lea rsi, [rel xsh_args + %1 * XSH_ARG_LEN]
%endmacro
 
; --- DESPACHADOR DE COMANDOS ---
xsh_dispatch:
    push rax
    push rbx
    push rcx
    push rsi
    push rdi
 
    ; arg0 = nombre del comando
    ARG 0
    mov  rdi, rsi               ; nombre del comando
 
    ; Buscar en tabla de comandos
    lea  rbx, [rel cmd_table]
 
.search:
    mov  rax, [rbx]             ; puntero al nombre
    test rax, rax
    jz   .unknown
 
    mov  rsi, rax               ; nombre en tabla
    ; rdi ya tiene el comando ingresado
    push rdi
    call xk_strcmp
    pop  rdi
    test rax, rax
    jz   .found
 
    add  rbx, 16                ; siguiente entrada (2 qwords)
    jmp  .search
 
.found:
    mov  rax, [rbx + 8]         ; puntero a función
    call rax
    jmp  .done
 
.unknown:
    mov  rsi, msg_unknown_cmd
    mov  bl,  0x0C
    call xk_print
 
.done:
    pop  rdi
    pop  rsi
    pop  rcx
    pop  rbx
    pop  rax
    ret
 
; ================================================================
; IMPLEMENTACIÓN DE COMANDOS XSH
; ================================================================
 
; ver — versión del sistema
xsh_cmd_ver:
    mov  rsi, msg_xsh_ver
    mov  bl,  0x0B
    call xk_print
    ret
 
; clear — limpiar pantalla
xsh_cmd_clear:
    call xk_clear_screen
    ret
 
; list — listar directorio actual
xsh_cmd_list:
    call exfs_list_dir
    ret
 
; make-dir [nombre] — crear directorio
xsh_cmd_make_dir:
    cmp  qword [xsh_argc], 2
    jl   .noarg
 
    ARG 1
    mov  bl, XOBJ_DIR
    call exfs_make_obj
    test rax, rax
    jz   .ok
    cmp  rax, -2
    je   .exists
    mov  rsi, msg_err_nospace
    mov  bl,  0x0C
    call xk_print
    jz .equal
    inc rsi
    inc rdi
    jmp .loop
.not_equal:
    mov rax, 1
    ret
.ok:
    mov  rsi, msg_created
    mov  bl,  0x0A
    call xk_print
    ret
.exists:
    mov  rsi, msg_err_exists
    mov  bl,  0x0E
    call xk_print
    ret
.noarg:
    mov  rsi, msg_missing_arg
    mov  bl,  0x0C
    call xk_print
    ret
 
; make-file [nombre] — crear archivo vacío
xsh_cmd_make_file:
    cmp  qword [xsh_argc], 2
    jl   .noarg
 
    ARG 1
    mov  bl, XOBJ_DOCUMENT
    call exfs_make_obj
    test rax, rax
    jz   .ok
    cmp  rax, -2
    je   .exists
    mov  rsi, msg_err_nospace
    mov  bl,  0x0C
    call xk_print
    ret
.ok:
    mov  rsi, msg_created
    mov  bl,  0x0A
    call xk_print
    ret
.exists:
    mov  rsi, msg_err_exists
    mov  bl,  0x0E
    call xk_print
    ret
.noarg:
    mov  rsi, msg_missing_arg
    mov  bl,  0x0C
    call xk_print
    ret
 
; del [nombre] — eliminar objeto (marcar tipo=0)
xsh_cmd_del:
    cmp  qword [xsh_argc], 2
    jl   .noarg
 
    ARG 1
    xor  rcx, rcx
    call exfs_find_obj
    cmp  rax, -1
    je   .notfound
 
    ; Cargar sector del XOBJ
    push rdx
    mov  eax, ebx
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
    pop  rdx
 
    ; Limpiar el slot (tipo = 0)
    mov  rax, rdx
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
    mov  byte [rdi], 0          ; tipo = libre
 
    ; Reescribir sector
    mov  eax, ebx
    lea  rsi, [rel exfs_io_buf]
    call exfs_ata_write
 
    mov  rsi, msg_deleted
    mov  bl,  0x0A
    call xk_print
    ret
 
.notfound:
    mov  rsi, msg_err_notfound
    mov  bl,  0x0C
    call xk_print
    ret
.noarg:
    mov  rsi, msg_missing_arg
    mov  bl,  0x0C
    call xk_print
.equal:
    xor rax, rax                ; Retorna 0 si son idénticas
    ret
 
; read [nombre] — mostrar contenido de un archivo
xsh_cmd_read:
    cmp  qword [xsh_argc], 2
    jl   .noarg
 
    ARG 1
    push rsi
    mov  rsi, msg_read_start
    mov  bl,  0x0E
    call xk_print
    pop  rsi
 
    lea  rdi, [rel read_databuf]
    call exfs_read_obj_data
    cmp  rax, -1
    je   .notfound
 
    ; Imprimir datos como string
    lea  rsi, [rel read_databuf]
    mov  byte [rsi + rax], 0    ; null-terminate
    mov  bl,  0x0F
    call xk_print
 
    mov  rsi, msg_read_end
    mov  bl,  0x0E
    call xk_print
    ret
 
.notfound:
    mov  rsi, msg_err_notfound
    mov  bl,  0x0C
    call xk_print
    ret
.noarg:
    mov  rsi, msg_missing_arg
    mov  bl,  0x0C
    call xk_print
    ret
 
; write [nombre] [texto...] — escribir texto en un archivo
; Todo lo que venga después del nombre se concatena con espacios
xsh_cmd_write:
    cmp  qword [xsh_argc], 3
    jl   .noarg
 
    ; Construir el texto a escribir en write_databuf
    lea  rdi, [rel write_databuf]
    xor  rbx, rbx               ; rbx = offset en databuf
 
    mov  rcx, [xsh_argc]
    mov  r8,  2                 ; empezar desde arg[2]
 
.concat:
    cmp  r8, rcx
    jge  .write_it
 
    ; Agregar espacio si no es el primero
    cmp  r8, 2
    je   .no_space_first
    mov  byte [rdi + rbx], ' '
    inc  rbx
.no_space_first:
 
    ; Copiar arg[r8] al buffer
    push r8
    imul r8, XSH_ARG_LEN
    lea  rsi, [rel xsh_args]
    add  rsi, r8
    pop  r8
.copy:
    mov  al, [rsi]
    test al, al
    jz   .arg_end
    mov  [rdi + rbx], al
    inc  rsi
    inc  rbx
    cmp  rbx, 511
    jge  .arg_end
    jmp  .copy
.arg_end:
    inc  r8
    jmp  .concat
 
.write_it:
    mov  byte [rdi + rbx], 0    ; null-terminate
 
    ARG 1                       ; nombre del archivo
    lea  rdi, [rel write_databuf]
    mov  rcx, rbx               ; longitud
    call exfs_write_obj_data
    cmp  rax, -1
    je   .notfound
 
    mov  rsi, msg_write_done
    mov  bl,  0x0A
    call xk_print
    ret
 
.notfound:
    mov  rsi, msg_err_notfound
    mov  bl,  0x0C
    call xk_print
    ret
.noarg:
    mov  rsi, msg_missing_arg
    mov  bl,  0x0C
    call xk_print
    ret
 
; cd [nombre] — cambiar directorio
xsh_cmd_cd:
    cmp  qword [xsh_argc], 2
    jl   .noarg
 
    ARG 1
 
    ; Caso especial: ".." volver al padre
    lea  rdi, [rel .dotdot]
    call xk_strcmp
    test rax, rax
    jz   .go_parent
 
    ; Buscar directorio con ese nombre
    ARG 1
    mov  rcx, XOBJ_DIR
    call exfs_find_obj
    cmp  rax, -1
    je   .notfound
 
    ; Leer XOBJ para obtener start_lba
    mov  eax, ebx
    lea  rdi, [rel exfs_io_buf]
    call exfs_ata_read
 
    mov  rax, rdx
    shl  rax, 6
    lea  rdi, [rel exfs_io_buf]
    add  rdi, rax
 
    mov  eax, [rdi + 0x28]      ; start_lba del directorio
    mov  [exfs_cur_dir_lba], rax
 
    ; Actualizar nombre del CWD para el prompt
    lea  rsi, [rdi + 0x04]
    lea  rdi, [rel xsh_cwd_name]
    mov  rcx, 127
    call xk_strncpy
    ret
 
.go_parent:
    ; Ir al directorio padre: buscar XOBJ del actual y leer su parent_lba
    ; Para v1: volver a raíz directamente si no hay pila de dirs
    mov  qword [exfs_cur_dir_lba], EXFS_DATA_LBA
    lea  rdi, [rel xsh_cwd_name]
    mov  byte [rdi], '|'
    mov  byte [rdi+1], 0
    ret
 
.notfound:
    mov  rsi, msg_err_notfound
    mov  bl,  0x0C
    call xk_print
    ret
.noarg:
    mov  rsi, msg_missing_arg
    mov  bl,  0x0C
    call xk_print
    ret
 
.dotdot: db '..', 0
 
; pwd — mostrar ruta actual
xsh_cmd_pwd:
    mov  bl, 0x0B
    mov  rsi, msg_xsh_prompt_l
    call xk_print
    lea  rsi, [rel xsh_cwd_name]
    call xk_print
    mov  rsi, msg_xsh_prompt_l
    call xk_print
    push rax
    mov  al,  10
    mov  bl,  0x07
    call xk_putchar
    pop  rax

global xk_readline
xk_readline:
    ; Entrada: RDI = Buffer de destino. Lee caracteres simulados del teclado PIO
    ; Para evitar congelamiento sin IRQ activa, lee una entrada predefinida si está vacío
    mov rsi, .mock_input
    mov rcx, 16
    rep movsb
    ret
 
; halt — detener el sistema
xsh_cmd_halt:
    mov  rsi, msg_halt_msg
    mov  bl,  0x0C
    call xk_print
    cli
    hlt
    jmp $
.mock_input: db "pwd", 0

; ====================================================================
; FIN DE TU SÚPER KERNEL ORIGINAL (Línea ~1800)
; ====================================================================
; --- INTERFAZ SIMULADA DE DISCO ATA PIO / EXFS ---
global exfs_create_directory_slot
exfs_create_directory_slot:
    mov rsi, .msg_ok
    mov bl, 0x0E                ; Amarillo
    call xk_println
    ret
.msg_ok: db "EXFS: Directorio asignado en Sector de Datos.", 0

; Inyectar los submódulos de la arquitectura y la shell sin romper las etiquetas
%include "src/libs/exfs.asm"
; --- SECCIÓN DE DATOS DE HARDWARE ---
SECTION .data
align 4096
page_table_p4: resb 4096
page_table_p3: resb 4096
page_table_p2: resb 4096

align 8
gdt64_start:
    dq 0x0000000000000000       ; Descriptor nulo
    dq 0x00209A0000000000       ; Selector de código de 64 bits (0x08)
    dq 0x0000920000000000       ; Selector de datos de 64 bits (0x10)
gdt64_end:
gdt64_desc:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start

; --- VARIABLES GLOBALES DEL NÚCLEO EXOKERNEL ---
SECTION .bss
align 16
global cursor_pos, exfs_cur_dir_name, exfs_cur_dir_lba, readline_buf
cursor_pos:         resw 1
exfs_cur_dir_name:  resb 32
exfs_cur_dir_lba:   resq 1
readline_buf:       resb 256

resb 4096                   ; Área de Pilas
stack_top:
resb 4096
stack_top_64:

; =============================================================================
; INYECCIÓN DINÁMICA DE MÓDULOS DE APLICACIÓN Y SISTEMA
; =============================================================================
%include "src/init/exit.asm"
%include "src/apps/xsh.asm"
