bits 16

snake_main:
    ; Устанавливаем видеорежим
    mov ax, 0x0003
    int 0x10
    
    ; Инициализируем игру
    call snake_init
    
    ; Основной игровой цикл
.game_loop:
    call snake_draw_frame
    call snake_handle_input
    call snake_update
    call snake_check_collision
    jc .game_over
    
    ; Задержка для скорости игры
    call snake_delay
    jmp .game_loop

.game_over:
    call snake_show_game_over
    ret

; Инициализация игры
snake_init:
    ; Инициализируем змейку
    mov byte [snake_length], 3
    
    ; Голова змейки в центре
    mov byte [snake_x], 40
    mov byte [snake_y], 12
    
    ; Тело змейки
    mov byte [snake_body_x], 39
    mov byte [snake_body_y], 12
    mov byte [snake_body_x+1], 38
    mov byte [snake_body_y+1], 12
    
    ; Начальное направление
    mov byte [snake_direction], 'R'  ; R - right
    
    ; Генерируем первую еду
    call snake_generate_food
    
    ; Счет
    mov word [snake_score], 0
    
    ret

; Отрисовка игрового поля
snake_draw_frame:
    ; Очищаем экран
    mov ax, 0x0003
    int 0x10
    
    ; Рисуем границы
    call snake_draw_borders
    
    ; Рисуем змейку
    call snake_draw_snake
    
    ; Рисуем еду
    call snake_draw_food
    
    ; Рисуем счет
    call snake_draw_score
    
    ret

; Рисуем границы поля
snake_draw_borders:
    pusha
    
    ; Верхняя граница
    mov dh, 0
    mov dl, 0
    mov cx, 80
.top:
    call snake_set_cursor
    mov al, 205        ; ═
    call snake_print_char
    inc dl
    loop .top
    
    ; Нижняя граница
    mov dh, 24
    mov dl, 0
    mov cx, 80
.bottom:
    call snake_set_cursor
    mov al, 205        ; ═
    call snake_print_char
    inc dl
    loop .bottom
    
    ; Левая граница
    mov dh, 1
    mov dl, 0
    mov cx, 23
.left:
    call snake_set_cursor
    mov al, 186        ; ║
    call snake_print_char
    inc dh
    loop .left
    
    ; Правая граница
    mov dh, 1
    mov dl, 79
    mov cx, 23
.right:
    call snake_set_cursor
    mov al, 186        ; ║
    call snake_print_char
    inc dh
    loop .right
    
    ; Углы
    mov dh, 0
    mov dl, 0
    call snake_set_cursor
    mov al, 201        ; ╔
    call snake_print_char
    
    mov dh, 0
    mov dl, 79
    call snake_set_cursor
    mov al, 187        ; ╗
    call snake_print_char
    
    mov dh, 24
    mov dl, 0
    call snake_set_cursor
    mov al, 200        ; ╚
    call snake_print_char
    
    mov dh, 24
    mov dl, 79
    call snake_set_cursor
    mov al, 188        ; ╝
    call snake_print_char
    
    popa
    ret

; Рисуем змейку
snake_draw_snake:
    pusha
    
    ; Рисуем голову
    mov dh, [snake_y]
    mov dl, [snake_x]
    call snake_set_cursor
    mov al, 2          ; ☻ - голова
    call snake_print_char
    
    ; Рисуем тело
    mov cl, [snake_length]
    dec cl             ; Минус голова
    mov si, snake_body_x
    mov di, snake_body_y
.draw_body:
    mov dh, [di]
    mov dl, [si]
    call snake_set_cursor
    mov al, 15         ; ○ - тело
    call snake_print_char
    inc si
    inc di
    loop .draw_body
    
    popa
    ret

; Рисуем еду
snake_draw_food:
    pusha
    mov dh, [food_y]
    mov dl, [food_x]
    call snake_set_cursor
    mov al, 4          ; ♦ - еда
    call snake_print_char
    popa
    ret

; Рисуем счет
snake_draw_score:
    pusha
    mov dh, 0
    mov dl, 2
    call snake_set_cursor
    
    mov si, score_text
    call snake_print_string
    
    mov ax, [snake_score]
    call snake_print_number
    
    popa
    ret

; Обработка ввода
snake_handle_input:
    mov ah, 0x01
    int 0x16
    jz .no_input
    
    mov ah, 0x00
    int 0x16
    
    ; Стрелки или WASD
    cmp ah, 0x48       ; Up arrow
    je .up
    cmp ah, 0x50       ; Down arrow
    je .down
    cmp ah, 0x4B       ; Left arrow
    je .left
    cmp ah, 0x4D       ; Right arrow
    je .right
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'a'
    je .left
    cmp al, 'd'
    je .right
    cmp al, 27         ; ESC
    je .exit
    jmp .no_input

.up:
    cmp byte [snake_direction], 'D'
    je .no_input
    mov byte [snake_direction], 'U'
    jmp .no_input

.down:
    cmp byte [snake_direction], 'U'
    je .no_input
    mov byte [snake_direction], 'D'
    jmp .no_input

.left:
    cmp byte [snake_direction], 'R'
    je .no_input
    mov byte [snake_direction], 'L'
    jmp .no_input

.right:
    cmp byte [snake_direction], 'L'
    je .no_input
    mov byte [snake_direction], 'R'
    jmp .no_input

.exit:
    pop ax             ; Чистим стек
    jmp snake_main.end

.no_input:
    ret

; Обновление позиции змейки
snake_update:
    ; Сохраняем текущую позицию головы
    mov al, [snake_x]
    mov bl, [snake_y]
    
    ; Сдвигаем тело
    mov cl, [snake_length]
    dec cl
    mov si, snake_body_x + 62   ; Конец массива
    mov di, snake_body_y + 62
    
.body_shift:
    mov dl, [si-1]
    mov [si], dl
    mov dl, [di-1]
    mov [di], dl
    dec si
    dec di
    loop .body_shift
    
    ; Первый сегмент тела становится на место старой головы
    mov [snake_body_x], al
    mov [snake_body_y], bl
    
    ; Двигаем голову
    cmp byte [snake_direction], 'U'
    je .move_up
    cmp byte [snake_direction], 'D'
    je .move_down
    cmp byte [snake_direction], 'L'
    je .move_left
    cmp byte [snake_direction], 'R'
    je .move_right

.move_up:
    dec byte [snake_y]
    jmp .move_done

.move_down:
    inc byte [snake_y]
    jmp .move_done

.move_left:
    dec byte [snake_x]
    jmp .move_done

.move_right:
    inc byte [snake_x]
    jmp .move_done

.move_done:
    ; Проверяем съела ли змейка еду
    mov al, [snake_x]
    mov bl, [food_x]
    cmp al, bl
    jne .no_food
    
    mov al, [snake_y]
    mov bl, [food_y]
    cmp al, bl
    jne .no_food
    
    ; Змейка съела еду!
    call snake_eat_food

.no_food:
    ret

; Змейка съедает еду
snake_eat_food:
    ; Увеличиваем длину
    inc byte [snake_length]
    
    ; Увеличиваем счет
    inc word [snake_score]
    
    ; Генерируем новую еду
    call snake_generate_food
    ret

; Генерация еды
snake_generate_food:
.generate:
    ; Случайная позиция X (1-78)
    call snake_random
    and al, 0x7F
    cmp al, 78
    ja .generate
    cmp al, 1
    jb .generate
    mov [food_x], al
    
    ; Случайная позиция Y (1-23)
    call snake_random
    and al, 0x1F
    cmp al, 23
    ja .generate
    cmp al, 1
    jb .generate
    mov [food_y], al
    
    ; Проверяем, что еда не на змейке
    call snake_check_food_collision
    jc .generate
    
    ret

; Проверка столкновений
snake_check_collision:
    ; Проверка с границами
    mov al, [snake_x]
    cmp al, 1
    jb .collision
    cmp al, 78
    ja .collision
    
    mov al, [snake_y]
    cmp al, 1
    jb .collision
    cmp al, 23
    ja .collision
    
    ; Проверка с телом
    mov cl, [snake_length]
    dec cl
    mov si, snake_body_x
    mov di, snake_body_y
.check_body:
    mov al, [snake_x]
    cmp al, [si]
    jne .next_segment
    mov al, [snake_y]
    cmp al, [di]
    je .collision
.next_segment:
    inc si
    inc di
    loop .check_body
    
    clc
    ret

.collision:
    stc
    ret

; Проверка позиции еды
snake_check_food_collision:
    ; Проверяем с головой
    mov al, [food_x]
    cmp al, [snake_x]
    jne .check_body
    mov al, [food_y]
    cmp al, [snake_y]
    je .collision
    
.check_body:
    ; Проверяем с телом
    mov cl, [snake_length]
    mov si, snake_body_x
    mov di, snake_body_y
.check_loop:
    mov al, [food_x]
    cmp al, [si]
    jne .next
    mov al, [food_y]
    cmp al, [di]
    je .collision
.next:
    inc si
    inc di
    loop .check_loop
    
    clc
    ret

.collision:
    stc
    ret

; Простой рандом на основе таймера
snake_random:
    mov ah, 0x00
    int 0x1A          ; Получаем тики таймера
    mov al, dl        ; Используем младший байт
    ret

; Задержка для скорости игры
snake_delay:
    push cx
    mov cx, 0x0FFF
.delay_loop:
    nop
    nop
    nop
    loop .delay_loop
    pop cx
    ret

; Экран игры окончена
snake_show_game_over:
    mov dh, 10
    mov dl, 30
    call snake_set_cursor
    mov si, game_over_text
    call snake_print_string
    
    mov dh, 12
    mov dl, 35
    call snake_set_cursor
    mov si, final_score_text
    call snake_print_string
    
    mov ax, [snake_score]
    call snake_print_number
    
    ; Ждем любую клавишу
    mov ah, 0x00
    int 0x16
    
    ret

; Вспомогательные функции
snake_set_cursor:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    ret

snake_print_char:
    mov ah, 0x0A
    mov bh, 0
    mov cx, 1
    int 0x10
    ret

snake_print_string:
    lodsb
    test al, al
    jz .done
    call snake_print_char
    inc dl
    call snake_set_cursor
    jmp snake_print_string
.done:
    ret

snake_print_number:
    push ax
    push bx
    push cx
    push dx
    
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
    call snake_print_char
    inc dl
    call snake_set_cursor
    loop .print
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Данные игры
snake_length db 0
snake_x db 0
snake_y db 0
snake_direction db 0

; Тело змейки (максимум 64 сегмента)
snake_body_x times 64 db 0
snake_body_y times 64 db 0

; Еда
food_x db 0
food_y db 0

; Счет
snake_score dw 0

; Тексты
score_text db 'Score: ', 0
game_over_text db 'GAME OVER!', 0
final_score_text db 'Final: ', 0

snake_main.end:
    ret