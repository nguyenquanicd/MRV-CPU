/* Target */
OUTPUT_ARCH(riscv)
OUTPUT_FORMAT(elf32-littleriscv)

/* Entry point label */
ENTRY(_start)

/* Memory Layout */
MEMORY
{
    IVEC (rx)  : ORIGIN = 0x00000100, LENGTH = 256   /* Interrupt vector region */
    IRAM (rx)  : ORIGIN = 0x00001000, LENGTH = 32K   /* Instruction RAM starts at 0x1000 */
    DRAM (rw)  : ORIGIN = 0x80000000, LENGTH = 8K    /* Data RAM */
}

/* Sections layout */
SECTIONS
{
    . = ORIGIN(IVEC);

    /* Interrupt vector section at 0x100 */
    .interrupt : {
        *(.interrupt)
        *(.interrupt.*)
    } > IVEC

    . = ORIGIN(IRAM);
    
    /* Text section (code) placed in IRAM */
    .text : {
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > IRAM

    /* Uninitialized data section (BSS) - will be zeroed by runtime */
    .bss : ALIGN(4) {
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _ebss = .;
    } > IRAM

    /* Discard other sections */
    /DISCARD/ : {
        *(.comment)
        *(.gnu.*)
        *(.note.*)
    }

    /* Stack at top of DRAM */
    _stack_top = (ORIGIN(DRAM) + LENGTH(DRAM)) & ~0xF;
}
