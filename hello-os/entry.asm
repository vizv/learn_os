; Viz @ 2021.05.15
; Credits: https://github.com/tanmayv25/x86-bootloader, http://3zanders.co.uk/2017/10/13/writing-a-bootloader

; 入口部分 .entry
; 组成了 MBR，用于配置硬件和加载 MBR 外的内核加载器和内核到内存
[section .entry]
[bits 16]
[global entry]
entry:
        ; 打开 A20 总线
        ; 参考 https://wiki.osdev.org/A20_Line#INT_15
	mov ax, 0x2401
	int 0x15

        ; 调用系统中断 0x10，设置 80x25 字符显示模式（ah=0x0, al=0x3）
        ; 参考 (Table 0009) http://muruganad.com/8086/interrupt%20list/int%2010%20video%20interrupt/Int-10-AH-00-Set-Video-Mode.html
	mov ax, 0x3
	int 0x10

        ; BIOS 将该引导代码所在的磁盘号保存在了 DL 寄存器（如果只有一个磁盘一般是 0）
        ; 参考 https://wiki.osdev.org/Boot_Sequence#Early_Environment
	mov [disk], dl

        ; 调用系统中断 0x13，以 CHS 模式读取磁盘
        ; 参考 https://wiki.osdev.org/ATA_in_x86_RealMode_(BIOS)
	mov ah, 0x2         ; 设置以 CHS 模式读取磁盘扇区
	mov al, 6           ; 要读取的扇区总数
	mov ch, 0           ; 柱面号
	mov dh, 0           ; 磁头号
	mov cl, 2           ; 扇区号
	mov dl, [disk]      ; 磁盘号
	mov bx, copy_target ; 目标指针，因为 BIOS 只加载了磁盘 MBR（前 512 个字节）
	int 0x13

        ; 关闭中断
	cli

        ; 重载 GDT 并进入保护模式
        ; https://wiki.osdev.org/Protected_mode
	lgdt [gdt_pointer]
	mov eax, cr0
	or eax, 0x1
	mov cr0, eax

        ; 设置数据段
	mov ax, DATA_SEG
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

        ; 跳转到 MBR 后面位于代码段的内核加载器
	jmp CODE_SEG:loader

; GDT（Global Descriptor Table，全局描述符表）配置部分
; https://wiki.osdev.org/GDT

; GDT 指针
gdt_pointer:
	dw gdt_end - gdt_start ; GDT 大小
	dd gdt_start           ; GDT 偏移

; GDT 条目（共两条，一条配置可执行的代码段，另一条配置不可执行的数据段）
gdt_start:
	dq 0x0 ; GDT 条目以一个空的条目开始
; 代码段条目（从 gdt_code 开始到 gdt_end 结束）
gdt_code:
	dw 0xFFFF    ; [00:15] - 段长度界限[00:15] = 0xFFFF（4GiB）
	dw 0x0       ; [16:31] -   段基地址[00:15] = 0x0000
	db 0x0       ; [32:39] -   段基地址[16:23] = 0x00
	db 10011010b ; [40:47] - 存取权限字节：
                               ;   存在位[7] = 1（1 才有效）
                               ; 段特权[5:6] = 0（Ring 0 / 内核）
                               ;   段类型[4] = 1（代码段或数据段使用 1，系统段使用 0）
                               ;   可执行[3] = 1（可执行如代码段）
                               ;   段方向[2] = 0
                               ;   可读写[1] = 1（1 则允许写入，否则只读）
                               ;   正访问[0] = 0（这里设置为 0，CPU 访问时被设置成 1）
	db 11001111b ; [48:51] - 段长度界限[16:19] = 0xF（1111b）
                     ; [52:53] - 填充，总是 0
                     ;    [54] - 位宽位 = 1（1 为 32 位，否则为 16 位）
                     ;    [55] - 粒度位 = 1（1 为 4 KiB 的分页，否则为一个字节）
	db 0x0       ; [56-63] -   段基地址[24:31] = 0x00
; 数据段条目
gdt_data:
	dw 0xFFFF    ; [00:15] - 段长度界限[00:15] = 0xFFFF（4GiB）
	dw 0x0       ; [16:31] -   段基地址[00:15] = 0x0000
	db 0x0       ; [32:39] -   段基地址[16:23] = 0x00
	db 10010010b ; [40:47] - 存取权限字节：
                               ;   存在位[7] = 1（1 才有效）
                               ; 段特权[5:6] = 0（Ring 0 / 内核）
                               ;   段类型[4] = 1（代码段或数据段使用 1，系统段使用 0）
                               ;   可执行[3] = 0（不可执行如数据段）
                               ;   段方向[2] = 0
                               ;   可读写[1] = 1（1 则允许写入，否则只读）
                               ;   正访问[0] = 0（这里设置为 0，CPU 访问时被设置成 1）
	db 11001111b ; [48:51] - 段长度界限[16:19] = 0xF（1111b）
                     ; [52:53] - 填充，总是 0
                     ;    [54] - 位宽位 = 1（1 为 32 位，否则为 16 位）
                     ;    [55] - 粒度位 = 1（1 为 4 KiB 的分页，否则为一个字节）
	db 0x0       ; [56-63] -   段基地址[24:31] = 0x00
gdt_end:

; 代码段和数据段的偏移量
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; 磁盘号变量，将从 DL 设置
disk:
	db 0x0

; 填充到 512 个字节然后加上 0xaa55 作为有效的 MBR
times 510 - ($-$$) db 0
dw 0xaa55

; 内核加载器部分 .loader
; 这部分由入口部分加载到 copy_target: 的位置
[bits 32]
copy_target:

; 加载器逻辑
loader:
        ; 初始化内核需要的栈
	mov esp, kernel_stack_top

        ; 调用外部的内核 main 函数，由 ld 负责链接
	extern main
	call main

        ; 内核的 main 函数退出后关闭中断并停止 CPU
	cli
	hlt

; 栈部分预留 16 KiB = 16384
[section .bss]
align 4
kernel_stack_bottom: equ $
	resb 16384
kernel_stack_top:
