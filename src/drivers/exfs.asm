bits 16 ; Puede ser ensamblado o llamado desde código de 16, 32 o 64 bits cambiando las directivas de registros

; =============================================================================
; ESTRUCTURAS GEOMÉTRICAS DE EXFS
; =============================================================================
align 4
exfs_geometria:
    exfs_firma          db "EXFS16  "   ; 8 bytes - Identificador del Sistema de Archivos
    exfs_sectores_fat   dw 32           ; 2 bytes - Tamaño de la tabla de asignación
    exfs_entradas_root  dw 512          ; 2 bytes - Número máximo de archivos en el Root
    exfs_bytes_sector   dw 512          ; 2 bytes - Tamaño estándar de sector de hardware
    exfs_bloque_inicio  dw 65           ; 2 bytes - Sector físico donde empiezan los datos

; Estructura de plantilla para mapear una entrada de archivo (Para referencia del programador)
; nombre            times 8 db 0
; extension         times 3 db 0
; atributos         db 0
; bloque_inicial    dw 0
; tamano_archivo    dd 0
; reservado         times 14 db 0

; =============================================================================
; FUNCIÓN: exfs_buscar_archivo
; Busca un archivo en el buffer del Directorio Raíz cargado en memoria.
; Entrada: 
;   - ESI / SI: Puntero al nombre del archivo a buscar (Cadena de 11 bytes: "XEDIT   XEXE")
;   - EDI / DI: Puntero al buffer donde se cargó el Directorio Raíz de la memoria
; Salida:
;   - AX: Bloque inicial del archivo (0xFFFF si no se encuentra)
;   - ECX / CX: Tamaño del archivo en bytes
; =============================================================================
exfs_buscar_archivo:
    xor edx, edx
    mov dx, [exfs_entradas_root]       ; Número de intentos máximo (512 archivos)

.bucle_busqueda:
    push edi
    push esi
    mov ecx, 11                         ; Comparar los 11 caracteres (8 nombre + 3 extensión)
    repe cmpsb                          ; Comparar bytes en memoria
    pop esi
    pop edi
    je .archivo_encontrado              ; Si son iguales, encontramos el archivo

    add edi, 32                         ; Avanzar a la siguiente entrada de directorio (32 bytes)
    dec edx
    jnz .bucle_busqueda

.archivo_no_encontrado:
    mov ax, 0xFFFF                      ; Retornar indicador de error
    xor ecx, ecx
    ret

.archivo_encontrado:
    ; El puntero EDI está al inicio de la entrada del archivo válido (32 bytes)
    mov ax, [edi + 12]                  ; Offset 12: Extraer el valor del Bloque Inicial (2 bytes)
    mov ecx, [edi + 14]                 ; Offset 14: Extraer el Tamaño del Archivo (4 bytes)
    ret
