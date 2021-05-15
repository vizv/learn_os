/* Viz @ 2021.05.15 */
/* Credits: https://github.com/tanmayv25/x86-bootloader, http://3zanders.co.uk/2017/10/13/writing-a-bootloader */

ENTRY(entry)
OUTPUT_FORMAT("binary")
SECTIONS {
    . = 0x7c00;
    .text :
    {
        *(.entry)
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
        *(.bss)
    }
}
