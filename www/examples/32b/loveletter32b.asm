mov al,0x10
S: int 0x10
shl bl,1
add dx,cx
sar dx,1
rcr bp,1
jc B
inc bx
sbb cx,dx
adc dx,byte 127
B: lea ax,[bx+0x0d05]
aas
xchg cx,dx
sub cx,byte 27
jmp short S
