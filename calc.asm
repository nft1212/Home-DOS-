bits 16

calc_main:
    mov ax, 0x0003
    int 0x10
    
    mov si, calc_header
    call calc_print_string
    
.calc_loop:
    mov si, calc_prompt
    call calc_print_string
    
    ; Читаем выражение
    mov di, calc_buffer
    mov cx, 0
.input_loop:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x0D        ; Enter
    je .calculate
    cmp al, 0x08        ; Backspace
    je .backspace
    cmp al, 27          ; ESC
    je .exit
    
    ; Проверяем допустимые символы
    cmp al, '0'
    jb .input_loop
    cmp al, '9'
    jbe .valid_char
    cmp al, '+'
    je .valid_char
    cmp al, '-'
    je .valid_char
    cmp al, '*'
    je .valid_char
    cmp al, '/'
    je .valid_char
    jmp .input_loop

.valid_char:
    cmp cx, 30
    jge .input_loop
    
    mov [di], al
    inc di
    inc cx
    
    mov ah, 0x0E
    int 0x10
    jmp .input_loop

.backspace:
    test cx, cx
    jz .input_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .input_loop

.calculate:
    mov byte [di], 0
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    
    ; Вычисляем выражение
    mov si, calc_buffer
    call evaluate_expression
    
    ; Выводим результат
    mov si, calc_result
    call calc_print_string
    mov ax, [calc_value]
    call calc_print_number
    mov si, calc_newline
    call calc_print_string
    
    jmp .calc_loop

.exit:
    ret

; Вычисление выражения a+b, a-b, a*b, a/b
; IN: SI = строка выражения
evaluate_expression:
    mov word [calc_value], 0
    mov word [calc_error], 0
    
    ; Парсим первое число
    call parse_number
    cmp word [calc_error], 0
    jne .error
    mov ax, [num1]
    mov [calc_value], ax
    
    ; Пропускаем пробелы
    call skip_spaces
    cmp byte [si], 0
    je .done
    
    ; Получаем оператор
    mov al, [si]
    mov [operator], al
    inc si
    
    ; Парсим второе число
    call parse_number
    cmp word [calc_error], 0
    jne .error
    
    ; Выполняем операцию
    mov ax, [calc_value]
    mov bx, [num1]
    
    cmp byte [operator], '+'
    je .do_add
    cmp byte [operator], '-'
    je .do_sub
    cmp byte [operator], '*'
    je .do_mul
    cmp byte [operator], '/'
    je .do_div
    
    jmp .error

.do_add:
    add ax, bx
    jmp .store_result

.do_sub:
    sub ax, bx
    jmp .store_result

.do_mul:
    imul bx
    jmp .store_result

.do_div:
    test bx, bx
    jz .div_zero
    xor dx, dx
    div bx
    jmp .store_result

.div_zero:
    mov word [calc_error], 2
    jmp .error

.store_result:
    mov [calc_value], ax
    jmp .done

.error:
    mov word [calc_error], 1

.done:
    ret

; Парсинг числа
; OUT: num1 = число
parse_number:
    mov word [num1], 0
    
    ; Пропускаем пробелы
    call skip_spaces
    
    ; Парсим цифры
.number_loop:
    mov al, [si]
    cmp al, '0'
    jb .done
    cmp al, '9'
    ja .done
    
    ; Конвертируем цифру
    sub al, '0'
    mov bx, [num1]
    imul bx, 10
    add bx, ax
    mov [num1], bx
    
    inc si
    jmp .number_loop

.done:
    ret

; Пропуск пробелов
skip_spaces:
    cmp byte [si], ' '
    jne .done
    inc si
    jmp skip_spaces
.done:
    ret

; Печать числа
calc_print_number:
    push ax
    push bx
    push cx
    push dx
    
    mov ax, [calc_value]
    
    ; Проверка на ошибку
    cmp word [calc_error], 0
    jne .show_error
    
    ; Проверка на отрицательное
    test ax, ax
    jns .positive
    
    ; Отрицательное число
    push ax
    mov al, '-'
    mov ah, 0x0E
    int 0x10
    pop ax
    neg ax

.positive:
    mov bx, 10
    xor cx, cx
    
    ; Особый случай: 0
    test ax, ax
    jnz .divide
    mov al, '0'
    mov ah, 0x0E
    int 0x10
    jmp .done

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
    mov ah, 0x0E
    int 0x10
    loop .print
    jmp .done

.show_error:
    cmp word [calc_error], 2
    je .div_error
    mov si, calc_error_msg
    call calc_print_string
    jmp .done

.div_error:
    mov si, calc_div_error_msg
    call calc_print_string

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Печать строки
calc_print_string:
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

; Данные
calc_header db 'HDOS Calculator (+, -, *, /)', 0x0D, 0x0A, 0
calc_prompt db '> ', 0
calc_result db '= ', 0
calc_error_msg db 'Error', 0
calc_div_error_msg db 'Div/0', 0
calc_newline db 0x0D, 0x0A, 0

calc_buffer times 32 db 0
calc_value dw 0
num1 dw 0
operator db 0
calc_error dw 0