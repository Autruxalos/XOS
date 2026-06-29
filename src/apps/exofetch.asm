; =============================================================================
; EXOFETCH — Fastfetch para XOS (XSPEC)
; =============================================================================
[BITS 64]

exofetch_main:
    call print_logo
    call print_system_info
    ret

print_logo:
    mov rsi, exofetch_logo
    mov bl, 0x0B          ; Cyan
    call xk_print
    ret

print_system_info:
    ; Aquí va la info real del sistema
    mov rsi, .info_arch
    call xk_println
    ; Añadir: memoria disponible, versión XKERNEL, modo actual (16/32/64), etc.
    ret

.info_arch db "Arquitectura: x86_64 (modo largo)", 10, 0
; ... más líneas

; === Logo desde tu archivo adjunto ===
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
