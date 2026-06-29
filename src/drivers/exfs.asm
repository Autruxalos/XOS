; =============================================================================
; EXFS — Sistema de Archivos XOS (8086 → Phenom II)
; =============================================================================
[BITS 16]

EXFS_MAGIC equ 'EXFS'

struc EXFS_SuperBlock
    magic resb 4
    version resw 1
    total_sectors resd 1
    xobj_count resw 1
    root_index resw 1
    label resb 32
    reserved resb 462
endstruc

struc XOBJ
    name resb 32
    type resb 1
    attributes resw 1
    start_lba resd 1
    size resd 1
    parent resw 1
    default_type resb 1
    reserved resb 25
endstruc

exfs_mount:
    mov si, msg_mount
    call bios_print
    ret

msg_mount db "EXFS montado |", 13, 10, 0

bios_print:
    mov ah, 0x0E
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret
