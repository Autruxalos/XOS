; XPKG - Instalador rápido
xpkg_install:
    ; Leer header del .xpkg
    ; Verificar magic "XPKG"
    ; Extraer XEXE y escribir en |packages| o |apps|
    ret

xpkg_list:
    ; Listar paquetes instalados en EXFS
    ret
