bits 16

; Глобальная функция паники ядра
; IN: SI = строка с ошибкой
kernel_panic:
    cli
    call show_error_screen
    jmp .panic_loop

; Функция для вызова ошибки вручную
manual_panic:
    mov si, manual_panic_msg
    call show_error_screen
    jmp .panic_loop

; Проверка сочетания клавиш TAB+Q
check_panic_hotkey:
    mov ah, 0x02        ; Получить состояние клавиш
    int 0x16
    test al, 0x03       ; Проверить TAB (бит 1) и Q (бит 0)
    jz .no_hotkey
    
    ; Оба нажаты - вызываем панику
    call manual_panic
    
.no_hotkey:
    ret

; Показать экран ошибки
; IN: SI = строка ошибки
show_error_screen:
    ; Устанавливаем текстовый режим
    mov ax, 0x0003
    int 0x10
    
    ; Устанавливаем тёмно-синий фон
    mov ax, 0xB800
    mov es, ax
    mov di, 0
    mov cx, 2000
    mov ax, 0x1F20      ; Синий фон, белый текст
    rep stosw
    
    ; Рисуем рамку
    call draw_error_border
    
    ; Выводим заголовок ошибки
    mov di, 160*5 + 50  ; Центр
    mov si, error_header
    call print_at_pos_error
    
    ; Выводим сообщение об ошибке
    mov di, 160*8 + 30  ; Центр, шире для длинных сообщений
    call print_message_centered
    
    ; Выводим инструкцию
    mov di, 160*16 + 40
    mov si, reboot_instruction
    call print_at_pos_error
    
    ; Выводим системную информацию
    call display_system_info
    
    ret

; Рисуем рамку вокруг ошибки
draw_error_border:
    pusha
    mov ax, 0xB800
    mov es, ax
    
    ; Верхняя граница
    mov di, 160*4 + 20
    mov cx, 40
    mov ax, 0x1FCD      ; Двойная линия
.top:
    mov [es:di], ax
    add di, 2
    loop .top
    
    ; Нижняя граница
    mov di, 160*18 + 20
    mov cx, 40
.bottom:
    mov [es:di], ax
    add di, 2
    loop .bottom
    
    ; Боковые границы
    mov cx, 14          ; Высота
    mov di, 160*4 + 20
.sides:
    mov word [es:di], 0x1FBA    ; Вертикальная линия
    mov word [es:di+78], 0x1FBA
    add di, 160
    loop .sides
    
    ; Углы
    mov di, 160*4 + 20
    mov word [es:di], 0x1FC9    ; Левый верхний
    
    mov di, 160*4 + 98
    mov word [es:di], 0x1FBB    ; Правый верхний
    
    mov di, 160*18 + 20
    mov word [es:di], 0x1FC8    ; Левый нижний
    
    mov di, 160*18 + 98
    mov word [es:di], 0x1FBC    ; Правый нижний
    
    popa
    ret

; Вывод сообщения с центрированием
; IN: SI = сообщение, DI = позиция Y
print_message_centered:
    pusha
    mov ax, 0xB800
    mov es, ax
    
    ; Вычисляем длину строки
    push si
    mov cx, 0
.calc_length:
    lodsb
    test al, al
    jz .length_done
    inc cx
    jmp .calc_length
.length_done:
    pop si
    
    ; Вычисляем центрированную позицию
    mov ax, 80          ; Ширина экрана
    sub ax, cx          ; Минус длина текста
    shr ax, 1           ; Делим на 2
    shl ax, 1           ; Умножаем на 2 (т.к. 2 байта на символ)
    
    ; Устанавливаем позицию
    mov di, 160*8       ; Строка 8
    add di, ax
    
    ; Выводим текст
.loop:
    lodsb
    test al, al
    jz .done
    mov [es:di], al
    add di, 2
    jmp .loop
.done:
    popa
    ret

; Вывод текста в позиции
; IN: SI = текст, DI = позиция
print_at_pos_error:
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

; Вывод системной информации
display_system_info:
    pusha
    mov ax, 0xB800
    mov es, ax
    
    ; Выводим информацию о памяти
    mov di, 160*12 + 30
    mov si, mem_info
    call print_at_pos_error
    
    int 0x12            ; Получить размер памяти
    mov di, 160*12 + 50
    call err_print_dec_word
    
    mov di, 160*12 + 56
    mov si, kb_text
    call print_at_pos_error
    
    ; Выводим версию HDOS
    mov di, 160*13 + 30
    mov si, hdos_version
    call print_at_pos_error
    
    ; Выводим текущее время
    mov di, 160*14 + 30
    mov si, time_info
    call print_at_pos_error
    
    call get_current_time
    mov di, 160*14 + 50
    mov si, err_time_buffer
    call print_at_pos_error
    
    popa
    ret

; Получение текущего времени
get_current_time:
    pusha
    
    ; Часы
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    call bcd_to_ascii_error
    mov [err_time_buffer], ax
    
    ; Минуты
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    call bcd_to_ascii_error
    mov [err_time_buffer+3], ax
    
    ; Секунды
    mov al, 0x00
    out 0x70, al
    in al, 0x71
    call bcd_to_ascii_error
    mov [err_time_buffer+6], ax
    
    mov byte [err_time_buffer+2], ':'
    mov byte [err_time_buffer+5], ':'
    mov byte [err_time_buffer+8], 0
    
    popa
    ret

; BCD to ASCII для ошибок
bcd_to_ascii_error:
    mov ah, al
    and al, 0x0F
    add al, '0'
    shr ah, 4
    and ah, 0x0F
    add ah, '0'
    xchg ah, al
    ret

; Печать десятичного числа
; IN: AX = число, DI = позиция
err_print_dec_word:
    push ax
    push bx
    push cx
    push dx
    push es
    
    mov bx, 0xB800
    mov es, bx
    
    mov bx, 10
    xor cx, cx
    
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
    
.print:
    pop ax
    add al, '0'
    mov [es:di], al
    add di, 2
    loop .print
    
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.panic_loop:
    ; Ждём любую клавишу
    mov ah, 0x00
    int 0x16
    
    ; Перезагрузка
    mov ax, 0x0040
    mov ds, ax
    mov word [0x0072], 0x1234
    jmp 0xFFFF:0x0000

; Данные ошибок
error_header db 'HDOS KERNEL PANIC', 0
manual_panic_msg db 'Manual system shutdown initiated', 0
reboot_instruction db 'Press any key to reboot system', 0
mem_info db 'Memory: ', 0
hdos_version db 'HDOS: v2.0 Build 2024', 0
time_info db 'Time: ', 0
kb_text db ' KB', 0

; Буферы
err_time_buffer db '00:00:00', 0

; Экспортируемые функции
global kernel_panic
global check_panic_hotkey

kernel_panic.panic_loop:
manual_panic.panic_loop:
    jmp $