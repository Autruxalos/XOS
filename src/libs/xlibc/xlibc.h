#ifndef _XLIBC_H_
#define _XLIBC_H_

// Tipos de datos estrictos para arquitectura de 64 bits
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef uint64_t           size_t;

// Estructura de archivo rígida mapeada a una entrada EXFS de 32 bytes
typedef struct {
    char     nombre[8];
    char     extension[3];
    uint8_t  atributo;
    uint16_t bloque_inicio;
    uint32_t tamano;
    uint64_t posicion_actual; // Control de lectura en RAM
} XFILE;

// Constantes globales de hardware expuestas por el Exokernel
#define VIDEO_MEMORY ((uint8_t*)0xB8000)
#define EXFS_ROOT    ((uint8_t*)0x9000)
#define XFAT_TABLE   ((uint16_t*)0x20000)

// Prototipos de las funciones en esteroides
void    xlibc_init(void);
void    printf(const char* formato, ...);
XFILE* fopen(const char* nombre, const char* modo);
size_t  fread(void* ptr, size_t tamano, size_t miembros, XFILE* flujo);

#endif
