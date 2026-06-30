; XPKG - Instalador rápido
xpkg-install:
    ; Leer header del .xpkg
    ; Verificar magic "XPKG"
    ; Extraer XEXE y escribir en |packages| o |apps|
    ret

xpkg-list:
    ; Listar paquetes instalados en EXFS
    ret
