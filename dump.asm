; bash loadable builtin module as a
; minimal dynamically linked elf
; 2024-04-12 563 bytes initial size
;            499 remove padding from dynamic section
;            483 remove RELACOUNT from dynamic
;            467 remove final NULL from dynamic
;            465 overlap "s",0 module_name somewhere
;            445 overlap HASH on SYMTAB:0 (didn't help gzip output still 276)

BITS 64

org 0

section EHdr start=0
EHdr_addr equ $
                          ; e_ident[16]
db 0x7F,"ELF"             ;   ei_magic
db 2,1,1                  ;   ei_class ei_data ei_version
db 0,0                    ;   ei_osabi ei_abiversion
; nope. can't use these zeros
;   enable: cannot open shared object ./s: ./s: nonzero padding in e_ident
times 7 db 0              ;   ei_pad
dw 3                      ; e_type
dw 62                     ; e_machine
dd 1                      ; e_version
dq 0                      ; e_entry
dq PHdr_addr              ; e_phoff
dq 0                      ; e_shoff
dd 0                      ; e_flags
dw EHdr_sz                ; e_ehsize
dw e_phentsize            ; e_phentsize
dw PHdr_sz / e_phentsize  ; e_phnum
dw 64                     ; e_shentsize
dw 0                      ; e_shnum
dw 0                      ; e_shstrndx

EHdr_sz equ $ - $$
section PHdr
PHdr_addr equ $

dd 1                      ; p_type (PT_LOAD)
dd 7                      ; p_flags (RWX)
dq 0                      ; p_offset
dq 0                      ; p_vaddr
dq 0                      ; p_paddr
dq filesz                 ; p_filesz
dq filesz                 ; p_memsz
dq 4096                   ; p_align
e_phentsize equ $ - $$

dd 2                      ; p_type (PT_DYNAMIC)
dd 6                      ; p_flags (R_X)
dq dynamic_addr           ; p_offset
dq dynamic_addr           ; p_vaddr
dq dynamic_addr           ; p_paddr
dq dynamic_sz             ; p_filesz
dq dynamic_sz             ; p_memsz
dq 8                      ; p_align

PHdr_sz equ $ - $$
section rela
rela_addr equ $

.rela0:
dq s_struct.name          ; r_offset
dq 8                      ; r_info
dq module_name            ; r_addend

.rela24:
dq s_struct.function      ; r_offset
dq 8                      ; r_info
dq s                      ; r_addend

rela_sz equ $ - $$
; moved into .sym0
;section hash
;hash_addr equ $
;
;dd 1                      ; nbucket
;dd 2                      ; nchain
;dd 1                      ; bucket[0]
;dd 0                      ;  chain[0]
;dd 0                      ;  chain[1]
;hash_sz equ $ - $$
section strtab
strtab_addr equ $

.undef:
.str0: db 0               ; undef entry
.str1: db 's_struct',0

strtab_sz equ $ - $$
section dynamic
dynamic_addr equ $

dq 0x4,hash_addr          ; HASH   
dq 0x5,strtab_addr        ; STRTAB
dq 0x6,symtab_addr        ; SYMTAB
dq 0x7,rela_addr          ; RELA
dq 0x8,rela_sz            ; RELASZ
dq 0x9,0x18               ; RELAENT
dq 0xa,0xa                ; STRSZ
dq 0xb,0x18               ; SYMENT
;dq 0x0,0x0               ; NULL

dynamic_sz equ $ - $$
section symtab
symtab_addr equ $

.sym0:
dd 0                      ; st_name
; overlap HASH. seems fine as long as idx=0 has st_name=0
hash_addr equ $
dd 1,2,1,0,0

.sym1:
dd 1                      ; st_name (s_struct)
db 16                     ; st_info
module_name:
db "s"                    ; st_other
dw 0                      ; st_shndx
dq s_struct               ; st_value
dq 0                      ; st_size

symtab_sz equ $ - $$

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SYS_setgid equ 105
SYS_setuid equ 106

; nasm wants to put .text at 0 so i just name it something else for now
section code
text_addr equ $
s:
  xor eax,eax
  mov rdi,65534

  mov al,SYS_setuid
  syscall

  mov al,SYS_setgid
  syscall

  ret

section .data
data_addr equ $
s_struct:
  .name dq module_name
  .function dq s
  db 1

filesz equ $
