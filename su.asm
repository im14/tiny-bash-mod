BITS 64

global s_struct
SYS_setgid equ 105
SYS_setuid equ 106

section .text
s:
  xor rax,rax
  mov rdi,65534

  mov al,SYS_setuid
  syscall

  mov al,SYS_setgid
  syscall

  ret

section .data
bname: db "s",0
s_struct:
  .name dq bname
  .function dq s
  db 1
