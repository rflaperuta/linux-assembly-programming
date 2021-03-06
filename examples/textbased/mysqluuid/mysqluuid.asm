; Name:         mysqluuid.asm
;
; Build:        nasm "-felf64" mysqluuid.asm -l mysqluuid.lst -o mysqluuid.o
;               ld -s -melf_x86_64 -o mysqluuid mysqluuid.o -lc --dynamic-linker /lib64/ld-linux-x86-64.so.2 -lmysqlclient
;
; Description:  As an alternative for the uuid example, we can get a uuid from mysql server.
;               Benefit : mysql keeps track of unique uids
;               Disadvantage : mysql server must be running on your system.

bits 64

section .bss
section .data

[list -]
    extern    mysql_close
    extern    mysql_errno
    extern    mysql_error
    extern    mysql_fetch_row
    extern    mysql_free_result
    extern    mysql_init
    extern    mysql_query
    extern    mysql_real_connect
    extern    mysql_server_end
    extern    mysql_server_init
    extern    mysql_use_result
    %include  "unistd.inc"
    %include  "sys/stat.inc"
[list +]

    conn:               dq  0
    result:             dq  0
    heapstart:          dq  0
    fd:                 dq  0
    host:               dq  0
    port:               dq  0
    user:               dq  0
    password:           dq  0
    database:           dq  0
    socket:             dq  0
    clientflag:         dq  0

string:
    .filenotfound:              db  "configuration file not found", 10
    .filenotfound.length:       equ $-.filenotfound
    .fileread:                  db  "error reading configuration file", 10
    .fileread.length:           equ $-.fileread
    .filestatus:                db  "error reading configuration file status", 10
    .filestatus.length:         equ $-.filestatus
    .fileclose:                 db  "error closing configuration file", 10
    .fileclose.length:          equ $-.fileclose
    .notenoughmemory:           db  "not enough memory", 10
    .notenoughmemory.length:    equ $-.notenoughmemory
    .deallocmemory:             db  "error deallocating memory", 10
    .deallocmemory.length:      equ $-.deallocmemory

    .mysqlserverinit:           db  "MySQL library could not be initialized",10
    .mysqlserverinit.length:    equ $-.mysqlserverinit
    .mysqlobjinit:              db  "MySQL init object failed", 10
    .mysqlobjinit.length:       equ $-.mysqlobjinit
    .mysqlresult:               db  "MySQL result error", 10
    .mysqlresult.length:        equ $-.mysqlresult
    .mysqlfetchrow:             db  "MySQL fetch row error", 10
    .mysqlfetchrow.length:      equ $-.mysqlfetchrow

    query:                      db  "select uuid()",0
    configfilename:             db  "./mysql.cfg",0
    hoststring:                 db  "DBHOST="
    .length:                    equ $-hoststring
    userstring:                 db  "DBUSER="
    .length:                    equ $-userstring
    passwordstring:             db  "DBPASSWORD="
    .length:                    equ $-passwordstring
    portstring:                 db  "DBPORT="
    .length:                    equ $-portstring

    ; file status structure
    STAT stat
    
section .text
        global _start

_start:
    ; open configuration file
    syscall   open, configfilename, O_RDONLY
    and       rax, rax
    jl        Error.filenotfound
    mov       qword[fd], rax                          ; save filedescriptor
    ; get the filesize
    syscall   fstat, rax, stat
    and       rax, rax
    jl        Error.filestatus
    ; reserve memory for file contents
    ; get memory break
    syscall   brk, 0
    and       rax, rax
    jle       Error.notenoughmemory
    mov       qword[heapstart], rax                   ; save pointer to memory break
    add       rax, qword[stat.st_size]                ; add filesize to allocate memory
    inc       rax                                     ; one extra byte, to be sure the string ends with 00

    ; try to allocate additional memory
    syscall   brk, rax
    sub       rax, rdi                                ; new memory break equal to calculated one?
    and       rax, rax
    jnz       Error.notenoughmemory

    ; read the file in the allocated memory
    syscall   read, qword[fd], qword[heapstart], rdx, qword[stat.st_size]
    and       rax, rax
    jl        Error.fileread

    ; close file
    syscall   close, qword[fd]
    and       rax, rax
    jnz       Error.fileclose
    
; loop through our string, replacing each 0x0A and 0x0D with 00
    mov       rsi, qword[heapstart]
    mov       rdi, qword[stat.st_size]
    call      String.ZeroCRLF

; get the values for host, user, password, port, database, socket and clientflag, if socket and clientflag are
; empty strings then the values for these are NULL instead of the pointer to the socket and clientflag string.
; Port need to be stored as an unsigned integer.
    ; get pointer to HOST
    mov       rdi, hoststring.length
    mov       rsi, hoststring
    call      String.Search
    mov       qword[host], rax
    ; get pointer to USER
    mov       rdi, userstring.length
    mov       rsi, userstring
    call      String.Search
    mov       qword[user], rax
    ; get pointer to PASSWORD
    mov       rdi, passwordstring.length
    mov       rsi, passwordstring
    call      String.Search
    mov       qword[password], rax
    ; get pointer to PORT      
    mov       rdi, portstring.length
    mov       rsi, portstring
    call      String.Search
    ; parse PORT to integer
    mov       rdi, rax
    call      String.ToInt
    mov       qword[port], rax

; all values are known, now connect to mysql server and get an uuid
    ; not an embedded MySQL so all arguments must be zero
    xor       rdi, rdi
    xor       rsi, rsi
    xor       rdx, rdx
    call      mysql_server_init
    and       rax, rax
    jnz       Error.mysqlserverinit
    ; From this point we need to cleanup the library!!!!
    xor       rdi, rdi
    call      mysql_init
    and       rax, rax
    jz        Error.mysqlobjinit
    ; no errors, connect and login 
    mov       qword [conn], rax                 ; save *mysql
    mov       rdi, rax                          ; value of mysql = pointer to mysql instance of connection
    push      qword 0                           ;[clientflag]                       ; the value of clientflags or NULL if none
    push      qword 0                           ;[socket]           ; the value of socket or NULL if none
    mov       r9d, dword [port]                 ; the value of the port to connect to               
    xor       r8, r8                            ; pointer to zero terminated database string
    mov       rcx, qword [password]             ; pointer to zero terminated password string
    mov       rdx, qword [user]                 ; pointer to zero terminated user string
    mov       rsi, qword [host]                 ; pointer to zero terminated host string
    call      mysql_real_connect                ; connect
    pop       rdx                               ; restore stackpointer
    pop       rdx
    sub       rax, qword [conn]                 ; if conn == pointer to mysql instance then succes
    and       rax, rax      
    jnz       Error.mysqlconnect
    ; We are connected, execute the query
    mov       rsi, query                        ; pointer to zero terminated query string
    mov       rdi, qword [conn]                 ; value of mysql = pointer to mysql instance of connection
    call      mysql_query                       ; query the server
    ; check for errors
    mov       rdi, qword [conn]                 ; check if an error occured
    call      mysql_errno
    and       rax, rax
    jnz       Error.mysqlerror

    mov       rdi, qword[conn]
    call      mysql_use_result                  ; we don't ask all the records at once (less client side memory)
    and       rax, rax
    jz        Error.mysqlresult
    ; get uuid from resultset
    mov       qword [result], rax
    mov       rdi, rax
    call      mysql_fetch_row
    and       rax, rax
    cmp       rax, 2000                         ; unknown error
    je        Error.mysqlerror
    cmp       rax, 2013                         ; connection lost
    je        Error.mysqlerror
    jz        NoRows
    mov       rsi, [rax]                        ; get result
    mov       rdi, rsi
    call      String.Length                     ; result length
    mov       rdx, rax                          ; length in rdx
    inc       rdx
    add       rax, rsi
    mov       byte [rax], 0x0A
    syscall   write, stdout
NoRows:      
    mov       rdi, qword[conn]
    call      mysql_errno
    and       rax, rax
    jnz       Error.mysqlerror
    ; free result
    mov       rdi, qword[result]
    call      mysql_free_result
CloseConnection:
    mov       rdi, qword[conn]
    call      mysql_close
ServerEnd:        
    call      mysql_server_end
FreeHeap:
    syscall   brk, qword[heapstart]
    and       rax, rax
    jl        Error.deallocmemory
Exit:
    syscall   exit, 0

Error:
.mysqlserverinit:
    mov       rsi, string.mysqlserverinit
    mov       rdx, string.mysqlserverinit.length
    call      String.ToStdErr
    jmp       Exit
.mysqlobjinit:
    mov       rsi, string.mysqlobjinit
    mov       rdx, string.mysqlobjinit.length
    call      String.ToStdErr
    jmp       ServerEnd
.mysqlconnect:
    push      ServerEnd
    jmp       ._error
.mysqlerror:
    push      CloseConnection
._error:     
    mov       rdi, qword[conn]
    call      mysql_error
    mov       rsi, rax
    mov       rdi, rax
    call      String.Length
    mov       rdx, rax
    inc       rdx
    add       rax, rsi
    mov       byte[rax], 0x0A
    call      String.ToStdErr
    ret
.mysqlresult:
    mov       rsi, string.mysqlresult
    mov       rdx, string.mysqlresult.length
    call      String.ToStdErr
    jmp       CloseConnection
.mysqlfetchrow:
    mov       rsi, string.mysqlfetchrow
    mov       rdx, string.mysqlfetchrow.length
    call      String.ToStdErr
    jmp       CloseConnection   
.notenoughmemory:
    mov       rsi, string.notenoughmemory
    mov       rdx, string.notenoughmemory.length
    jmp       Exit
.deallocmemory:
    mov       rsi, string.deallocmemory
    mov       rdx, string.deallocmemory.length
    call      String.ToStdErr
    jmp       Exit
.fileread:
    mov       rsi, string.fileread
    mov       rdx, string.fileread.length
    call      String.ToStdErr
    jmp       Exit
.filenotfound:
    mov       rsi, string.filenotfound
    mov       rdx, string.filenotfound.length
    call      String.ToStdErr
    jmp       Exit
.filestatus:
    mov       rsi, string.filestatus
    mov       rdx, string.filestatus.length
    call      String.ToStdErr
    jmp       Exit
.fileclose:
    mov       rsi, string.fileclose
    mov       rdx, string.fileclose.length
    call      String.ToStdErr
    jmp       Exit      

String.ToStdErr:
    push      rcx
    push      r11
    mov       rdi, stderr
    jmp       _syscallwrite
    
String.ToStdOut:
    push      rcx
    push      r11
    mov       rdi, stdout
_syscallwrite:     
    syscall   write, rdi, rsi, rdx
    pop       r11
    pop       rcx
    ret

; Search for a substring in a string
; on succes CF=0 and RAX has pointer
String.Search:
    mov       rax, rdi                          ; the length in rax
    mov       rbx, rsi                          ; the stringpointer in rbx
    mov       rsi, qword[heapstart]
    mov       rdx, qword[stat.st_size]
    sub       rdx, rdi
.@1:    
    mov       rdi, rbx
    mov       rcx, rax
    cld
    repe      cmpsb
    je        .@2
    dec       rdx
    and       rdx, rdx
    jnz       .@1
    stc
    ret
.@2:
    mov       rax, rsi
    clc
    ret
; convert string to unsigned integer value
String.ToInt:
    mov       rsi, rdi
    xor       rdx, rdx
.@1:    
    xor       rax, rax
    lodsb
    and       al, al                            ; end of string?
    jz        .@2
    and       al, 0x0F                          ; un-ascii
    and       rdx, rdx
    jz        .@3
    mov       rcx, rax
    mov       rax, rdx
    xor       rdx, rdx
    mov       rbx, 10
    mul       rbx
    mov       rdx, rcx
.@3:    
    add       rax, rdx
    mov       rdx, rax
    jmp       .@1
.@2:
    mov       rax, rdx
    ret

; determine string length of a string in RDI    
String.Length:
    xor       rcx, rcx
    dec       rcx
    xor       rax, rax
    repne     scasb
    neg       rcx
    dec       rcx
    dec       rcx
    and       rcx, rcx
    mov       rax, rcx                          ; return length in RAX
    ret

; replaces LF en CR by NULL
String.ZeroCRLF:
    mov       rcx, rdi
    inc       rcx
.@1:
    cld
    lodsb
    cmp       al, 0x0A
    je        .@2
    cmp       al, 0x0D
    jne       .@3
.@2:
    dec       rsi
    xor       al, al
    mov       byte[rsi], al
.@3:      
    loop      .@1
    ret
