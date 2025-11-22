bits 16

clock_main:
    mov ax, 0x0003
    int 0x10
    
    mov si, clock_header
    call print_str
    
.clock_loop:
    ; Получаем часы
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    call bcd_to_str
    mov [time_disp], ax
    
    ; Получаем минуты
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    call bcd_to_str
    mov [time_disp+3], ax
    
    ; Моргание двоеточия
    mov ax, [ticks]
    and ax, 0x10
    jz .show_colon
    mov byte [time_disp+2], ' '
    jmp .show_time
.show_colon:
    mov byte [time_disp+2], ':'
    
.show_time:
    ; Выводим в центре экрана
    mov si, time_disp
    mov di, 160*12 + 70
    call print_at_position
    
    ; Проверяем клавишу ESC
    mov ah, 1
    int 0x16
    jz .clock_loop
    
    mov ah, 0
    int 0x16
    cmp al, 27
    jne .clock_loop
    
    ret

bcd_to_str:
    mov ah, al
    and al, 0x0F
    add al, '0'
    shr ah, 4
    and ah, 0x0F
    add ah, '0'
    xchg ah, al
    ret

print_at_position:
    push es
    mov ax, 0xB800
    mov es, ax
.loop:
    lodsb
    test al, al
    jz .done
    mov [es:di], al
    add di, 2
    jmp .loop
.done:
    pop es
    ret

print_str:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

clock_header db 'HDOS Clock - Press ESC to exit', 0x0D, 0x0A, 0x0A, 0
time_disp db '00:00', 0
ticks dw 0