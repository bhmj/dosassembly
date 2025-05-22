add ax,04F02h
A:
add cx,[si]
pop dx
and dh,3
mov bx,0105h
int 10h
sub di,cx
sub di,dx
add di,di
loop P
mov al,dh
xlat
P:
push cx
sbb cx,dx
mov ah,0Ch
jmp short A
