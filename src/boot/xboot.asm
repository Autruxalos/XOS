; =============================================================================
; XBOOT — Cargador MBR Mejorado para XOS
; Lee más sectores + mejor diagnóstico
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

    ; Limpiar pantalla
    mov ax, 0x03
    int 0x10

    mov si, MSG_LOADING
    call bios_print_string

load_kernel:
    mov bx, 0x9000          ; Dirección destino del kernel
    mov ah, 0x02
    mov al, 128             ; ← LEEMOS 128 SECTORES (64 KB) - Más espacio seguro
    mov ch, 0x00
    mov dh, 0x00
    mov cl, 0x02            ; Empezar desde sector 2
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc .disk_error

    cmp al, 0
    jz .disk_error

    mov si, MSG_LOAD_OK
    call bios_print_string

    jmp 0x0000:0x9000       ; Saltar al kernel

.disk_error:
    mov si, MSG_ERROR
    call bios_print_string

.halt:
    cli
    hlt
    jmp .halt

bios_print_string:
    push ax
    push bx
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    pop bx
    pop ax
    ret

BOOT_DRIVE:     db 0
MSG_LOADING:    db "XOS: Cargando kernel desde disco...", 13, 10, 0
MSG_LOAD_OK:    db "XOS: Kernel cargado. Saltando a 0x9000...", 13, 10, 0
MSG_ERROR:      db "XOS: ERROR al leer disco!", 13, 10, 0

; Firma MBR
times 510 - ($ - $$) db 0
dw 0xAA55
