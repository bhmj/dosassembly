;Quad 64b
;64 byte intro source by T$
;Greets to mados, cthulhu, spacey and neo

org 100h

  mov    al,13h
  int    10h
  lds    ax,[bx]

;  mov    dx,3C9h
;  mov    ch,3
;  locloop_1:
;  ror    eax,8
;  cmp    al,3Fh
;  jb     loc_2
;  mov    al,3Fh
;  inc    ah
;  loc_2:
;  test   cl,3
;  jz     loc_3
;  out    dx,al
;  loc_3:
;  loop   locloop_1

;mov cx,1

schleife:
 
mov ax,di
xor dx,dx
mov bx,320
div bx
;dx=x, ax=y

add ax,cx
add dx,cx
and ax,dx
;shr ax,3
;add ax,cx
shr ax,cl
;shl ax,16 ;rcr ax,1

xor [di],al 

;and al,1
;add [di],al ;adc byte [di],al ;0

inc di

jnz schleife

inc cx

jmp short schleife