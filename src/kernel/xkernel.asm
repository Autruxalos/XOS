; =============================================================================
; XKERNEL - NÚCLEO UNIVERSAL MULTI-MODO (16-BIT / 32-BIT / 64-BIT)
; =============================================================================
[BITS 16]
_kernel_start:
    ; Sincronizar segmentos de Modo Real
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; Ubicación segura para la pila temporal

    ; -------------------------------------------------------------------------
    ; DETECCIÓN DE HARDWARE: ¿Soporta al menos el set de instrucciones CPUID?
    ; -------------------------------------------------------------------------
    pushfd
    pop ax
    mov bx, ax
    xor ax, 0x00200000          ; Intentar conmutar el bit 21 (ID flag) en EFLAGS
    push ax
    popfd
    pushfd
    pop ax
    cmp ax, bx
    je .no_cpuid                ; Si el bit no cambió, es un 8086/286 antiguo

    ; Interrogar CPUID para soporte de Modo Largo (64-bits)
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .only_32_bits            ; No soporta funciones extendidas

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           ; Verificar el bit 29 (Long Mode Present)
    jz .only_32_bits            ; Soporta 32 bits pero no 64 bits

    ; -------------------------------------------------------------------------
    ; RUTA DE 64 BITS DISPONIBLE: Iniciar transición escalonada
    ; -------------------------------------------------------------------------
    ; 1. Habilitar la Línea A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; 2. Cargar GDT temporal de 32 bits
    cli
    lgdt [gdt32_descriptor]
    
    ; 3. Activar Modo Protegido en CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; 4. ¡SOLUCIÓN AL WARNING Y TRIPLE FALTA!
    ; Forzamos un salto lejano de 32-bits (Pmode far jump) usando prefijo de tamaño.
    ; 0x0008 es el selector de código de la GDT de 32-bits.
    jmp dword 0x0008:_kernel_32_entry

; --- Ramificaciones de compatibilidad ---

.no_cpuid:
    ; Cargar entorno de 16-bits (Sector 100)
    jmp _load_and_run_16

.only_32_bits:
    ; Configurar entorno exclusivo de 32-bits (Sector 120)
    in al, 0x92
    or al, 2
    out 0x92, al
    cli
    lgdt [gdt32_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp dword 0x0008:_kernel_32_only_entry

_load_and_run_16:
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    jmp 0x2000:0000

; =============================================================================
; [ MODO PROTEGIDO INTERMEDIO - 32 BITS ]
; =============================================================================
[BITS 32]
_kernel_32_entry:
    ; Sincronizar selectores de datos de 32-bits
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; -------------------------------------------------------------------------
    ; CONFIGURACIÓN DE TABLAS DE PÁGINAS (Identity Mapping 4GB)
    ; -------------------------------------------------------------------------
    mov edi, 0x1000
    mov cr3, edi                ; CR3 apunta a PML4
    xor eax, eax
    mov ecx, 4096
    rep stosd

    ; Enlazar tablas
    mov dword [0x1000], 0x2003  ; PML4 -> PDPT (Present + W)
    mov dword [0x2000], 0x3003  ; PDPT -> PD
    mov dword [0x3000], 0x4003  ; PD -> PT

    ; Mapear los primeros 2 MB
    mov edi, 0x4000
    mov eax, 0x00000003
    mov ecx, 512
.map_pages:
    mov [edi], eax
    add eax, 4096
    add edi, 8
    loop .map_pages

    ; Activar PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Activar Long Mode en MSR EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Activar Paginación en CR0
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Cargar GDT de 64-bits
    lgdt [gdt64_descriptor]

    ; Salto lejano definitivo a Modo Largo (0x0008 es el selector de código de 64-bits)
    jmp 0x0008:_kernel_64_entry

_kernel_32_only_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    hlt

; =============================================================================
; [ MODO LARGO NATIVO - 64 BITS ]
; =============================================================================
[BITS 64]
_kernel_64_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Imprimir aviso en pantalla VGA (Cyan)
    mov rdi, 0xB8000
    mov rsi, msg_kernel_64
.print_64:
    lodsb
    or al, al
    jz .disk_load
    mov [rdi], al
    mov byte [rdi+1], 0x0B
    add rdi, 2
    jmp .print_64

.disk_load:
    ; Cargar XSH64 (Sector 140)
    mov dx, 0x1F2
    mov al, 10
    out dx, al

    mov dx, 0x1F3
    mov al, 140
    out dx, al
    
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

.wait_ready:
    in al, dx
    test al, 0x08
    jz .wait_ready

    mov rdi, 0x200000           ; Destino RAM (2 MB)
    mov rcx, 2560
    mov dx, 0x1F0
    rep insw

    jmp 0x200000                ; Ejecutar Shell 64-bits

    cli
    hlt

; =============================================================================
; STRUCTS DE CONTROL GDT (Alineados de forma estricta)
; =============================================================================
align 16
gdt32:
    dd 0, 0                     ; Nulo
    dd 0x0000FFFF, 0x00CF9A00   ; Código 32-bits Base=0, Lim=4GB
    dd 0x0000FFFF, 0x00CF9200   ; Datos 32-bits Base=0, Lim=4GB
gdt32_descriptor:
    dw $ - gdt32 - 1
    dd gdt32

align 16
gdt64:
    dd 0, 0                     ; Nulo
    dd 0, 0x00209A00            ; Código 64-bits (Long Mode)
    dd 0, 0x00009200            ; Datos 64-bits
gdt64_descriptor:
    dw $ - gdt64 - 1
    dq gdt64

msg_kernel_64 db "XOS Kernel: Modo Largo Activado. Ejecutando XSH64...", 0
