bits 16

shell_start:
    mov ax, 0x0003
    int 0x10
    
    mov si, welcome_msg
    call shell_print_string

shell_loop:
    mov si, prompt
    call shell_print_string
    
    mov di, input_buffer
    mov cx, 0
.read_loop:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x0D
    je .execute
    cmp al, 0x08
    je .backspace
    
    cmp cx, 62
    jge .read_loop
    
    mov [di], al
    inc di
    inc cx
    
    mov ah, 0x0E
    int 0x10
    jmp .read_loop

.backspace:
    test cx, cx
    jz .read_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop

.execute:
    mov byte [di], 0
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    
    mov si, input_buffer
    cmp word [si], '//'
    jne .invalid_cmd
    
    mov bx, si
    call command_handler
    jmp shell_loop

.invalid_cmd:
    mov si, invalid_msg
    call shell_print_string
    jmp shell_loop

shell_print_string:
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

welcome_msg db 'HDOS Shell v1.0', 0x0D, 0x0A, 'Type //help', 0x0D, 0x0A, 0
prompt db 'HDOS> ', 0
invalid_msg db 'Error: Use //command', 0x0D, 0x0A, 0
input_buffer times 64 db 0