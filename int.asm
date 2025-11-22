bits 16

init_interrupts:
    cli
    ; Сохраняем старый обработчик
    mov ax, [0x0020]
    mov [old_timer], ax
    mov ax, [0x0022]
    mov [old_timer+2], ax
    
    ; Устанавливаем наш
    mov word [0x0020], timer_handler
    mov word [0x0022], cs
    sti
    ret

timer_handler:
    pusha
    inc word [timer_ticks]
    
    ; Обновляем часы каждую секунду
    test word [timer_ticks], 0x0F
    jnz .end
    call update_clock
    
.end:
    mov al, 0x20
    out 0x20, al
    popa
    iret

update_clock:
    ; Обновление времени в углу экрана
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    call bcd_to_bin
    mov [clock_hours], al
    
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    call bcd_to_bin
    mov [clock_minutes], al
    
    ; Моргание :
    mov ax, [timer_ticks]
    and ax, 0x10
    jz .show_colon
    mov byte [clock_separator], ' '
    jmp .display
.show_colon:
    mov byte [clock_separator], ':'
.display:
    ; Вывод в правый верхний угол
    mov ax, 0xB800
    mov es, ax
    mov di, 68
    
    ; Часы
    mov al, [clock_hours]
    call byte_to_ascii
    mov [es:di], ah
    mov [es:di+2], al
    
    ; Разделитель
    mov al, [clock_separator]
    mov [es:di+4], al
    
    ; Минуты
    mov al, [clock_minutes]
    call byte_to_ascii
    mov [es:di+6], ah
    mov [es:di+8], al
    ret

bcd_to_bin:
    push cx
    mov ah, al
    and al, 0x0F
    shr ah, 4
    mov cl, 10
    mul cl
    add al, ah
    pop cx
    ret

byte_to_ascii:
    mov ah, 0
    mov bl, 10
    div bl
    add ax, '00'
    ret

old_timer dw 0, 0
timer_ticks dw 0
clock_hours db 0
clock_minutes db 0
clock_separator db ':'