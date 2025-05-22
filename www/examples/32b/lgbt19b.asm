xchg cx,ax
mov al,13h
X: cwd
int 10h
mul cx
mov al,dh
add al,40
and al,46
mov ah,12
loop X
ret