bits 16
org 0x7E00

kernel_start:
    mov ax, 0x0003
    int 0x10
    call init_system
    call init_interrupts
    jmp shell_start

init_system:
    mov ax, 0xB800
    mov es, ax
    mov di, 0
    mov cx, 2000
    mov ax, 0x1F20
    rep stosw
    ret

%include "int.asm"
%include "comm.asm"
%include "sh.asm"
%include "101clock.asm"
%include "calc.asm"
%include "snake.asm"
%include "notepad.asm"
%include "err.asm"

kernel_end:
