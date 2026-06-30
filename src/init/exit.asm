; =============================================================================
; XOS MINIMAL INIT / EXIT PROCESS (`xinit.asm`)
; Compatible con la arquitectura híbrida de XOS (16/32/64 bits)
; =============================================================================

org 0x500000                    ; Dirección base estándar asignada en la RAM
bits 64                         ; Por defecto compilado para el Modo Largo del Phenom

; --- CABECERA ESTRICTA XEXE (16 Bytes) ---
xinit_header:
    .magic       db "XEXE"      ; Firma de validación del sistema de archivos EXFS
    .entry_point dd xinit_start ; Dirección física exacta de salto
    .flags       dw 0x0001      ; Indicador de proceso de sistema (Privilegiado)
    .reservado   dd 0x00000000  ; Alineación estructural estricta

; --- PUNTO DE ENTRADA ---
xinit_start:
    ; 1. Operación mínima de registro: Escribir un indicador directo en el hardware
    ; Usamos registros compatibles y direccionamiento absoluto para evitar colisiones
    mov rdi, 0xB8000            ; Dirección física de la memoria de video VGA
    add rdi, 320                ; Desplazamiento exacto a la tercera línea de la pantalla
    
    ; Escribir la firma de inicialización exitosa "[INIT]"
    mov dword [rdi], 0x0F490F5B ; '[', 'I' con atributos de texto blanco (0x0F)
    mov dword [rdi+4], 0x0F490F4E ; 'N', 'I'
    mov dword [rdi+8], 0x0F5D0F54 ; 'T', ']'

    ; 2. El "EXIT" absoluto del proceso
    ; En lugar de colapsar el Phenom con un bucle infinito ("jmp $") o un apagado ("hlt"),
    ; devolvemos el puntero de ejecución de forma limpia al punto de control del XKernel.
    ; Si el exokernel se encuentra mapeado en 0x10000, saltamos de regreso a su bucle base.
    
    xor rax, rax                ; Limpiar registro de estado de salida (0 = Éxito)
    jmp 0x10000                 ; Salto directo al bucle principal del exokernel
