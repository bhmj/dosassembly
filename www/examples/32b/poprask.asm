mov al,13h
int 10h
a:
les si,[bx]
mul di
b:
mov al,dh
sub dh,dl
mul dh
sub dx,bp
add dl,ah
dec si
ja  b
xchg si,ax
add ax,0AC53h
stosb
loop a
hlt
dec bp
jmp short a
