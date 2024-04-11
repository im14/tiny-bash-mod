BITS 64

global s_struct
SYS_setgid equ 105
SYS_setuid equ 106

section .text
s:
  push 65534
  pop rdi

  push SYS_setuid
  pop rax
	syscall

	push SYS_setgid
  pop rax
	syscall

  ret

section .data
bname: db "s",0
s_struct:
  .name dq bname
  .function dq s
  db 1
