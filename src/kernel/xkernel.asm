org 0x0000
bits 16

fase_16_bits:
    cli
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00

    in al, 0x92
    or al, 2
    out 0x92, al

    ; Ajuste de la GDT de 32 bits a dirección física lineal (0x10000)
    mov eax, gdt32_start
    add eax, 0x10000
    mov [gdt32_descriptor_fisico + 2], eax
    lgdt [gdt32_descriptor_fisico]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:(0x10000 + fase_32_bits)

bits 32
fase_32_bits:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Paginación Directa (Identity Mapping de los primeros 2MB)
    mov edi, 0x1000
    mov cr3, edi
    xor eax, eax
    mov ecx, 3072
    rep stosd

    mov dword [0x1000], 0x2003  ; PML4 -> PDPT
    mov dword [0x2000], 0x3003  ; PDPT -> PD
    mov dword [0x3000], 0x0083  ; PD -> 2MB Gigante

    mov eax, cr4
    or eax, 1 << 5              ; Habilitar PAE
    mov cr4, eax

    mov ecx, 0xC0000080         ; EFER MSR
    rdmsr
    or eax, 1 << 8              ; LME = 1
    wrmsr

    mov eax, cr0
    or eax, 1 << 31             ; Paging = 1
    mov cr0, eax

    ; Ajuste de la GDT de 64 bits a dirección física lineal (0x10000)
    mov eax, gdt64_start
    add eax, 0x10000
    mov [gdt64_descriptor_fisico + 2], eax
    lgdt [gdt64_descriptor_fisico]

    jmp 0x08:(0x10000 + fase_64_bits)

bits 64
fase_64_bits:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Pintar "XOS" en pantalla
    mov rax, 0x0F4F0F580F4F580F 
    mov qword [0xB8000], rax

.bucle_kernel:
    hlt
    jmp .bucle_kernel

align 4
gdt32_start:
    dd 0, 0
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF
gdt32_end:

gdt32_descriptor_fisico:
    dw gdt32_end - gdt32_start - 1
    dd 0

align 4
gdt64_start:
    dd 0, 0
    dw 0, 0, 0x9A00, 0x0020
    dw 0, 0, 0x9200, 0x0000
gdt64_end:

gdt64_descriptor_fisico:
    dw gdt64_end - gdt64_start - 1
    dd 0
