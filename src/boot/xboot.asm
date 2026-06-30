org 0x7C00
bits 16

; =============================================================================
; ENTRADA DE CONFIGURACIÓN DE HARDWARE (MÍNIMA Y ULTRA-COMPATIBLE)
; =============================================================================
xboot_inicio:
    jmp short .inicializar_entorno
    nop                             ; Relleno estándar para compatibilidad OEM

.inicializar_entorno:
    cli                             ; Deshabilitar interrupciones
    xor ax, ax                      ; Limpieza absoluta de registros de segmento
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00                  ; Ubicación de la pila segura

    mov [unidad_arranque], dl       ; Guardar la unidad que nos dio la BIOS (Ej: 0x80)

    ; 1. Cargar el Directorio Raíz de EXFS en RAM (Sector 33 físico)
    ; Destino temporal en la dirección 0x0000:0x9000
    mov ax, 33                      ; Sector lógico de inicio del Root Directory
    mov cl, 1                       ; Cantidad: 1 sector
    mov bx, 0x9000                  ; Offset destino
    call xboot_leer_sector

    ; 2. Cargar la Tabla de Asignación (XFAT) en RAM (Sectores 1 al 32 físico)
    ; Destino mapeado en la dirección física 0x20000 (Segmento 0x2000:0x0000)
    mov ax, 1                       ; Sector lógico 1 (Inicio de XFAT)
    mov cl, 32                      ; Cantidad: 32 sectores de tamaño XFAT
    mov bx, 0x2000              
    mov es, bx
    xor bx, bx                      ; ES:BX = 0x2000:0x0000 (0x20000)
    call xboot_leer_sector
    
    ; Restaurar segmento ES a cero por seguridad
    xor ax, ax
    mov es, ax

    ; =============================================================================
    ; PASOS 3 Y 4: CARGA MEDIANTE SISTEMA DE ARCHIVOS EXFS (DISEÑO ORIGINAL)
    ; =============================================================================
    ; 3. Buscar el archivo del Kernel ("XKERNEL XEXE") en el Directorio Raíz
    call exfs_buscar_archivo
    cmp ax, 0xFFFF
    je xboot_error                  ; Si no lo encuentra, error (pantalla parpadeante)

    ; 4. Cargar los bloques lógicos de datos del Kernel en RAM
    mov bx, 0x1000  
    mov es, bx
    xor bx, bx                      ; ES:BX = 0x1000:0x0000 (Dirección física 0x10000)
    call cargar_cadena_bloques  
    
    ; Restaurar segmento ES a cero por seguridad
    xor ax, ax
    mov es, ax

    ; =============================================================================
    ; 5. TRANSFERENCIA DE CONTROL AL EXOKERNEL
    ; =============================================================================
    jmp 0x1000:0x0000               ; ¡Salto al Kernel cargado en Modo Real!

xboot_error:
    ; Parpadear pantalla en rojo/azul en modo texto indicando fallo
    mov ax, 0x0B04
    int 0x10
.bucle:
    hlt                             ; Detener el procesador
    jmp .bucle

; =============================================================================
; DRIVER LBA ULTRA-COMPATIBLE PARA BIOS QUISQUILLOSAS (Extensiones INT 13h)
; Entrada: AX = Sector Lógico Lineal, CL = Cantidad, ES:BX = Destino RAM
; =============================================================================
xboot_leer_sector:
    pusha                           ; Resguardar todos los registros generales

    ; Rellenar dinámicamente el Paquete DAP en memoria
    mov [dap_sector_bajo], ax       ; Dirección sector inicial
    mov [dap_cantidad], cl          ; Sectores a leer
    mov [dap_buffer_offset], bx     ; Destino offset
    mov [dap_buffer_segment], es    ; Destino segmento

    mov si, dap_packet              ; DS:SI apunta al paquete de control
    mov dl, [unidad_arranque]       ; Identificador de unidad física
    mov ah, 0x42                    ; Función BIOS: Lectura LBA Extendida
    int 0x13
    jc xboot_error                  ; Si la BIOS falla saltar a la rutina de error

    popa                            ; Restaurar registros en caso de éxito
    ret

; =============================================================================
; ESTRUCTURAS DE DATOS Y PAQUETE DE ARRANQUE (DAP)
; =============================================================================
align 4
dap_packet:
    dap_tamano          db 16       ; Tamaño estructural fijo
    dap_reservado       db 0
    dap_cantidad        dw 0        ; Sectores a transferir
    dap_buffer_offset   dw 0        ; Puntero RAM: Offset
    dap_buffer_segment  dw 0        ; Puntero RAM: Segmento
    dap_sector_bajo     dd 0        ; LBA Dirección baja (4 bytes)
    dap_sector_alto     dd 0        ; LBA Dirección alta (4 bytes)

unidad_arranque     db 0
nombre_kernel       db "XKERNEL XEXE" ; Firma rígida de 11 bytes

; Incluye las funciones matemáticas 'exfs_buscar_archivo' y 'cargar_cadena_bloques'
; Nota: Al compilar desde la raíz del proyecto, la ruta desde src/boot/ hacia src/drivers/ es esta:
%include "src/drivers/exfs.asm"

; =============================================================================
; TABLA DE PARTICIONES MBR ESTÁNDAR (Falsa, para engañar a BIOS quisquillosas)
; Forzar el modo disco rígido en placas antiguas (Ocupa bytes 446 al 509)
; =============================================================================
times 446-($-$$) db 0

; Entrada de Partición 1 (Activa, abarca la geometría virtual del disco)
db 0x80                         ; Active Boot Flag (Partición de arranque)
db 0x01, 0x01, 0x00             ; CHS inicio falso
db 0x7F                         ; ID de Sistema de Archivos (Seguro / No asignado)
db 0xFE, 0xFF, 0xFF             ; CHS fin falso
dd 0x00000001                   ; LBA de inicio (Sector 1, donde vive la XFAT)
dd 0x000FFFFF                   ; Tamaño virtual total en sectores

; Entradas de partición 2, 3 y 4 vacías (16 bytes * 3 = 48 bytes)
times 48 db 0

; Firma de validación obligatoria del MBR
dw 0xAA55
