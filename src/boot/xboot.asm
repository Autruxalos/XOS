
; =============================================================================
; XBOOT - Bootloader XOS  [XSPEC-0001]
; Correccion: usa INT 13h AH=42h (LBA extendido) en vez de CHS
; El CHS con AL=255 falla porque cruza cabezas. LBA no tiene ese limite.
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
 
    ; Guardar drive ANTES de cualquier otra cosa
    mov [BOOT_DRIVE], dl
 
    ; Modo texto limpio
    mov ax, 0x0003
    int 0x10
 
    mov si, MSG_LOADING
    call bios_print
 
    ; -----------------------------------------------------------------------
    ; Verificar soporte INT 13h extendido (LBA)
    ; Si el BIOS no lo soporta, caer a CHS limitado
    ; -----------------------------------------------------------------------
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc  .use_chs            ; CF=1 → no hay LBA extendido
    cmp bx, 0xAA55
    jne .use_chs
 
    ; -----------------------------------------------------------------------
    ; LBA extendido: cargar sectores 1..64 (32 KB) en 0x0000:0x9000
    ; DAP (Disk Address Packet) en stack — 16 bytes
    ; -----------------------------------------------------------------------
    mov si, MSG_LBA
    call bios_print
 
    push dword 0            ; LBA alto (32 bits superiores = 0)
    push dword 1            ; LBA bajo  = sector 1 (justo despues del MBR)
    push word  0x9000       ; offset destino
    push word  0x0000       ; segmento destino  → fisico 0x9000
    push word  64           ; sectores a leer (32 KB — suficiente para kernel)
    push word  0x0010       ; tamano DAP = 16 bytes
 
    mov si, sp              ; SI apunta al DAP
    mov ah, 0x42
    mov dl, [BOOT_DRIVE]
    int 0x13
 
    add sp, 16              ; limpiar DAP del stack
 
    jc  .error              ; CF=1 → error de lectura
 
    jmp .loaded
 
    ; -----------------------------------------------------------------------
    ; Fallback CHS: carga de a 63 sectores (1 pista completa) a la vez
    ; Maxima carga segura sin cruzar cabezas
    ; -----------------------------------------------------------------------
.use_chs:
    mov si, MSG_CHS
    call bios_print
 
    ; Primera llamada: sectores 2-64 (cabeza 0, cilindro 0)
    ; Limit: 63 sectores por llamada en CHS
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x9000          ; destino: ES:BX = 0x0000:0x9000
 
    mov ah, 0x02
    mov al, 63              ; 63 sectores (pista completa, seguro)
    mov ch, 0               ; cilindro 0
    mov dh, 0               ; cabeza 0
    mov cl, 2               ; sector CHS 2 (sector 1 LBA)
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc  .error
 
    ; Segunda llamada: siguientes 63 sectores (cabeza 1)
    ; ES:BX avanza 63*512 = 32256 bytes
    add bx, 63 * 512
 
    mov ah, 0x02
    mov al, 63
    mov ch, 0
    mov dh, 1               ; cabeza 1
    mov cl, 1               ; sector 1 de la cabeza 1
    mov dl, [BOOT_DRIVE]
    int 0x13
    ; Ignorar error aqui — con 63 sectores ya basta para el kernel
 
.loaded:
    mov si, MSG_OK
    call bios_print
 
    ; Saltar al kernel
    jmp 0x0000:0x9000
 
.error:
    mov si, MSG_ERROR
    call bios_print
    ; Mostrar codigo de error AH
    push ax
    mov  al, ah
    call print_hex_byte
    pop  ax
.halt:
    cli
    hlt
    jmp .halt
 
; -----------------------------------------------------------------------
; bios_print — imprime DS:SI via BIOS TTY
; -----------------------------------------------------------------------
bios_print:
    mov ah, 0x0E
    mov bx, 0x0007
.loop:
    lodsb
    or  al, al
    jz  .done
    int 0x10
    jmp .loop
.done:
    ret
 
; -----------------------------------------------------------------------
; print_hex_byte — imprime AL como 2 digitos hex (ayuda a debuggear)
; -----------------------------------------------------------------------
print_hex_byte:
    push ax
    push bx
    push cx
    mov  cx, ax
    ; nibble alto
    mov  al, cl
    shr  al, 4
    call .nibble
    ; nibble bajo
    mov  al, cl
    and  al, 0x0F
    call .nibble
    ; newline
    mov  ah, 0x0E
    mov  al, 0x0D
    int  0x10
    mov  al, 0x0A
    int  0x10
    pop  cx
    pop  bx
    pop  ax
    ret
.nibble:
    cmp  al, 10
    jl   .digit
    add  al, 'A' - 10
    jmp  .print
.digit:
    add  al, '0'
.print:
    mov  ah, 0x0E
    mov  bx, 0x0007
    int  0x10
    ret
 
; -----------------------------------------------------------------------
; Datos
; -----------------------------------------------------------------------
BOOT_DRIVE  db 0
MSG_LOADING db 'XOS Boot - Cargando...', 13, 10, 0
MSG_LBA     db 'Modo LBA', 13, 10, 0
MSG_CHS     db 'Modo CHS', 13, 10, 0
MSG_OK      db 'Kernel cargado! Saltando...', 13, 10, 0
MSG_ERROR   db 'ERROR lectura disco! Codigo: ', 0
 
; -----------------------------------------------------------------------
; Firma MBR obligatoria
; -----------------------------------------------------------------------
times 510 - ($ - $$) db 0
dw 0xAA55
