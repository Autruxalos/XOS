struc EXFS_SuperBlock
    magic           db 'EXFS'          ; 4 bytes
    version         dw 1
    total_sectors   dd ?               ; Tamaño total del volumen
    free_sectors    dd ?
    xobj_count      dw ?               ; Cantidad de objetos en la tabla
    root_lba        dd ?               ; LBA del directorio raíz
    block_size      dw 512
    flags           db ?               ; Bits de características
    label           db 32 dup(?)       ; Nombre del volumen ("XOS System")
    reserved        times 400 db 0
endstruc
