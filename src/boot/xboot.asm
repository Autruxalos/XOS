; =============================================================================
; XBOOT — Cargador de Arranque MBR para XOS [XSPEC-0001]
; =============================================================================
[BITS 16]
org 0x7C00

_xboot_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; 1. Activar Línea A20 (Puerto rápido 0x92)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; 2. Cargar el súper kernel en la dirección física 0x10000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov ah, 0x02
    mov al, 38                  ; Sectores a cargar
    mov ch, 0
    mov cl, 2                  ; Iniciar desde el Sector 2
    mov dh, 0
    mov dl, 0x80               ; Unidad de disco duro primaria
    int 0x13
    jc .error

    ; 3. Inicializar Modo Protegido de 32 bits
    lgdt [gdt32_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:.pmode

[BITS 32]
.pmode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    
    ; Transferir el Kernel a la posición Multiboot esperada (1 MB)
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, 4096
    rep movsd

    ; Salto final al punto de entrada
    jmp 0x100000

.error:
    hlt
    jmp .error

align 4
gdt32_start:
    dq 0x0000000000000000       ; Descriptor nulo
    dq 0x00CF9A000000FFFF       ; Código plano de 32 bits (Selector 0x08)
    dq 0x00CF92000000FFFF       ; Datos planos de 32 bits (Selector 0x10)
gdt32_end:

gdt32_desc:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start              ; Dirección en formato de 32 bits limpia

times 510-($-$$) db 0
dw 0xAA55
