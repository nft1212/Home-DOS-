bits 16

; Заглушки для нереализованных функций
notepad_main:
gui_main:
hfs_format:
hfs_list_files:
hfs_read_file:
    ret

; Глобальные переменные-заглушки
hfs_file_table times 1024 db 0

; Метки для ошибок
snake_main.end:
kernel_panic.panic_loop:
manual_panic.panic_loop:
    jmp $