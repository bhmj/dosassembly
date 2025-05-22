mov al,0x13
int 0x10
lds bp,[bx]
L: add [bx],ax
inc ax
das
dec bx
jnz L
X: imul si,byte 17
lodsb
mov [si],al
mov [si-2],al
mov [si+319],al
out 0x61,al
jmp short X

nop
nop