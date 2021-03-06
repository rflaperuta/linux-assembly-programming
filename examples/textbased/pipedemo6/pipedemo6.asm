; Name          : pipedemo6.asm
;
; Build         : nasm -felf64 pipedemo6.asm -l pipedemo6.lst -o pipedemo6.o
;                 ld -s -melf_x86_64 -o pipedemo6 pipedemo6.o
;
; Description   : A demonstration on pipes and fork based on an example from Beej's Guide to IPC
;                 This is a more usefull example. The program clones itself with fork.  The child
;                 process executes the /bin/ls command and writes the output to the pipe, the parent
;                 at his turn executes the /usr/bin/wc command and takes as arguments the contents of
;                 the pipe, earlier provided by the child process.  The entire result is displayed on
;                 stdout.
;                 This program executes the "ls | wc -l" command when entered in a terminal and displays
;                 the number of directory entries in the current directory.
;
; Source        : Beejs guide to IPC - http://beej.us/guide/bgipc/output/html/multipage/pipes.html
;
;
; August 24, 2014 : assembler 64 bits version
 
bits 64
 
[list -]
        %include "unistd.inc"
[list +]
 
section .bss
 
section .data

    pdfs:
    .read:          dd      0                       ; read end
    .write:         dd      0                       ; write end
    
    Child.Cmd:
    .filename       db      "/bin/ls",0                        ; full path! 
    .argvPtr        dq      Child.Cmd.filename
    ; to save space the end of argvPtr list is the same as the end of the envPtr list
    .envPtr         dq      0                                  ; terminate the list of pointers with NULL

    Parent.Cmd:
    .filename       db      "/usr/bin/wc",0                    ; again full path!
    .argv1          db      "-l", 0                            ; argument to pass
    .argvPtr        dq      Parent.Cmd.filename
                    dq      Parent.Cmd.argv1
    ; to save space the end of argvPtr list is the same as the end of the envPtr list
    .envPtr         dq      0                                  ; terminate the list of pointers with NULL
    
    errorexecve:    db      "execve error", 10
    .length:        equ     $-errorexecve
    errorfork:      db      "fork error", 10
    .length:        equ     $-errorpipe
    errorpipe:      db      "pipe error", 10
    .length:        equ     $-errorpipe
    
section .text
 
global _start
_start:

    ; create pipe
    syscall    pipe, pdfs
    and        rax, rax
    js         Error.PIPE
    ; fork child
    syscall    fork
    and        rax, rax
    js         Error.FORK
    jnz        ParentProcess
    
    ; close STDOUT
    syscall    close, stdout
    ; duplicate STDOUT to pdfs.stdout
    mov       edi, dword[pdfs.write]
    syscall    dup, rdi
    ; close read end of the pipe, not needed
    mov       edi, DWORD[pdfs.read]
    syscall    close, rdi
    ; execute ls command
    syscall    execve, Child.Cmd.filename, Child.Cmd.argvPtr, Child.Cmd.envPtr
    and        rax, rax
    js         Error.EXECVE
    jmp        Exit
    
ParentProcess:      
    ; close STDIN
    syscall    close, stdin
    ; duplicate STDIN to pdfs.stdin
    mov        edi, dword[pdfs.read]
    syscall    dup, rdi
    ; close write end of the pipe, not needed
    mov        edi, dword[pdfs.write]
    syscall    close, rdi
    ; execute wc -l command with input from pdfs.read, output to stdout
    syscall    execve, Parent.Cmd.filename, Parent.Cmd.argvPtr, Parent.Cmd.envPtr
    and        rax, rax
    js         Error.EXECVE
    jmp        Exit

Error:
.EXECVE:
    mov        rsi, errorexecve
    mov        rdx, errorexecve.length
    jmp        Write
.FORK:
    mov        rsi, errorfork
    mov        rdx, errorfork.length
    jmp        Write
.PIPE:
    mov        rsi, errorpipe
    mov        rdx, errorpipe.length
    jmp        Write
Write:
    syscall    write, stdout
Exit:      
    syscall    exit, 0
