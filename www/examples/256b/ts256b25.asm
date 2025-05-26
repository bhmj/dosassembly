; rEIfing tomEIto: OWUMM!
; 256b entry for Revision 2025 from T$
; runs on MS-DOS / DosBOX (cycles = max or at least high enough for > 18 fps) 
; note that some windows machines have insufficient pc speaker timing both with XP DOS box or NTVDN,
; use plain DOS for maximum fidelity

org 100h

push word 0a000h
pop es

mov al,13h
int 10h

schleife:

mov bp,[fs:0x46c]

xor dx,dx
mov ax,di
mov cx,320
div cx ;ax = y, dx = x

mov cx,ax
xor cx,dx
and cl,3

sub dx,160
jns xispositive
 neg dx
xispositive:
sub ax,110
jns noneg
 test bp,6
 jz noeye
 cmp al,-16
 jl noeye
 cmp dl,16
 jg noeye
  push ax
  add  ax,8
  imul ax,ax
  mov  bx,dx
  sub  bx,8
  imul bx,bx
  add bx,ax
  pop ax
  cmp bx,39;7*7
  jnb noeye
    mov al,31
    shr bl,2
    sub al,bl
    jmp draw
 noeye:
 imul ax,3
 sar ax,2
noneg:
push ax
imul ax,ax
imul dx,dx
add ax,dx
add ah,cl
shr ax,3

mov bx,bp;[fs:0x46c]
xor bh,bh
inc bx
xor dx,dx
div bx

mov ah,72
mul ah
add ax,16+16;+6

mov bx,bp
shr bx,8
imul bx,23
and bx,15
add ax,bx

pop dx

or ah,ah
jz draw

 mov bx,bp
 xor bh,bh
 shr bx,2
 sub dx,16
 sub dx,bx

  mov bx,di
  ror bl,3
  and bx,3
  add dx,bx

 js nobg
  mov al,dl
  add al,cl

  shr al,3 ;2
  add al,16+16+1*72 +3 ;+11
  
  mov bx,bp
  and bh,7
  imul bx,3
  add al,bh
  jmp draw

 nobg:
 xor ax,ax
draw:

stosb

or di,di
jnz near schleife

mov ax,bp
add al,ah
and al,7
mov cx,bp
shr cl,5
jnz nonoise
 mov ax,bp
 and ah,7
 xor al,ah
 ror al,5 
 xor ah,ah
 jmp soundout
nonoise:
;inc cl

shl al,cl
add al,64

soundout:
out 42h,al ; set speaker freq
out 42h,al
not al
out 61h,al ; enable speaker

; ui
in al,60h
dec al
jnz near schleife
ret