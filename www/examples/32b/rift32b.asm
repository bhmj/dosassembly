mov al,13h
out 61h,al
int 10h
X: db 0xA
les ax,[bx]
daa
L: add dl,[bp+si]
sub dh,dl
shl dl,1
adc dl,dh
inc ax
ja L
stosb
sub al,[bp+si]
out 42h,al
mov ah,0xcc
mul di
jmp short X-1
