; XSPEC-0003: Formato XEXE
struc XEXE_Header
    magic       db 'XEXE'
    arch        db 2          ; 0=16, 1=32, 2=64
    entry       dq entry_point
    code_size   dq code_end - code_start
    data_size   dq 0
    res_offset  dq 0
    flags       dd 0          ; bit0 = AutoExecutable
    version     dw 1
    reserved    times 6 db 0
endstruc

; Ejemplo de programa
[BITS 64]
[ORG 0]

header: ISTRUC XEXE_Header
    ; ... llenar según arriba
IEND

code_start:
entry_point:
    mov rsi, msg
    call xk_print
    ret

msg db "Programa XEXE ejecutado correctamente!", 10, 0
code_end:
