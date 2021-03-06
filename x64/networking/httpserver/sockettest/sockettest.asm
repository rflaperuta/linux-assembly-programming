; httpsockettest.asm
;
; example of a basic connection to a host:port
; basic error handling is used but can be (and must be) improved
;
; Purpose: This program works together with the httpserver demo.

BITS 64
[list -]
      %include "unistd.inc"
      %include "sys/socket.inc"
[list +]

section .bss
 
sockfd:                 resq 1
sock_addr:              resq 1
buffer:                 resb 1000
.length:                equ  $-buffer

section .data

; the message we will send to the server, for http server request we must change this to "GET / HTTP/1.1",10,10

request:                db 'GET /hello.html HTTP/1.1',10
                        db 'User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)',10
                        db 'Host: localhost',10
                        db 'Accept-Language: en-us',10
                        db 'Connection: Keep-Alive',10, 10
                        
request.length:         equ $-request
socketerror:            db "socket error", 10
.length:                equ $-socketerror
connecterror:           db "connection error", 10
.length:                equ $-connecterror
connected:              db "Connected", 10
.length:                equ $-connected
disconnected:           db "Connection closed", 10
.length:                equ $-disconnected

crlf:                   db 10
port:                   db 17,92           ; port 4444 (256 * 17 + 92)

section .text
 
global _start
 
_start:
 
; create a socket
        mov     rax, SYS_SOCKET          ; call socket(SOCK_STREAM, AF_NET, 0);
        mov     rdi, PF_INET             ; PF_INET = 2
        mov     rsi, SOCK_STREAM         ; SOCK_STREAM = 1
        xor     rdx, rdx                 ; IPPROTO_IP = 0
        syscall
        and     rax, rax
        jl      .socketerror
        mov     QWORD[sockfd], rax       ; save descriptor
 
; fill in sock_addr structure (on stack)
        xor     r8, r8                   ; clear the value of r8
        mov     r8, 0x0100007F;          ; 100007F (IP address : 127.0.0.1)
        push    r8                       ; push r8 to the stack
        push    WORD [port]              ; (Port = 4444) don't use PUSH WORD 4444 (endianess!)
        push    WORD AF_INET             ; push protocol argument to the stack (AF_INET = 2)
        mov     QWORD[sock_addr], rsp    ; Save the sock_addr_in

; connect to the remote host
        mov     rax, SYS_CONNECT         ; 
        mov     rdi, QWORD[sockfd]       ; socket descriptor
        mov     rsi, QWORD[sock_addr]    ; sock_addr structure
        mov     rdx, 16                  ; length of sock_addr structure
        syscall
        and     rax, rax
        jl      .connecterror
        
        mov     rsi, connected
        mov     rdx, connected.length
        mov     rdi, STDOUT
        mov     rax, SYS_WRITE
        syscall
        
; send the message to the server
        mov     rax, SYS_SENDTO
        mov     rdi, QWORD[sockfd]
        mov     rsi, request
        mov     rdx, request.length
        mov     rcx, 0                          ; flags
        mov     r8, 0                           ; pointer to destination address structure
        mov     r9, 0                           ; length of destination address structure
        syscall

; receive a message from the server
.receive:
        mov     rax, SYS_RECVFROM
        mov     rdi, QWORD[sockfd]
        mov     rsi, buffer
        mov     rdx, buffer.length              ; buffer length
        mov     rcx, 0                          ; flags
        mov     r8, 0                           ; pointer to source address structure
        mov     r9, 0                           ; length of source address structure
        syscall
        and     rax, rax
        jz      .endreceive

; write contents of the buffer to stdout, rax has the bytes read
        mov     rdx, rax                        ; bytes read in rdx
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        mov     rsi, buffer
        syscall
        jmp     .receive
        
.endreceive:        
; additional CRLF
        mov     rax, SYS_WRITE
        mov     rdi, STDOUT
        mov     rsi, crlf
        mov     rdx, 1
        syscall

; close connection
        mov     rax, SYS_CLOSE
        mov     rdi, QWORD[sockfd]
        syscall
        
; disconnected message
        mov     rsi, disconnected
        mov     rdx, disconnected.length
        mov     rdi, STDOUT
        mov     rax, SYS_WRITE
        syscall
 
; exit program        

        xor     rdi, rdi
        mov     rax, SYS_EXIT
        syscall
 
; the errors
.connecterror:
        mov     rsi, connecterror
        mov     rdx, connecterror.length
        jmp     .print
 
.socketerror:
        mov     rsi, socketerror
        mov     rdx, socketerror.length
        jmp     .print
 
.print:
        mov     rdi, STDOUT
        mov     rax, SYS_WRITE
        syscall
.exit:  
        xor     rdi, rdi
        mov     rax, SYS_EXIT
        syscall