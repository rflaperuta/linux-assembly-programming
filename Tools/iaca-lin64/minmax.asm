; Name:         minmax.asm
;
; Build:        nasm "-felf64" minmax.asm -l minmax.lst -o minmax.o
;               ld -s -melf_x86_64 -o minmax minmax.o
;
; Description:  Determine the minimum and maximum from a list of integers (wordsize).
;               If only one integer is given, that integer will be minimum and maximum.

bits 64

[list -]
    %include "unistd.inc"
[list +]

section .data

    ; the list
    numlist:    dw 56, 45, 36, 67, 76, 22, 89, 12, 29, 83
    ; the list length from which we will cacluate the number of integers in the list
    .length:    equ $-numlist
    min:        dw 0
    max:        dw 0
    
section .text
     global _start

_start:

    mov       rbx, numlist.length      ; size in bytes of numbers
    and       rbx, rbx                 ; is list empty?
    jz        Exit                     ; nothing to do list is empty
    shr       rbx, 1                   ; divided by two (2 bytes in one word) gives number of integers
    mov       rsi, numlist             ; start of integer list
    cld                                ; D flag should be zero, make zero just to be sure
    mov       rcx, rbx                 ; move number of integers in RCX (= loop counter)
    
     mov ebx, 111          ; Start marker bytes
    db 0x64, 0x67, 0x90   ; Start marker bytes
    
repeat:
    lodsw                              ; load word in ax
    cmp       rcx, rbx                 ; is it first number in list?
    je        firstMinMax              ; yes, min and max are both the same at this point
    cmp       ax, word [max]           ; not the first number in the list compare with maximum
    jg        newMax                   ; if greater than current max then ax has new maximum (use jg for signed integers else use ja)
    cmp       ax, word [min]           ; not greater, lower perhaps?
    jl        newMin                   ; yes, ax has new minimum (use jl for signed integers else use jb)
next:
    loop      repeat                   ; if RCX isn't zero then there are more integers in the list, so repeat loop
    mov ebx, 222          ; End marker bytes
    db 0x64, 0x67, 0x90   ; End marker bytes
    
    jmp       Exit                     ; otherwise we exit the program, WORD[min] has minimum from list, WORD[max] has the maximum from the list
firstMinMax:
    mov       word [min], ax           ; store first minimum
newMax:
    mov       word [max], ax           ; store (new or first) maximum
    jmp       next                     ; check for next integer
newMin:
    mov       word [min], ax           ; store new minimum
    jmp       next                     ; check for next integer

Exit:
    mov       ax, word [min]           ; minimum in ax
    mov       bx, word [max]           ; maximum in bx
    syscall   exit, 0

    
