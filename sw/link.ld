OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    /* Code and read-only data */
    .text :
    {
        *(.text.boot)
        *(.text*)
        *(.rodata*)
    } > RAM

    /* Initialized data */
    .data : ALIGN(4)
    {
        *(.data*)
    } > RAM

    /* Zero-initialized data */
    .bss (NOLOAD) : ALIGN(4)
    {
        *(.bss*)
        *(COMMON)
    } > RAM

    /DISCARD/ :
    {
        *(.comment*)
        *(.note*)
    }
}
