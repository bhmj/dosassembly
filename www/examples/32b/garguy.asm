jl X
X:sub [bx+si],al
int 10h
mov bl,5
M:mov cl,8
mov al,13
int 29h
mov al,10
L:int 29h
salc
rol dword [si],1
jc F
mov al,219
F:loop L
dec bx
jnz M
ret