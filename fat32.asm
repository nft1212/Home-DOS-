bits 16

; FAT32 структуры
bpb_instance:
    jmp start
    nop
    db 'MSWIN4.1'
    dw 512
    db 1
    dw 32
    db 2
    dw 0
    dw 2880
    db 0xF8
    dw 576
    dw 63
    dw 255
    dd 0
    dd 2880
    dd 576
    dw 0
    dw 0
    dd 2
    dw 1
    dw 6
    times 12 db 0
    db 0x80
    db 0
    db 0x29
    dd 0x12345678
    db 'HDOS DISK  '
    db 'FAT32   '

start:
    ret

; Глобальные переменные
fat_start_sector       dd 0
data_start_sector      dd 0
current_cluster        dd 0

init_fat32:
    pusha
    mov eax, 32
    mov [fat_start_sector], eax
    
    mov eax, 2
    mov dword [bpb_instance + 36], 576
    mul dword [bpb_instance + 36]
    add eax, 32
    mov [data_start_sector], eax
    popa
    ret

fat32_print_string:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

disk_error_msg db 'FAT32 Error!', 0