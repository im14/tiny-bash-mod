OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
SECTIONS
{
  .hash       : { *(.hash) }
  .dynsym     : { *(.dynsym) }
  .dynstr     : { *(.dynstr) }
  .rela.dyn   : { *(.rela.data) }
  .text       : { *(.text) }
  .dynamic    : { *(.dynamic) }
  .data       : { *(.data) }
  /DISCARD/   : { *(*) }
}
