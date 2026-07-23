bits 16

exofetch_main:
    ; Imprimir Logo en Cyan
    mov si, exofetch_logo
    mov bl, 0x0B           ; Color Cyan brillante
    call exofetch_imprimir_color

    ; Imprimir Información del Sistema Real
    mov si, msg_info_arch
    call xsh_imprimir_cadena

    mov si, msg_info_modo
    call xsh_imprimir_cadena

    ; Obtener Memoria Base (INT 12h -> AX = KB de RAM Base)
    mov si, msg_info_mem_base
    call xsh_imprimir_cadena

    int 0x12               ; Retorna tamaño en KiB en AX
    call exofetch_imprimir_numero

    mov si, msg_kb
    call xsh_imprimir_cadena

    ; Obtener Memoria Extendida (INT 15h, AH=88h)
    mov si, msg_info_mem_ext
    call xsh_imprimir_cadena

    mov ah, 0x88
    int 0x15
    jc .no_ext              ; Si el Flag Carry está activo, no hay ext memory
    call exofetch_imprimir_numero
    jmp .fin_mem

.no_ext:
    mov si, msg_cero
    call xsh_imprimir_cadena

.fin_mem:
    mov si, msg_kb
    call xsh_imprimir_cadena
    ret

; =============================================================================
; RUTINAS AUXILIARES DE EXOFETCH
; =============================================================================
exofetch_imprimir_color:
    mov ah, 0x09           ; Imprimir carácter con atributo de color
    mov bh, 0
    mov cx, 1              ; 1 repetición por carácter
.bucle:
    lodsb
    or al, al
    jz .fin
    cmp al, 10             ; Salto de línea
    je .nueva_linea
    int 0x10
    ; Avanzar cursor manualmente
    push ax
    mov ah, 0x03
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop ax
    jmp .bucle

.nueva_linea:
    mov ah, 0x03
    int 0x10
    inc dh                 ; Siguiente fila
    mov dl, 0              ; Columna 0
    mov ah, 0x02
    int 0x10
    mov ah, 0x09
    jmp .bucle
.fin:
    ret

exofetch_imprimir_numero:
    ; Convierte el valor en AX a decimal e imprime
    pusha
    mov cx, 0
    mov bx, 10
.m1:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz .m1
.m2:
    pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x0E
    int 0x10
    loop .m2
    popa
    ret

; =============================================================================
; DATOS E INTERFAZ DE EXOFETCH
; =============================================================================
msg_info_arch     db 13, 10, "OS: XOS (Real Mode Exokernel)", 13, 10, 0
msg_info_modo     db "Arquitectura: Intel 8086 / x86_16", 13, 10, 0
msg_info_mem_base db "RAM Convencional: ", 0
msg_info_mem_ext  db "RAM Extendida: ", 0
msg_kb            db " KB", 13, 10, 0
msg_cero          db "0", 0

exofetch_logo:
    db "                                                             #;                                     ", 10
    db "                                                          ,###S                                     ", 10
    db "                                                        :###+SS                                     ", 10
    db "                                                      .S##,  SS                                     ", 10
    db "                                                    ,##S.    SS;                                    ", 10
    db "                                                   S##,      .S%                                    ", 10
    db "                                                 +#%.        .S?                                    ", 10
    db "                                               *##,          .S?                                    ", 10
    db "                                             +#S:             *S,                                   ", 10
    db "                   .........................S#*............   +S,                                   ", 10
    db "                    .:;SSSSSSSS##########SS##########SSSSSSS%%%%%SSS%++*?.                          ", 10
    db "                                         ?SSSS??               %S                                    ", 10
    db "                                       ;SSS;.                  %%                                    ", 10
    db "                                      ;SS*                     ,%*                                  ", 10
    db "                                     %%S%                      ,?+                                  ", 10
    db "                                   .%%.S?                       *?.                                 ", 10
    db "                                  .%%  SS                       +?.                                 ", 10
    db "                                 .?*   %%,                      ,??                                 ", 10
    db "                                .%+    :%S,                      **                                 ", 10
    db "                                ?*       +%%,                    :*;                                ", 10
    db "                               *+         .;***::                ,*:                                ", 10
    db "                              :*               ;;;;;;;;+*????+:.  +*                                ", 10
    db "                              ;                                   ;+                                ", 10
    db "                              .                                    ;+                               ", 10, 0
