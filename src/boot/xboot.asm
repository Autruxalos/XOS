; =============================================================================
; XBOOT - CARGADOR SELECTOR Y CONFIGURADOR DE HARDWARE MULTI-ARQUITECTURA
; =============================================================================

org 0x7C00                      
bits 16                         

_start:
    xor ax, ax                  
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              
    mov [boot_drive], dl        

    ; --- CONTROLADOR DE DISCO: CARGAR EL MONORREPOSITORIO EN RAM ---
    mov ax, 0x1000              
    mov es, ax
    xor bx, bx                  

    mov ah, 0x02                
    mov al, 16                  
    mov ch, 0                   
    mov dh, 0                   
    mov cl, 2                   
    mov dl, [boot_drive]        
    int 0x13                    
    jc disk_error               

    ; --- INTERROGAR CPU (CPUID) ---
    pushfd                      
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jz no_cpuid                 

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb switch_to_32bit          

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           
    jz switch_to_32bit          

    ; --- ENRUTAMIENTO HACIA MODO LARGO (64-BITS) ---
    ; Configuración de Tablas de Paginación Identitaria en zona segura (0x9000)
    mov edi, 0x9000
    xor eax, eax
    mov ecx, 3072
    rep stosd

    mov dword [0x9000], 0xA003  ; PML4 -> PDPT
    mov dword [0xA000], 0xB003  ; PDPT -> PD
    mov dword [0xB000], 0x0083  ; PD Mapea primeros 2MB directos

    mov eax, 0x9000
    mov cr3, eax

    mov eax, cr4
    or eax, 1 << 5              ; Activar PAE
    mov cr4, eax

    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8              ; Activar LME (Long Mode Enable)
    wrmsr

    mov eax, cr0
    or eax, 1 << 31 | 1 << 0    ; Activar Paginación + Modo Protegido
    mov cr0, eax

    lgdt [gdt64_descriptor]     
    jmp 0x08:0x10080            

switch_to_32bit:
    cli                         
    mov eax, cr0
    or eax, 1                   
    mov cr0, eax

    lgdt [gdt32_descriptor]     
    jmp 0x08:0x10040            

disk_error:
no_cpuid:
    hlt                         
    jmp $

align 8
gdt32_start:
    dq 0x0000000000000000       
gdt32_code:
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00
gdt32_data:
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt32_end:

gdt32_descriptor:
    dw gdt32_end - gdt32_start - 1
    dd gdt32_start

gdt64_start:
    dq 0x0000000000000000       
gdt64_code:
    dq 0x00209A0000000000       
gdt64_data:
    dq 0x0000920000000000       
gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

boot_drive db 0x00

times 510 - ($ - $$) db 0       
dw 0xAA55
