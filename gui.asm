bits 16

gui_main:
    ; Переходим в графический режим 320x200, 256 цветов
    mov ax, 0x0013
    int 0x10
    
    ; Инициализируем мышь
    call init_mouse
    
    ; Рисуем интерфейс
    call draw_desktop
    call draw_taskbar
    call draw_icons
    call draw_clock
    
    ; Основной цикл GUI
.event_loop:
    ; Обновляем часы каждую секунду
    call update_clock_display
    
    ; Обрабатываем мышь
    call handle_mouse
    
    ; Проверяем клавиатуру
    mov ah, 0x01
    int 0x16
    jz .no_input
    
    mov ah, 0x00
    int 0x16
    cmp al, 27        ; ESC
    je .exit
    cmp al, '1'
    je .launch_calc
    cmp al, '2'
    je .launch_notepad
    cmp al, '3'
    je .launch_snake
    cmp al, '4'
    je .launch_clock
    cmp al, '5'
    je .launch_terminal
    
.no_input:
    ; Короткая задержка
    mov cx, 0x02FF
.delay:
    nop
    loop .delay
    
    jmp .event_loop

.launch_calc:
    call hide_mouse
    call restore_text_mode
    call calc_main
    call show_mouse
    jmp gui_main

.launch_notepad:
    call hide_mouse
    call restore_text_mode
    call notepad_main
    call show_mouse
    jmp gui_main

.launch_snake:
    call hide_mouse
    call restore_text_mode
    call snake_main
    call show_mouse
    jmp gui_main

.launch_clock:
    call hide_mouse
    call restore_text_mode
    call clock_main
    call show_mouse
    jmp gui_main

.launch_terminal:
    call hide_mouse
    call restore_text_mode
    ret

.exit:
    call hide_mouse
    call restore_text_mode
    ret

; Инициализация мыши
init_mouse:
    mov ax, 0x0000    ; Сброс мыши
    int 0x33
    cmp ax, 0xFFFF
    jne .no_mouse
    
    mov ax, 0x0001    ; Показать курсор
    int 0x33
    
    mov ax, 0x0004    ; Установить позицию
    mov cx, 160       ; X центр
    mov dx, 100       ; Y центр
    int 0x33
    
    mov ax, 0x000C    ; Установить обработчик
    mov cx, 0x0007    ; Левая кнопка + движение
    mov ax, cs
    mov es, ax
    mov dx, mouse_handler
    int 0x33
    
.no_mouse:
    ret

; Обработчик мыши
mouse_handler:
    pusha
    push es
    
    ; Сохраняем состояние мыши
    mov [mouse_x], cx
    mov [mouse_y], dx
    mov [mouse_buttons], bx
    
    ; Проверяем клик по иконкам
    test bx, 1        ; Левая кнопка
    jz .done
    
    call check_icon_click
    
.done:
    pop es
    popa
    retf

; Проверка клика по иконкам
check_icon_click:
    ; Иконка Calculator (50,30) - (66,46)
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    cmp ax, 50
    jb .next1
    cmp ax, 66
    ja .next1
    cmp bx, 30
    jb .next1
    cmp bx, 46
    ja .next1
    jmp .launch_calc

.next1:
    ; Иконка Notepad (150,30) - (166,46)
    cmp ax, 150
    jb .next2
    cmp ax, 166
    ja .next2
    cmp bx, 30
    jb .next2
    cmp bx, 46
    ja .next2
    jmp .launch_notepad

.next2:
    ; Иконка Snake (50,80) - (66,96)
    cmp ax, 50
    jb .next3
    cmp ax, 66
    ja .next3
    cmp bx, 80
    jb .next3
    cmp bx, 96
    ja .next3
    jmp .launch_snake

.next3:
    ; Иконка Clock (150,80) - (166,96)
    cmp ax, 150
    jb .next4
    cmp ax, 166
    ja .next4
    cmp bx, 80
    jb .next4
    cmp bx, 96
    ja .next4
    jmp .launch_clock

.next4:
    ; Кнопка Start (5,182) - (65,198)
    cmp ax, 5
    jb .done
    cmp ax, 65
    ja .done
    cmp bx, 182
    jb .done
    cmp bx, 198
    ja .done
    call show_start_menu

.done:
    ret

.launch_calc:
    call hide_mouse
    call restore_text_mode
    call calc_main
    call show_mouse
    jmp gui_main

.launch_notepad:
    call hide_mouse
    call restore_text_mode
    call notepad_main
    call show_mouse
    jmp gui_main

.launch_snake:
    call hide_mouse
    call restore_text_mode
    call snake_main
    call show_mouse
    jmp gui_main

.launch_clock:
    call hide_mouse
    call restore_text_mode
    call clock_main
    call show_mouse
    jmp gui_main

; Показать меню Start
show_start_menu:
    pusha
    mov ax, 0xA000
    mov es, ax
    
    ; Рисуем меню
    mov di, 140*320 + 5
    mov cx, 100
.menu_loop:
    push cx
    push di
    mov cx, 80
    mov al, 15
.menu_line:
    mov [es:di], al
    inc di
    loop .menu_line
    pop di
    add di, 320
    pop cx
    loop .menu_loop
    
    ; Текст меню
    mov si, start_menu_text1
    mov di, 145*320 + 10
    mov ah, 0
    call draw_text
    
    mov si, start_menu_text2
    mov di, 155*320 + 10
    mov ah, 0
    call draw_text
    
    mov si, start_menu_text3
    mov di, 165*320 + 10
    mov ah, 0
    call draw_text
    
    mov si, start_menu_text4
    mov di, 175*320 + 10
    mov ah, 0
    call draw_text
    
    mov si, start_menu_text5
    mov di, 185*320 + 10
    mov ah, 0
    call draw_text
    
    ; Ждём клик вне меню
.wait_click:
    mov ax, 0x0003
    int 0x33
    test bx, 1
    jnz .wait_click
    
    ; Перерисовываем панель задач
    call draw_taskbar
    call draw_clock
    
    popa
    ret

; Обработка мыши в основном цикле
handle_mouse:
    ret

; Показать курсор мыши
show_mouse:
    mov ax, 0x0001
    int 0x33
    ret

; Скрыть курсор мыши
hide_mouse:
    mov ax, 0x0002
    int 0x33
    ret

; Восстановление текстового режима
restore_text_mode:
    mov ax, 0x0003
    int 0x10
    ret

; Рисуем рабочий стол
draw_desktop:
    pusha
    mov ax, 0xA000
    mov es, ax
    xor di, di
    
    ; Синий градиентный фон
    mov cx, 200
.y_loop:
    push cx
    mov cx, 320
    mov al, 9          ; Синий цвет
    add al, cl         ; Градиент
    shr al, 2
.x_loop:
    stosb
    loop .x_loop
    pop cx
    loop .y_loop
    
    ; Логотип HDOS
    mov si, hdos_logo
    mov di, 50*320 + 140
    call draw_logo
    
    popa
    ret

; Рисуем панель задач
draw_taskbar:
    pusha
    mov ax, 0xA000
    mov es, ax
    
    ; Панель задач (серая полоса внизу)
    mov di, 180*320
    mov cx, 320*20
    mov al, 40         ; Серый цвет
    rep stosb
    
    ; Кнопка Start
    mov di, 182*320 + 5
    mov cx, 60
    mov al, 32         ; Темно-серый
.start_button:
    mov [es:di], al
    inc di
    loop .start_button
    
    ; Текст "Start"
    mov si, start_text
    mov di, 187*320 + 10
    mov ah, 15         ; Белый
    call draw_text
    
    ; Иконки приложений
    call draw_app_icons
    
    popa
    ret

; Рисуем иконки приложений на панели задач
draw_app_icons:
    ; Иконка калькулятора
    mov si, calc_icon
    mov di, 182*320 + 80
    call draw_icon
    
    ; Иконка блокнота
    mov si, notepad_icon
    mov di, 182*320 + 100
    call draw_icon
    
    ; Иконка змейки
    mov si, snake_icon
    mov di, 182*320 + 120
    call draw_icon
    
    ; Иконка часов
    mov si, clock_icon
    mov di, 182*320 + 140
    call draw_icon
    
    ret

; Рисуем иконку 16x16
; IN: SI = данные иконки, DI = позиция
draw_icon:
    pusha
    mov ax, 0xA000
    mov es, ax
    
    mov cx, 16
.y_loop:
    push cx
    push di
    mov cx, 16
.x_loop:
    lodsb
    test al, al
    jz .skip
    mov [es:di], al
.skip:
    inc di
    loop .x_loop
    pop di
    add di, 320
    pop cx
    loop .y_loop
    popa
    ret

; Рисуем иконки на рабочем столе
draw_icons:
    ; Иконка "Calculator"
    mov si, calc_desktop_icon
    mov di, 30*320 + 50
    call draw_desktop_icon
    
    ; Иконка "Notepad"
    mov si, notepad_desktop_icon
    mov di, 30*320 + 150
    call draw_desktop_icon
    
    ; Иконка "Snake"
    mov si, snake_desktop_icon
    mov di, 80*320 + 50
    call draw_desktop_icon
    
    ; Иконка "Clock"
    mov si, clock_desktop_icon
    mov di, 80*320 + 150
    call draw_desktop_icon
    
    ret

; Рисуем иконку на рабочем столе с текстом
; IN: SI = данные иконки, DI = позиция
draw_desktop_icon:
    pusha
    
    ; Рисуем иконку
    call draw_icon
    
    ; Рисуем текст под иконкой
    mov ax, di
    mov bx, 320
    xor dx, dx
    div bx
    add ax, 18         ; Строка под иконкой
    mul bx
    mov di, ax
    add di, [si + 256] ; Центрирование текста
    
    mov ah, 15         ; Белый цвет
    add si, 256        ; Переход к тексту
    call draw_text
    
    popa
    ret

; Рисуем текст в графическом режиме
; IN: SI = текст, DI = позиция, AH = цвет
draw_text:
    pusha
    mov ax, 0xA000
    mov es, ax
.text_loop:
    lodsb
    test al, al
    jz .done
    mov [es:di], al
    inc di
    jmp .text_loop
.done:
    popa
    ret

; Рисуем логотип HDOS
draw_logo:
    pusha
    mov ax, 0xA000
    mov es, ax
    
    mov si, hdos_logo
    mov cx, 30
.y_loop:
    push cx
    push di
    mov cx, 40
.x_loop:
    lodsb
    test al, al
    jz .skip
    mov [es:di], al
.skip:
    inc di
    loop .x_loop
    pop di
    add di, 320
    pop cx
    loop .y_loop
    popa
    ret

; Рисуем и обновляем часы
draw_clock:
    call update_clock_display
    ret

update_clock_display:
    pusha
    
    ; Получаем время
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    call bcd_to_ascii_gui
    mov [gui_time_buffer], ax
    
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    call bcd_to_ascii_gui
    mov [gui_time_buffer+3], ax
    
    mov byte [gui_time_buffer+2], ':'
    mov byte [gui_time_buffer+5], 0
    
    ; Рисуем время в правом углу
    mov si, gui_time_buffer
    mov di, 187*320 + 280
    mov ah, 15
    call draw_text
    
    popa
    ret

; BCD to ASCII для GUI
bcd_to_ascii_gui:
    mov ah, al
    and al, 0x0F
    add al, '0'
    shr ah, 4
    and ah, 0x0F
    add ah, '0'
    xchg ah, al
    ret

; Данные GUI
start_text db 'Start', 0

; Иконки для панели задач (16x16)
calc_icon:
    db 0,0,0,0,0,15,15,15,15,15,15,0,0,0,0,0
    db 0,0,0,15,15,15,15,15,15,15,15,15,15,0,0,0
    db 0,0,15,15,15,15,15,15,15,15,15,15,15,15,0,0
    db 0,15,15,15,1,1,1,1,1,1,1,1,15,15,15,0
    db 0,15,15,1,1,1,1,1,1,1,1,1,1,15,15,0
    db 15,15,1,1,15,15,15,15,15,15,15,15,1,1,15,15
    db 15,15,1,1,15,15,15,15,15,15,15,15,1,1,15,15
    db 15,15,1,1,15,15,15,15,15,15,15,15,1,1,15,15
    db 15,15,1,1,15,15,15,15,15,15,15,15,1,1,15,15
    db 15,15,1,1,15,15,15,15,15,15,15,15,1,1,15,15
    db 15,15,1,1,15,15,15,15,15,15,15,15,1,1,15,15
    db 15,15,1,1,1,1,1,1,1,1,1,1,1,1,15,15
    db 15,15,1,1,1,1,1,1,1,1,1,1,1,1,15,15
    db 0,15,15,15,15,15,15,15,15,15,15,15,15,15,15,0
    db 0,0,15,15,15,15,15,15,15,15,15,15,15,15,0,0
    db 0,0,0,0,15,15,15,15,15,15,15,15,0,0,0,0

notepad_icon:
    db 0,0,15,15,15,15,15,15,15,15,15,15,15,15,0,0
    db 0,15,2,2,2,2,2,2,2,2,2,2,2,2,15,0
    db 15,2,2,2,2,2,2,2,2,2,2,2,2,2,2,15
    db 15,2,15,15,15,15,15,15,15,15,15,15,15,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,1,1,1,1,1,1,1,1,1,1,15,2,15
    db 15,2,15,15,15,15,15,15,15,15,15,15,15,15,2,15
    db 15,2,2,2,2,2,2,2,2,2,2,2,2,2,2,15
    db 0,15,15,15,15,15,15,15,15,15,15,15,15,15,15,0
    db 0,0,15,15,15,15,15,15,15,15,15,15,15,15,0,0

snake_icon:
    db 0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0
    db 0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0
    db 0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0
    db 0,2,2,2,10,10,10,10,10,10,10,10,2,2,2,0
    db 0,2,2,10,10,10,10,10,10,10,10,10,10,2,2,0
    db 2,2,10,10,2,2,2,2,2,2,2,2,10,10,2,2
    db 2,2,10,10,2,2,2,2,2,2,2,2,10,10,2,2
    db 2,2,10,10,2,2,2,2,2,2,2,2,10,10,2,2
    db 2,2,10,10,2,2,2,2,2,2,2,2,10,10,2,2
    db 2,2,10,10,2,2,2,2,2,2,2,2,10,10,2,2
    db 2,2,10,10,2,2,2,2,2,2,2,2,10,10,2,2
    db 2,2,10,10,10,10,10,10,10,10,10,10,10,10,2,2
    db 2,2,10,10,10,10,10,10,10,10,10,10,10,10,2,2
    db 0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0
    db 0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0
    db 0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,0

clock_icon:
    db 0,0,0,14,14,14,14,14,14,14,14,14,14,0,0,0
    db 0,0,14,14,14,14,14,14,14,14,14,14,14,14,0,0
    db 0,14,14,14,14,14,14,14,14,14,14,14,14,14,14,0
    db 14,14,14,14,1,1,1,1,1,1,1,1,14,14,14,14
    db 14,14,14,1,1,1,1,1,1,1,1,1,1,14,14,14
    db 14,14,14,1,1,14,14,14,14,14,14,1,1,14,14,14
    db 14,14,14,1,1,14,14,14,14,14,14,1,1,14,14,14
    db 14,14,14,1,1,14,14,14,14,14,14,1,1,14,14,14
    db 14,14,14,1,1,14,14,14,14,14,14,1,1,14,14,14
    db 14,14,14,1,1,14,14,14,14,14,14,1,1,14,14,14
    db 14,14,14,1,1,14,14,14,14,14,14,1,1,14,14,14
    db 14,14,14,1,1,1,1,1,1,1,1,1,1,14,14,14
    db 14,14,14,14,1,1,1,1,1,1,1,1,14,14,14,14
    db 0,14,14,14,14,14,14,14,14,14,14,14,14,14,14,0
    db 0,0,14,14,14,14,14,14,14,14,14,14,14,14,0,0
    db 0,0,0,0,14,14,14,14,14,14,14,14,0,0,0,0

; Иконки для рабочего стола с текстом
calc_desktop_icon:
    times 256 db 15  ; Простая белая иконка
    db 'Calculator', 0
    times 246 db 0   ; Выравнивание

notepad_desktop_icon:
    times 256 db 15
    db 'Notepad', 0
    times 249 db 0

snake_desktop_icon:
    times 256 db 15
    db 'Snake', 0
    times 251 db 0

clock_desktop_icon:
    times 256 db 15
    db 'Clock', 0
    times 251 db 0

; Логотип HDOS (40x30)
hdos_logo:
    times 1200 db 15  ; Простой белый прямоугольник

; Буфер времени
gui_time_buffer db '00:00', 0

; Данные мыши
mouse_x dw 160
mouse_y dw 100
mouse_buttons dw 0

; Текст меню Start
start_menu_text1 db 'Calculator', 0
start_menu_text2 db 'Notepad', 0
start_menu_text3 db 'Snake Game', 0
start_menu_text4 db 'Clock', 0
start_menu_text5 db 'Terminal', 0