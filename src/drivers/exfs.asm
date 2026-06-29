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

struc XOBJ_Entry
    name        db 32 dup(?)     ; Nombre (sin path, máx 31 chars + null)
    type        db ?             ; 0=Dir, 1=Programa(XEXE), 2=Documento, 3=Imagen...
    attributes  dw ?             ; ReadOnly, AutoExecutable, Hidden, Compression...
    start_lba   dd ?             ; Primer sector de datos
    size        dd ?             ; Tamaño en bytes
    parent      dw ?             ; Índice del XOBJ padre (para jerarquía simple)
    default_type db ?            ; Para Directorios Inteligentes
    reserved    times 20 db 0
endstruc
