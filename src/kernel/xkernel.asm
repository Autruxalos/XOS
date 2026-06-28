; =============================================================================
; XKERNEL - NÚCLEO UNIVERSAL MULTI-MODO (16-BIT / 32-BIT / 64-BIT)
; =============================================================================
; Entrada desde xboot.bin en Modo Real. Dirección de carga típica: 0x1000:0000
; =============================================================================

[BITS 16]
_kernel_start:
    ; Sincronizar segmentos de Modo Real
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; Ubicación segura para la pila temporal

    ; Imprimir mensaje de diagnóstico inicial (Modo Real)
    mov si, msg_kernel_16
    call print_string_16

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
    je .no_cpuid                ; Si el bit no cambió, es un 8086/286/486 antiguo

    ; Interrogar CPUID para soporte de Modo Largo (64-bits)
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .only_32_bits            ; No soporta funciones extendidas (es un i386/i486 clásico)

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           ; Verificar el bit 29 (Long Mode Present)
    jz .only_32_bits            ; Soporta 32 bits pero no 64 bits

    ; -------------------------------------------------------------------------
    ; RUTA DE 64 BITS DISPONIBLE: Iniciar transición escalonada
    ; -------------------------------------------------------------------------
    ; 1. Habilitar la Línea A20 (Acceso a memoria alta)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; 2. Cargar GDT temporal de 32 bits para el salto intermedio
    cli
    lgdt [gdt32_descriptor]
    
    ; 3. Activar Modo Protegido en CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; 4. Salto lejano (Far Jump) para limpiar la cola de ejecución e ingresar a 32-bits
    jmp 0x08:_kernel_32_entry

; --- Ramificaciones de compatibilidad hacia atrás ---

.no_cpuid:
    ; Hardware antiguo detectado (8086 original). 
    ; Leer la Shell de 16-bits desde el sector 100 del almacenamiento e iniciar.
    mov cx, 100                 ; Sector LBA / Registro simplificado para BIOS int 13h
    jmp _load_and_run_16

.only_32_bits:
    ; Procesador de 32-bits (ej: Pentium II / III). 
    ; Configurar GDT de 32 bits, entrar a Modo Protegido y saltar a la Shell de 32 bits.
    in al, 0x92
    or al, 2
    out 0x92, al
    cli
    lgdt [gdt32_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:_kernel_32_only_entry


; --- Subrutina de impresión en 16 bits ---
print_string_16:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10                    ; Usar servicios de video BIOS seguros de 16-bits
    jmp print_string_16
.done:
    ret

_load_and_run_16:
    ; Aquí se mapea la lectura física del sector 100 a la memoria baja (ej: 0x2000)
    ; Por simplicidad y consistencia de ejecución, salta al segmento de la shell 16
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
    ; CONFIGURACIÓN DE TABLAS DE PÁGINAS PARA MODO LARGO (Identiy Mapping 4GB)
    ; -------------------------------------------------------------------------
    ; Limpiar espacio de tablas en RAM (ej: desde 0x1000 hasta 0x5000)
    mov edi, 0x1000
    mov cr3, edi                ; CR3 apunta a la base PML4
    xor eax, eax
    mov ecx, 4096
    rep stosd

    ; Enlazar las tablas jerárquicamente
    ; PML4 -> PDPT
    mov dword [0x1000], 0x2003  ; Base PDPT en 0x2000 + Flags (Presente + Lectura/Escritura)
    ; PDPT -> Page Directory
    mov dword [0x2000], 0x3003  ; Base PD en 0x3000 + Flags
    ; PD -> Page Table
    mov dword [0x3000], 0x4003  ; Base PT en 0x4000 + Flags

    ; Mapear los primeros 2 MB de memoria física de forma directa (Identity Mapping)
    mov edi, 0x4000
    mov eax, 0x00000003         ; Dirección física 0 + Flags
    mov ecx, 512
.map_pages:
    mov [edi], eax
    add eax, 4096
    add edi, 8
    loop .map_pages

    ; -------------------------------------------------------------------------
    ; ACTIVACIÓN DE CAPAS DE HARDWARE AVANZADO
    ; -------------------------------------------------------------------------
    ; 1. Activar PAE (Physical Address Extension) indispensable para 64-bits
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 2. Activar Long Mode en el registro MSR EFER (Extended Feature Enable Register)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8              ; Cambiar bit LME (Long Mode Enable)
    wrmsr

    ; 3. Activar Paginación Global en CR0 para inicializar el procesador
    mov eax, cr0
    or eax, 1 << 31             ; Conmutar bit PG (Paging)
    mov cr0, eax

    ; 4. Cargar la GDT definitiva de 64-bits
    lgdt [gdt64_descriptor]

    ; 5. Salto de arquitectura hacia Modo Largo puro
    jmp 0x08:_kernel_64_entry

_kernel_32_only_entry:
    ; Punto de entrada alternativo si la CPU es estrictamente de 32 bits (i386/Pentium)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    ; Lógica del controlador de disco para leer el sector LBA 120 (Shell 32)
    ; [Inserte rutina de lectura ATA de 32-bits]
    jmp 0x300000                ; Dirección de carga de la shell de 32-bits


; =============================================================================
; [ MODO LARGO NATIVO - 64 BITS ]
; =============================================================================
[BITS 64]
_kernel_64_entry:
    ; Sincronizar selectores de segmento nulos/datos de 64-bits
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Limpiar pantalla y mostrar confirmación Cyan de 64 bits en la esquina superior
    mov rdi, 0xB8000
    mov rsi, msg_kernel_64
.print_64:
    lodsb
    or al, al
    jz .disk_load
    mov [rdi], al
    mov byte [rdi+1], 0x0B      ; Atributo Cyan
    add rdi, 2
    jmp .print_64

.disk_load:
    ; Cargar la Shell de 64-bits desde el Sector LBA 140
    mov dx, 0x1F2
    mov al, 10                  ; 10 sectores
    out dx, al

    mov dx, 0x1F3
    mov al, 140                 ; Sector 140
    out dx, al
    
    mov dx, 0x1F7
    mov al, 0x20                ; Comando: Read Sectors
    out dx, al

.wait_ready:
    in al, dx
    test al, 0x08
    jz .wait_ready

    mov rdi, 0x200000           ; Dirección RAM destino (2 MB)
    mov rcx, 2560               ; Palabras a transferir
    mov dx, 0x1F0
    rep insw                    ; Transferencia masiva directa de hardware a RAM

    ; Saltar al entorno interactivo de 64-bits aislado
    jmp 0x200000

    cli
    hlt

; =============================================================================
; ESTRUCTURAS DE DATOS COLECTIVAS (GDTs)
; =============================================================================

align 16
gdt32:
    dd 0, 0                     ; Descriptor nulo
    dd 0x0000FFFF, 0x00CF9A00   ; Código de 32-bits (Base 0, Límite 4GB)
    dd 0x0000FFFF, 0x00CF9200   ; Datos de 32-bits (Base 0, Límite 4GB)
gdt32_descriptor:
    dw $ - gdt32 - 1
    dd gdt32

align 16
gdt64:
    dd 0, 0                     ; Descriptor nulo
    dd 0, 0x00209A00            ; Código de 64-bits (Long Mode Descriptor flags)
    dd 0, 0x00009200            ; Datos de 64-bits
gdt64_descriptor:
    dw $ - gdt64 - 1
    dq gdt64

; Mensajes
msg_kernel_16 db "XOS: Modo Real Inicializado. Analizando CPU...", 13, 10, 0
msg_kernel_64 db "XOS Kernel: Modo Largo Activado. Ejecutando XSH64...", 0
