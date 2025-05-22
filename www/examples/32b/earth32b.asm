org 100h
mov dx,0x330
rep outsb
lds bp,[bx]
or al,0x13
L: int 0x10
X: lodsb
adc al,[si+320]
rcr al,1
not al
mov [si],al
A:imul si,byte 1+4*25
jmp short X
M:db 0xc9,56,0x99,81,127