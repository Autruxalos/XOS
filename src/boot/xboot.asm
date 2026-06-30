org 0x7C00
bits 16

; =============================================================================
; ENTRADA DE CONFIGURACIÓN DE HARDWARE (MINIMA Y PRECISA)
; =============================================================================
xboot_inicio:
    cli                         ; Deshabilitar interrupciones inmediatamente
    xor ax, ax                  ; Limpieza absoluta de registros de segmento
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; Ubicación de la pila segura

    mov [unidad_arranque], dl   ; Guardar el número de unidad que nos dio la BIOS (Ej: 0x80)

    ; 1. Cargar el Directorio Raíz de EXFS en la memoria RAM (Sector 33 físico)
    ; Lo pondremos temporalmente en la dirección 0x9000
    mov ax, 33                  ; Sector lógico del Root Directory en EXFS
    mov cx, 1                   ; Leer 1 sector (suficiente para el arranque inicial)
    mov bx, 0x9000              ; Destino en RAM: 0x0000:0x9000
    call xboot_leer_sector

    ; 2. Cargar la Tabla de Asignación (XFAT) en la memoria RAM (Sector 1 físico)
    ; La mapearemos en la dirección 0x20000 (Segmento 0x2000:0x0000)
    mov ax, 1                   ; Sector lógico 1 (Inicio de XFAT)
    mov cx, 32                  ; Leer los 32 sectores que mide la XFAT
    mov bx, 0x2000              
    mov es, bx
    xor bx, bx                  ; Destino en RAM: 0x2000:0x0000 (0x20000 física)
    call xboot_leer_sector
    
    ; Restaurar ES a cero
    xor ax, ax
    mov es, ax

    ; 3. Buscar el archivo del Kernel ("XKERNEL XEXE") en el Directorio Raíz
    mov si, nombre_kernel       ; Puntero a la cadena de búsqueda
    mov di, 0x9000              ; Puntero al buffer del Root Directory
    call exfs_buscar_archivo
    
    cmp ax, 0xFFFF              ; ¿Se encontró el archivo?
    je xboot_error              ; Si no, detener el Phenom

    ; 4. Cargar los bloques del Kernel en la RAM destino (0x10000)
    ; Pasar de Bloque Lógico EXFS a Sector Físico se hace dentro de la rutina
    mov bx, 0x1000              
    mov es, bx
    xor bx, bx                  ; Destino en RAM: 0x1000:0x0000 (0x10000 física)
    call cargar_cadena_bloques

    ; 5. Salto de ejecución directo al Kernel cargado
    ; Detenemos la BIOS y transferimos el control absoluto al Exokernel
    xor ax, ax
    mov es, ax
    jmp 0x1000:0x0000           ; Ejecutar XKERNEL en hardware real

xboot_error:
.bucle:
    hlt                         ; Detener el procesador
    jmp .bucle

; =============================================================================
; DRIVER MÍNIMO DE DISCO (BIOS INT 13h)
; Entrada: AX = Sector Lógico, CX = Cantidad de sectores, ES:BX = Destino RAM
; =============================================================================
xboot_leer_sector:
    push ax
    push bx
    push cx
    
    ; Conversión simplificada de Sector Lógico a LBA/CHS para BIOS antiguas
    ; (Asumiendo geometría estándar de un USB de pruebas emulado como disco duro)
    mov dx, ax
    mov cx, ax
    shl cx, 6
    and cl, 0x3F
    inc cl                      ; Sector en CL
    
    mov ch, dl
    shr ch, 2                   ; Cilindro en CH
    
    mov dh, dl
    and dh, 0x01                ; Cabeza en DH
    
    mov dl, [unidad_arranque]   ; Recuperar unidad física
    mov ax, 0x0201              ; AH=02 (Leer), AL=01 (1 sector por llamada)
    int 0x13
    
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; ARCHIVOS INCLUIDOS (Estructuras de tu Sistema Operativo)
; =============================================================================
%include "exfs.asm"             ; Incluye 'exfs_buscar_archivo' y 'cargar_cadena_bloques'

; =============================================================================
; DATOS RÍGIDOS DE CONTROL
; =============================================================================
align 2
unidad_arranque db 0
nombre_kernel   db "XKERNEL XEXE" ; Nombre exacto de 11 bytes fijados en EXFS

; Relleno y firma obligatoria del Master Boot Record (MBR)
times 510-($-$$) db 0
dw 0xAA55
