bits 16

; HDOS File System (HFS)
; Простая ФС для HDOS

; Структура суперблока
struc HFS_SUPERBLOCK
    .signature        resb 8    ; "HFSv1.0"
    .bytes_per_sector resw 1
    .sectors_per_cluster resb 1
    .total_files      resw 1
    .total_sectors    resd 1
    .free_sectors     resd 1
    .root_dir_sector  resw 1
    .reserved         resb 490
endstruc

; Структура записи файла
struc HFS_FILE_ENTRY
    .filename        resb 11    ; 8.3 формат
    .attributes      resb 1     ; 0x01=исполняемый, 0x02=системный
    .start_sector    resw 1     ; Стартовый сектор
    .file_size       resd 1     ; Размер в байтах
    .reserved        resb 16
endstruc

; Глобальные переменные
hfs_superblock times 512 db 0
hfs_file_table times 1024 db 0  ; 32 файла по 32 байта
current_dir_sector dw 2

; Инициализация HFS
hfs_init:
    pusha
    ; Пытаемся загрузить суперблок
    mov eax, 1                  ; Сектор 1
    mov cx, 1
    mov bx, hfs_superblock
    mov es, bx
    xor bx, bx
    call read_sectors
    jc .format_disk             ; Если ошибка - форматируем
    
    ; Проверяем сигнатуру
    mov si, hfs_superblock
    mov di, hfs_signature
    mov cx, 8
    rep cmpsb
    jne .format_disk
    
    ; Загружаем таблицу файлов
    mov eax, 2                  ; Сектор 2
    mov cx, 2                   ; 2 сектора
    mov bx, hfs_file_table
    mov es, bx
    xor bx, bx
    call read_sectors
    
    popa
    ret

.format_disk:
    call hfs_format
    popa
    ret

; Форматирование дискеты под HFS
hfs_format:
    pusha
    
    ; Инициализируем суперблок
    mov di, hfs_superblock
    mov si, hfs_signature
    mov cx, 8
    rep movsb
    
    mov word [di], 512          ; bytes_per_sector
    mov byte [di+2], 1          ; sectors_per_cluster
    mov word [di+3], 32         ; total_files
    mov dword [di+5], 2878      ; total_sectors (2880 - 2)
    mov dword [di+9], 2878      ; free_sectors
    mov word [di+13], 2         ; root_dir_sector
    
    ; Записываем суперблок
    mov eax, 1
    mov cx, 1
    mov bx, hfs_superblock
    mov es, bx
    xor bx, bx
    call write_sectors
    
    ; Очищаем таблицу файлов
    mov di, hfs_file_table
    mov cx, 1024
    mov al, 0
    rep stosb
    
    ; Записываем пустую таблицу файлов
    mov eax, 2
    mov cx, 2
    mov bx, hfs_file_table
    mov es, bx
    xor bx, bx
    call write_sectors
    
    popa
    ret

; Поиск файла по имени
; IN: DS:SI = имя файла (11 символов)
; OUT: AX = индекс файла, CF=1 если не найден
hfs_find_file:
    push bx
    push cx
    push di
    push es
    
    mov ax, ds
    mov es, ax
    mov di, hfs_file_table
    mov cx, 32                  ; Максимум 32 файла
    
.search_loop:
    push si
    push di
    push cx
    mov cx, 11
    rep cmpsb
    pop cx
    pop di
    pop si
    je .found
    
    add di, 32                  ; Следующая запись
    loop .search_loop
    
    ; Файл не найден
    stc
    jmp .exit

.found:
    mov ax, 32
    sub ax, cx                  ; AX = индекс файла
    clc

.exit:
    pop es
    pop di
    pop cx
    pop bx
    ret

; Создание файла
; IN: DS:SI = имя файла, CX = размер
; OUT: CF=1 при ошибке
hfs_create_file:
    pusha
    
    ; Ищем свободную запись
    mov di, hfs_file_table
    mov cx, 32
    
.find_free:
    cmp byte [di], 0
    je .found_free
    add di, 32
    loop .find_free
    stc                         ; Нет свободных записей
    jmp .exit

.found_free:
    ; Копируем имя файла
    push di
    mov cx, 11
    rep movsb
    pop di
    
    ; Устанавливаем атрибуты
    mov byte [di + 11], 0x01    ; Исполняемый по умолчанию
    
    ; Находим свободный сектор
    call hfs_find_free_sector
    jc .exit
    
    mov [di + 12], ax           ; start_sector
    mov [di + 14], ecx          ; file_size
    
    ; Обновляем таблицу файлов на диске
    mov eax, 2
    mov cx, 2
    mov bx, hfs_file_table
    mov es, bx
    xor bx, bx
    call write_sectors
    
    clc

.exit:
    popa
    ret

; Поиск свободного сектора
; OUT: AX = номер сектора, CF=1 если нет места
hfs_find_free_sector:
    push cx
    push di
    
    mov di, hfs_file_table
    mov cx, 32
    mov ax, 4                   ; Начинаем с сектора 4
    
.check_sector:
    push ax
    push di
    push cx
    
    ; Проверяем занят ли сектор
    mov cx, 32
.check_loop:
    cmp word [di + 12], ax      ; start_sector
    je .sector_used
    add di, 32
    loop .check_loop
    
    ; Сектор свободен
    pop cx
    pop di
    pop ax
    clc
    jmp .exit

.sector_used:
    pop cx
    pop di
    pop ax
    inc ax
    cmp ax, 2880
    jae .no_space
    loop .check_sector

.no_space:
    stc

.exit:
    pop di
    pop cx
    ret

; Чтение файла
; IN: DS:SI = имя файла, ES:BX = буфер
; OUT: CF=1 при ошибке
hfs_read_file:
    pusha
    
    call hfs_find_file
    jc .error
    
    ; Получаем информацию о файле
    mov di, hfs_file_table
    mov cx, 32
    mul cx
    add di, ax
    
    mov ax, [di + 12]           ; start_sector
    mov ecx, [di + 14]          ; file_size
    
    ; Вычисляем количество секторов
    mov dx, 0
    mov bx, 512
    div bx
    test dx, dx
    jz .exact
    inc ax                      ; Округляем вверх
.exact:
    mov cx, ax
    
    ; Читаем секторы
    mov eax, [di + 12]
    call read_sectors
    jc .error
    
    clc
    jmp .exit

.error:
    stc

.exit:
    popa
    ret

; Запись файла
; IN: DS:SI = имя файла, ES:BX = данные, ECX = размер
; OUT: CF=1 при ошибке
hfs_write_file:
    pusha
    
    ; Проверяем существует ли файл
    call hfs_find_file
    jnc .file_exists
    
    ; Создаем новый файл
    call hfs_create_file
    jc .error

.file_exists:
    ; Находим запись файла
    call hfs_find_file
    mov di, hfs_file_table
    mov dx, 32
    mul dx
    add di, ax
    
    ; Обновляем размер
    mov [di + 14], ecx
    
    ; Записываем данные
    mov eax, [di + 12]          ; start_sector
    
    ; Вычисляем количество секторов
    mov edx, ecx
    add edx, 511
    shr edx, 9                  ; Делим на 512
    
    mov cx, dx
    call write_sectors
    jc .error
    
    ; Обновляем таблицу файлов
    mov eax, 2
    mov cx, 2
    mov bx, hfs_file_table
    mov es, bx
    xor bx, bx
    call write_sectors
    
    clc
    jmp .exit

.error:
    stc

.exit:
    popa
    ret

; Список файлов
; OUT: SI = список файлов
hfs_list_files:
    mov si, hfs_file_table
    ret

; Удаление файла
; IN: DS:SI = имя файла
hfs_delete_file:
    pusha
    
    call hfs_find_file
    jc .exit
    
    ; Очищаем запись
    mov di, hfs_file_table
    mov cx, 32
    mul cx
    add di, ax
    
    mov cx, 32
    mov al, 0
    rep stosb
    
    ; Обновляем таблицу на диске
    mov eax, 2
    mov cx, 2
    mov bx, hfs_file_table
    mov es, bx
    xor bx, bx
    call write_sectors

.exit:
    popa
    ret

; Вспомогательные функции
read_sectors:
    ; EAX = LBA сектор, CX = количество, ES:BX = буфер
    pusha
    mov [.lba], eax
    mov [.count], cx
    mov [.buffer], bx
    mov [.segment], es

.read_loop:
    mov eax, [.lba]
    call lba_to_chs
    
    mov ah, 0x02
    mov al, 1
    mov ch, [.cylinder]
    mov cl, [.sector]
    mov dh, [.head]
    mov dl, 0x80
    mov bx, [.buffer]
    mov es, [.segment]
    int 0x13
    jc .error
    
    inc dword [.lba]
    add word [.buffer], 512
    dec word [.count]
    jnz .read_loop
    
    popa
    ret

.error:
    popa
    stc
    ret

.lba dd 0
.count dw 0
.buffer dw 0
.segment dw 0

write_sectors:
    ; EAX = LBA сектор, CX = количество, ES:BX = буфер
    pusha
    mov [.lba], eax
    mov [.count], cx
    mov [.buffer], bx
    mov [.segment], es

.write_loop:
    mov eax, [.lba]
    call lba_to_chs
    
    mov ah, 0x03
    mov al, 1
    mov ch, [.cylinder]
    mov cl, [.sector]
    mov dh, [.head]
    mov dl, 0x80
    mov bx, [.buffer]
    mov es, [.segment]
    int 0x13
    jc .error
    
    inc dword [.lba]
    add word [.buffer], 512
    dec word [.count]
    jnz .write_loop
    
    popa
    ret

.error:
    popa
    stc
    ret

.lba dd 0
.count dw 0
.buffer dw 0
.segment dw 0

lba_to_chs:
    ; EAX = LBA -> CHS
    xor dx, dx
    div word [sectors_per_track]
    inc dl
    mov [.sector], dl
    
    xor dx, dx
    div word [heads_per_cylinder]
    mov [.head], dl
    mov [.cylinder], al
    ret

.sector db 0
.head db 0
.cylinder db 0

; Данные
hfs_signature db 'HFSv1.0', 0
sectors_per_track dw 18
heads_per_cylinder dw 2

; Команды для comm.asm
; //format - форматирование
; //ls - список файлов  
; //load <file> - загрузка
; //save <file> - сохранение
; //del <file> - удаление

read_sectors.cylinder db 0
read_sectors.sector db 0  
read_sectors.head db 0
write_sectors.cylinder db 0
write_sectors.sector db 0
write_sectors.head db 0