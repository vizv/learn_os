/* Viz @ 2021.05.15 */
/* Credits: https://github.com/tanmayv25/x86-bootloader, http://3zanders.co.uk/2017/10/13/writing-a-bootloader */

ENTRY(entry)
OUTPUT_FORMAT("binary")
SECTIONS {
    /* MBR 被 BIOS 加载到 0x7c00 */
    /* 参考 https://wiki.osdev.org/MBR_(x86) */
    . = 0x7c00;
    .text :
    {
        *(.entry) /* 来自 entry.asm 的 .entry section */
        *(.text)
    }
    .rodata :
    {
        *(.rodata)
    }
    .data :
    {
        *(.data)
    }
    .bss :
    {
        *(.bss) /* 来自 entry.asm 的 .bss section */
    }
}
