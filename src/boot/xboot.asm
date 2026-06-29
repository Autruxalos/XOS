; =============================================================================
; XBOOT - Versión Definitiva para pruebas
; =============================================================================
[BITS 16]
[ORG 0x7C00]

xboot_main:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [BOOT_DRIVE], dl

    mov ax, 0x03
    int 0x10

    mov si, MSG_LOADING
    call bios_print_string

load_kernel:
    mov bx, 0x9000
    mov ah, 0x02
    mov al, 255          ; Máximo práctico
    mov ch, 0
    mov dh, 0
    mov cl, 2
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc .error

    mov si, MSG_OK
    call bios_print_string
    jmp 0x0000:0x9000

.error:
    mov si, MSG_ERROR
    call bios_print_string

.halt:
    cli
    hlt
    jmp .halt

bios_print_string:
    mov ah, 0x0E
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

BOOT_DRIVE db 0
MSG_LOADING db "XOS Boot - Cargando...", 13, 10, 0
MSG_OK      db "Kernel cargado!", 13, 10, 0
MSG_ERROR   db "ERROR lectura disco!", 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
