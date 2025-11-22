bits 16

command_handler:
    pusha
    mov si, bx
    add si, 2
    
    mov di, cmd_help
    call strcmp
    jc .execute_help
    
    mov di, cmd_clock
    call strcmp
    jc .execute_clock
    
    mov di, cmd_snake
    call strcmp
    jc .execute_snake
    
    mov di, cmd_calc
    call strcmp
    jc .execute_calc
    
    mov di, cmd_reboot
    call strcmp
    jc .execute_reboot
    
    mov di, cmd_time
    call strcmp
    jc .execute_time
    
    mov di, cmd_clear
    call strcmp
    jc .execute_clear
    
    mov di, cmd_info
    call strcmp
    jc .execute_info
    
    mov di, cmd_ver
    call strcmp
    jc .execute_ver
    
    mov di, cmd_mem
    call strcmp
    jc .execute_mem
    
    mov di, cmd_date
    call strcmp
    jc .execute_date
    
    mov di, cmd_notepad
    call strcmp
    jc .execute_notepad
    
    mov di, cmd_gui
    call strcmp
    jc .execute_gui
    
    mov di, cmd_format
    call strcmp
    jc .execute_format
    
    mov di, cmd_ls
    call strcmp
    jc .execute_ls
    
    mov di, cmd_load
    call strcmp
    jc .execute_load
    
    mov di, cmd_save
    call strcmp
    jc .execute_save
    
    mov di, cmd_del
    call strcmp
    jc .execute_del
    
    ; Неизвестная команда
    mov si, unknown_cmd_msg
    call comm_print_string
    jmp .done

.execute_help:
    mov si, help_text
    call comm_print_string
    jmp .done

.execute_clock:
    call clock_main
    jmp .done

.execute_snake:
    call snake_main
    jmp .done

.execute_calc:
    call calc_main
    jmp .done

.execute_reboot:
    mov ax, 0x0040
    mov ds, ax
    mov word [0x0072], 0x1234
    jmp 0xFFFF:0x0000

.execute_time:
    call display_time
    jmp .done

.execute_clear:
    call clear_screen
    jmp .done

.execute_info:
    mov si, info_text
    call comm_print_string
    jmp .done

.execute_ver:
    mov si, version_text
    call comm_print_string
    jmp .done

.execute_mem:
    call show_memory
    jmp .done

.execute_date:
    call display_date
    jmp .done

.execute_notepad:
    call notepad_main
    jmp .done

.execute_gui:
    ; ВРЕМЕННО ОТКЛЮЧЕНО - GUI В РАЗРАБОТКЕ
    mov si, gui_develop_msg
    call comm_print_string
    jmp .done

.execute_format:
    ; ВРЕМЕННО ОТКЛЮЧЕНО - ФС В РАЗРАБОТКЕ
    mov si, fs_develop_msg
    call comm_print_string
    jmp .done

.execute_ls:
    ; ВРЕМЕННО ОТКЛЮЧЕНО - ФС В РАЗРАБОТКЕ
    mov si, fs_develop_msg
    call comm_print_string
    jmp .done

.execute_load:
    ; ВРЕМЕННО ОТКЛЮЧЕНО - ФС В РАЗРАБОТКЕ
    mov si, fs_develop_msg
    call comm_print_string
    jmp .done

.execute_save:
    ; ВРЕМЕННО ОТКЛЮЧЕНО - ФС В РАЗРАБОТКЕ
    mov si, fs_develop_msg
    call comm_print_string
    jmp .done

.execute_del:
    ; ВРЕМЕННО ОТКЛЮЧЕНО - ФС В РАЗРАБОТКЕ
    mov si, fs_develop_msg
    call comm_print_string
    jmp .done

.done:
    popa
    ret

; Вспомогательные функции
strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc si
    inc di
    jmp .loop
.equal:
    stc
    jmp .exit
.not_equal:
    clc
.exit:
    pop di
    pop si
    ret

clear_screen:
    pusha
    mov ax, 0xB800
    mov es, ax
    mov di, 0
    mov cx, 2000
    mov ax, 0x1F20
    rep stosw
    mov byte [cursor_pos], 0
    popa
    ret

display_time:
    pusha
    mov al, 0x04
    out 0x70, al
    in al, 0x71
    call comm_bcd_to_ascii
    mov [comm_time_display], ax
    
    mov al, 0x02
    out 0x70, al
    in al, 0x71
    call comm_bcd_to_ascii
    mov [comm_time_display+3], ax
    
    mov byte [comm_time_display+2], ':'
    mov si, comm_time_display
    call comm_print_string
    mov si, comm_newline
    call comm_print_string
    popa
    ret

display_date:
    pusha
    mov al, 0x07
    out 0x70, al
    in al, 0x71
    call comm_bcd_to_ascii
    mov [comm_date_display], ax
    
    mov al, 0x08
    out 0x70, al
    in al, 0x71
    call comm_bcd_to_ascii
    mov [comm_date_display+3], ax
    
    mov al, 0x09
    out 0x70, al
    in al, 0x71
    call comm_bcd_to_ascii
    mov [comm_date_display+6], ax
    
    mov byte [comm_date_display+2], '/'
    mov byte [comm_date_display+5], '/'
    mov si, comm_date_display
    call comm_print_string
    mov si, comm_newline
    call comm_print_string
    popa
    ret

show_memory:
    pusha
    mov si, mem_text
    call comm_print_string
    
    int 0x12
    mov dx, ax
    call comm_print_hex_word
    mov si, mem_kb_text
    call comm_print_string
    popa
    ret

comm_bcd_to_ascii:
    mov ah, al
    and al, 0x0F
    add al, '0'
    shr ah, 4
    and ah, 0x0F
    add ah, '0'
    xchg ah, al
    ret

comm_print_hex_word:
    push ax
    mov al, dh
    shr al, 4
    call comm_print_hex_digit
    mov al, dh
    and al, 0x0F
    call comm_print_hex_digit
    mov al, dl
    shr al, 4
    call comm_print_hex_digit
    mov al, dl
    and al, 0x0F
    call comm_print_hex_digit
    pop ax
    ret

comm_print_hex_digit:
    cmp al, 10
    jb .digit
    add al, 7
.digit:
    add al, '0'
    mov ah, 0x0E
    int 0x10
    ret

comm_print_string:
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

; Заглушки для файловой системы
hfs_file_table times 1024 db 0

; Команды
cmd_help db "help", 0
cmd_clock db "clock", 0
cmd_snake db "snake", 0
cmd_calc db "calc", 0
cmd_reboot db "reboot", 0
cmd_time db "time", 0
cmd_clear db "clear", 0
cmd_info db "info", 0
cmd_ver db "ver", 0
cmd_mem db "mem", 0
cmd_date db "date", 0
cmd_notepad db "notepad", 0
cmd_gui db "gui", 0
cmd_format db "format", 0
cmd_ls db "ls", 0
cmd_load db "load", 0
cmd_save db "save", 0
cmd_del db "del", 0

; Сообщения
unknown_cmd_msg db "Unknown command. Type //help for list", 0x0D, 0x0A, 0
help_text db "Available commands:", 0x0D, 0x0A
          db "//help     //clock    //snake    //calc", 0x0D, 0x0A
          db "//reboot   //time     //clear    //info", 0x0D, 0x0A
          db "//ver      //mem      //date     //notepad", 0x0D, 0x0A
          db "//gui      //format   //ls       //load", 0x0D, 0x0A
          db "//save     //del", 0x0D, 0x0A, 0
info_text db "HDOS v2.0 - Winora Company", 0x0D, 0x0A
          db "Modular OS with GUI and HFS filesystem", 0x0D, 0x0A, 0
version_text db "HDOS Version 2.0 (Build 2024)", 0x0D, 0x0A, 0

gui_develop_msg db "GUI: In development for HDOS v3.0", 0x0D, 0x0A, 0
fs_develop_msg db "File system: In development for HDOS v3.0", 0x0D, 0x0A, 0

comm_time_display db '00:00', 0x0D, 0x0A, 0
comm_date_display db '00/00/00', 0
mem_text db 'Base memory: ', 0
mem_kb_text db ' KB', 0x0D, 0x0A, 0
comm_newline db 0x0D, 0x0A, 0
cursor_pos db 0