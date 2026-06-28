; =============================================================================
; EXFS - CONFIGURACIÓN DEL SUPERBLOQUE (32-bits Safe)
; =============================================================================

struc exfs_superblock
    .magic          resd 1    ; Firma mágica 'EXFS' (0x53465845)
    .total_sectors  resd 1    ; Tamaño total del disco en sectores
    .kernel_start   resd 1    ; Sector de inicio de XKERNEL
    .kernel_sectors resd 1    ; Cantidad de sectores que ocupa XKERNEL
    .xsh_start      resd 1    ; Sector de inicio de XSH
    .xsh_sectors    resd 1    ; Cantidad de sectores que ocupa XSH
    .block_size     resw 1    ; Tamaño de bloque (ej. 512 bytes)
    .unused         resb 30   ; Relleno para alinear
endstruc
