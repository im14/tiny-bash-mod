# bash tiny mod

## overview

There is an IRC bot that executes bash commands. Years ago I decided to try to make the smallest command to have it execute binary code. The smallest way is to inject over an existing application rather than write out teensy elf headers. This project is to create the smallest loadable bash builtin module. The same example code called `s` for `su` but it isn't the typical one. It just sheds root permissions by setuid/setgid to nobody.

## why?

Just to learn ELF sections and how linkers work. Everyone has a hobby eh.

## What I've learned

### Base sizes

A simple *Hello World* program in C is 14472 bytes in ELF-64. The same in ASM without libc is 4360 bytes. The latter has a lot fewer sections but could have even less.

### .shstrtab

You can pretty get lean output from standard tools but there is a very large section called `.shstrtab` that nothing wants to remove. It's typically last so finding that string in a binary and removing everything after it seems fine. This saved 207 bytes for the simple *Hello World* asm program.

### dynamic sections

When you're making a shared library vs an executable you have more sections. The included `su.asm` after being linked and stripped is 13096 bytes. Here are the program headers

    Program Headers:
      Type           Offset             VirtAddr           PhysAddr
                     FileSiz            MemSiz              Flags  Align
      LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                     0x0000000000000240 0x0000000000000240  R      0x1000
      LOAD           0x0000000000001000 0x0000000000001000 0x0000000000001000
                     0x0000000000000010 0x0000000000000010  R E    0x1000
      LOAD           0x0000000000002000 0x0000000000002000 0x0000000000002000
                     0x0000000000000000 0x0000000000000000  R      0x1000
      LOAD           0x0000000000002f10 0x0000000000002f10 0x0000000000002f10
                     0x0000000000000103 0x0000000000000103  RW     0x1000
      DYNAMIC        0x0000000000002f10 0x0000000000002f10 0x0000000000002f10
                     0x00000000000000f0 0x00000000000000f0  RW     0x8
      GNU_RELRO      0x0000000000002f10 0x0000000000002f10 0x0000000000002f10
                     0x00000000000000f0 0x00000000000000f0  R      0x1
    
     Section to Segment mapping:
      Segment Sections...
       00     .hash .gnu.hash .dynsym .dynstr .rela.dyn
       01     .text
       02     .eh_frame
       03     .dynamic .data
       04     .dynamic
       05     .dynamic

#### .eh_frame

I don't know much about the details here but it's big and unnecessary. It can be removed during linkage by using a flag. After adding that option, ie `ld -shared --no-ld-generated-unwind-info -o su su.o` the result after strip is 8920. That's **32%** shrinkage!

#### GNU hash

The way we find symbols involves an old inefficient hash function I guess so GNU made it better. Our program has one symbol that needs located. So to revert to that old SysV style we use another flag. After linking with `--hash-style=sysv` the stripped output is 8856 bytes. 36 bytes isn't much but it's gone now.

### ld scripts

We still have 5 sections looking like:

      Segment Sections...
       00     .hash .dynsym .dynstr .rela.dyn
       01     .text
       02     .dynamic .data
       03     .dynamic
       04     .dynamic
We don't care about security we can load everything in 1 section that's RWX and have just two program headers. One LOAD and one DYNAMIC. Now we're at 5144 bytes -- a savings of 3712 bytes! Section headers (.shstrtab) start at 4568 so removing them saves 576 bytes.

### Holes

Well I got it down to 413 bytes so there must be a lot more to remove... The current program headers:

    Program Headers:
      Type           Offset             VirtAddr           PhysAddr
                     FileSiz            MemSiz              Flags  Align
      LOAD           0x0000000000001000 0x0000000000000000 0x0000000000000000
                     0x0000000000000193 0x0000000000000193  RWE    0x1000
      DYNAMIC        0x00000000000010a0 0x00000000000000a0 0x00000000000000a0
                     0x00000000000000e0 0x00000000000000e0  RW     0x8

That first LOAD offset is 0x1000 - that's 4K! Do we need that many zeros? No. Using `. = SIZEOF_HEADERS;` in the ld script takes all that out. Then we're at 581 bytes after strip and manually removing shstrtab. We're now at 4% of our original 13096 bytes. So much fat trimmed.

## Anymore FAT to trim?

Well that's where I throw together `elf2nasm.c` to get a clear view of the structure. It's not polished by any means. It was just enough to get this one-off program in a form I could start hacking away at. I found things still ran without having RELACOUNT, STRSZ, and SYMENT in the dynstr section. Then the rest of the savings are likely just overlapping things that can be re-used on top of things that don't matter so much but are sorta necessary. So right now that's 413 bytes. That's another **30%** less than where we were before deep diving.
