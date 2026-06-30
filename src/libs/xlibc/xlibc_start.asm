bits 64
global _start
extern xlibc_init
extern main

section .text
_start:
    ; 1. Configurar la pila local alineada a 16 bytes para el AMD Phenom
    mov rbp, rsp
    sub rsp, 32                 ; Espacio de sombra estándar para ABI de 64 bits

    ; 2. Inicializar los subsistemas de XLIBC
    call xlibc_init

    ; 3. Saltar a la aplicación del usuario escrita en C
    call main

    ; 4. Punto de Salida Seguro (EXIT) de vuelta al Kernel
    xor rax, rax
    jmp 0x10000                 ; Salto físico directo al bucle del XKernel
