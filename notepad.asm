bits 16

notepad_main:
    ; Устанавливаем видеорежим 80x25
    mov ax, 0x0003
    int 0x10
    
    ; Очищаем экран с синим фоном
    mov ax, 0xB800
    mov es, ax
    mov di, 0
    mov cx, 2000
    mov ax, 0x1F00      ; Синий фон, чёрный текст
    rep stosw
    
    ; Отображаем заголовок
    mov si, header
    mov di, 160*0 + 30  ; Центр первой строки
    call print_at_pos
    
    ; Отображаем подсказки
    mov si, shortcuts
    mov di, 160*1 + 20
    call print_at_pos
    
    ; Рисуем рамку редактора
    call draw_editor_frame
    
    ; Инициализируем позицию курсора
    mov byte [cursor_x], 2
    mov byte [cursor_y], 4
    mov word [text_offset], 0
    
    ; Основной цикл редактора
.main_loop:
    call update_cursor
    call display_status
    
    ; Обработка ввода
    mov ah, 0x00
    int 0x16
    
    cmp ah, 0x01        ; ESC
    je .exit
    cmp ah, 0x0E        ; Backspace
    je .backspace
    cmp ah, 0x1C        ; Enter
    je .newline
    cmp ah, 0x4B        ; Left arrow
    je .left
    cmp ah, 0x4D        ; Right arrow
    je .right
    cmp ah, 0x48        ; Up arrow
    je .up
    cmp ah, 0x50        ; Down arrow
    je .down
    cmp ah, 0x53        ; Delete
    je .delete
    
    ; Обычный символ
    cmp al, 32
    jb .main_loop
    cmp al, 126
    ja .main_loop
    
    call insert_char
    jmp .main_loop

.backspace:
    call delete_char
    jmp .main_loop

.newline:
    call new_line
    jmp .main_loop

.left:
    call move_left
    jmp .main_loop

.right:
    call move_right
    jmp .main_loop

.up:
    call move_up
    jmp .main_loop

.down:
    call move_down
    jmp .main_loop

.delete:
    call delete_forward
    jmp .main_loop

.exit:
    ret

; Рисуем рамку редактора
draw_editor_frame:
    pusha
    mov ax, 0xB800
    mov es, ax
    
    ; Верхняя граница
    mov di, 160*3 + 20
    mov cx, 40
    mov ax, 0x1FCD      ; Двойная линия
.top:
    mov [es:di], ax
    add di, 2
    loop .top
    
    ; Боковые границы
    mov cx, 16          ; Высота редактора
    mov di, 160*4 + 20
.sides:
    mov word [es:di], 0x1FBA    ; Вертикальная линия
    mov word [es:di+78], 0x1FBA
    add di, 160
    loop .sides
    
    ; Нижняя граница
    mov di, 160*20 + 20
    mov cx, 40
.bottom:
    mov [es:di], ax
    add di, 2
    loop .bottom
    
    popa
    ret

; Обновляем позицию курсора
update_cursor:
    pusha
    ; Вычисляем позицию на экране
    mov al, [cursor_y]
    sub al, 4
    mov bl, 160
    mul bl
    mov bx, ax
    
    mov al, [cursor_x]
    sub al, 2
    mov cl, 2
    mul cl
    add bx, ax
    add bx, 22          ; Смещение для рамки
    
    ; Устанавливаем позицию курсора
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl
    out dx, al
    
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh
    out dx, al
    popa
    ret

; Отображаем статус бар
display_status:
    pusha
    mov ax, 0xB800
    mov es, ax
    
    ; Очищаем статус бар
    mov di, 160*22 + 20
    mov cx, 40
    mov ax, 0x1F20
.clear:
    mov [es:di], ax
    add di, 2
    loop .clear
    
    ; Позиция курсора
    mov di, 160*22 + 22
    mov si, status_pos
    call print_at_pos_no_attr
    
    ; X координата
    mov al, [cursor_x]
    sub al, 2
    call print_dec_byte
    
    mov al, ','
    mov [es:di], al
    add di, 2
    
    ; Y координата
    mov al, [cursor_y]
    sub al, 4
    call print_dec_byte
    
    ; Размер файла
    mov di, 160*22 + 50
    mov si, status_size
    call print_at_pos_no_attr
    
    mov ax, [text_length]
    call notepad_print_dec_word
    
    popa
    ret

; Вставка символа
insert_char:
    pusha
    
    ; Проверяем лимит текста
    mov ax, [text_length]
    cmp ax, 4096
    jae .exit
    
    ; Сдвигаем текст вправо
    mov si, text_buffer
    add si, [text_length]
    mov di, si
    inc di
    
    mov cx, [text_length]
    sub cx, [text_offset]
    std
    rep movsb
    cld
    
    ; Вставляем символ
    mov di, text_buffer
    add di, [text_offset]
    mov [di], al
    
    ; Обновляем длину и позицию
    inc word [text_length]
    inc word [text_offset]
    
    ; Перерисовываем текст
    call redraw_text
    
.exit:
    popa
    ret

; Удаление символа (Backspace)
delete_char:
    pusha
    
    cmp word [text_offset], 0
    je .exit
    
    ; Сдвигаем текст влево
    mov si, text_buffer
    add si, [text_offset]
    mov di, si
    dec di
    
    mov cx, [text_length]
    sub cx, [text_offset]
    cld
    rep movsb
    
    ; Обновляем длину и позицию
    dec word [text_length]
    dec word [text_offset]
    
    ; Перерисовываем текст
    call redraw_text
    
.exit:
    popa
    ret

; Удаление символа вперед (Delete)
delete_forward:
    pusha
    
    mov ax, [text_offset]
    cmp ax, [text_length]
    jae .exit
    
    ; Сдвигаем текст влево
    mov si, text_buffer
    add si, [text_offset]
    inc si
    mov di, si
    dec di
    
    mov cx, [text_length]
    sub cx, [text_offset]
    dec cx
    cld
    rep movsb
    
    ; Обновляем длину
    dec word [text_length]
    
    ; Перерисовываем текст
    call redraw_text
    
.exit:
    popa
    ret

; Новая строка
new_line:
    pusha
    call insert_char
    mov al, 13
    call insert_char
    popa
    ret

; Перемещение курсора
move_left:
    cmp word [text_offset], 0
    je .exit
    dec word [text_offset]
.exit:
    ret

move_right:
    mov ax, [text_offset]
    cmp ax, [text_length]
    jae .exit
    inc word [text_offset]
.exit:
    ret

move_up:
    ; Простая реализация - перейти на предыдущую строку
    cmp word [text_offset], 40
    jb .exit
    sub word [text_offset], 40
.exit:
    ret

move_down:
    ; Простая реализация - перейти на следующую строку
    mov ax, [text_offset]
    add ax, 40
    cmp ax, [text_length]
    ja .exit
    mov [text_offset], ax
.exit:
    ret

; Перерисовка текста в редакторе
redraw_text:
    pusha
    mov ax, 0xB800
    mov es, ax
    
    ; Очищаем область редактора
    mov di, 160*4 + 22
    mov cx, 16          ; 16 строк
.clear_lines:
    push cx
    push di
    mov cx, 38          ; 38 символов в строке
    mov ax, 0x1F20
.clear_line:
    mov [es:di], ax
    add di, 2
    loop .clear_line
    pop di
    add di, 160
    pop cx
    loop .clear_lines
    
    ; Отображаем текст
    mov si, text_buffer
    mov di, 160*4 + 22
    mov cx, [text_length]
    cmp cx, 608         ; 16*38 символов
    jbe .draw
    mov cx, 608
.draw:
    jcxz .done
    mov al, [si]
    cmp al, 13
    je .newline
    mov [es:di], al
    add di, 2
    inc si
    loop .draw
    jmp .done
    
.newline:
    ; Переход на следующую строку
    push ax
    mov ax, di
    mov bl, 160
    div bl
    inc al
    mul bl
    mov di, ax
    pop ax
    inc si
    loop .draw
    
.done:
    popa
    ret

; Вспомогательные функции печати
print_at_pos:
    push es
    mov ax, 0xB800
    mov es, ax
.loop:
    lodsb
    test al, al
    jz .done
    mov [es:di], al
    inc di
    mov byte [es:di], 0x1F  ; Атрибут
    inc di
    jmp .loop
.done:
    pop es
    ret

print_at_pos_no_attr:
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

print_dec_byte:
    push ax
    push bx
    push cx
    push dx
    
    mov bl, 10
    mov cx, 0
    
.divide:
    xor ah, ah
    div bl
    push ax
    inc cx
    test al, al
    jnz .divide
    
.print:
    pop ax
    mov al, ah
    add al, '0'
    mov [es:di], al
    add di, 2
    loop .print
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

notepad_print_dec_word:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10
    mov cx, 0
    
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
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Данные
header db 'HDOS Notepad v1.0', 0
shortcuts db 'ESC:Exit  Arrows:Navigate  Enter:Newline', 0
status_pos db 'Pos: ', 0
status_size db 'Size: ', 0

; Переменные редактора
cursor_x db 2
cursor_y db 4
text_offset dw 0
text_length dw 0
text_buffer times 4096 db 0