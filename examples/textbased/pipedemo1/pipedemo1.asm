; Name:         : pipedemo1.asm
;
; Build:        : nasm -f elf64 -o pipedemo1.o -l pipedemo1.lst pipedemo1.asm
;                 ld -s -melf_x86_64 -o pipedemo1 pipedemo1.o
;
; Description   : The program creates a pipe, writes three message in it. Later on the message
;                 read on the other end of the pipe and displayed on stdout.
;
; Source        : This was an C example I found on the internet, don't know where

bits 64
 
[list -]
     %include "unistd.inc"
[list +]

%define MSGSIZE  8

section .bss
 
     p:
     .read:          resd    1            ; read end of the pipe
     .write:         resd    1            ; write end of the pipe
     inbuf:          resb    MSGSIZE
 
section .data

     msg1:           db      "hello #1"
     msg2:           db      "hello #2"
     msg3:           db      "hello #3"
     EOL:            db      10
     pipeerror:      db      "pipe call error"
     .length:        equ     $-pipeerror
 
section .text
     global _start

_start:
     syscall   pipe, p
     and       rax, rax
     jns       startpipe                        ; if RAX < 0 then error
     syscall   write, stdout, pipeerror, pipeerror.length
     jmp       exit
      
startpipe:      
     ; write msg1 to the pipe
     mov       edi, dword[p.write]
     syscall   write, rdi, msg1, MSGSIZE
     ; write msg2 to the pipe
     mov       edi, dword[p.write]
     syscall   write, rdi, msg2, MSGSIZE
     ; write msg3 to the pipe
     mov       edi, dword[p.write]
     syscall   write, rdi, msg3, MSGSIZE
     xor       r8, r8                           ; init loopcounter
.repeat:      
     ; read MSGSIZE bytes from the pipe into the buffer
     mov       edi, dword[p.read]
     syscall   read, rdi, inbuf, MSGSIZE
     syscall   write, stdout, inbuf, MSGSIZE
     syscall   write, stdout, EOL, 1
     inc       r8
     cmp       r8, 3
     jl        .repeat                          ; repeat 2 more times
exit:      
     syscall   exit, 0
