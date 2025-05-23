;##***---...  DIFU'ZE
;#*#*-*-.-. . a 256-byte intro by Rrrola
;##***---...  rrrola@gmail.com
;#*#*-*-.-. . http://rrrola.wz.cz
; greets to all MIDI enthusiasts

org 100h ; assume ah=bx=0, cx=255, dx=cs, si=256, di=sp=-2, 216kB free

;Init: set mode 13h, ds=cs+1300h es=cs+2600h fs~A000h cx=20CDh

  lfs  cx,[bx]
  mov  al,13h
  int  10h
  add  dh,al
  mov  ds,dx      ; urine density (u)
  add  dh,al
  mov  es,dx      ; vomit density (v)

;Palette: eight gradients (six unique: vi pi cy bl br gr)

  mov  dx,3C8h
P imul bx,cx,-4   ; bl = 4 times {0..255}
  mov  al,bl
  sar  al,1       ; al = {0..63,-64..0}
  je   Q          ; al==0: cycle RGB->GBR
  jns  R
  not  al
R out  dx,al      ; = {0..63,63..0}
  mov  dl,0C9h
  mul  bl
  shr  ax,7       ; {0..63,63..0} * {0..255} / 128
Q out  dx,al      ; = {63..48..0,0..16..63}
  mul  al
  shr  ax,6
  out  dx,al      ; = {62..36..0,0..4..62}
  loop P

;Starting conditions

  mov  ah,18
S mov  [di+37304],di
  stosw
  loop S

;Main loop: store last pixel, load rule parameters

M imul dx,di,3    ; change rules every 4096/3 frames
  shld bx,si,8
  sub  dx,bx
  mov  bl,[si+1]
  add  dx,bx
  shr  dx,12      ; phase is based on u[] and y
  mov  al,dl

  push ax         ; ax = oldpixel....RULE
  mov  bx,G
  ss xlatb        ; ax = oldpixelGGGGDvDu
  aam  16
  ror  al,2
  or   ax,0010000000100000b
  xchg ax,cx      ; cx = ..1.GGGGDu1...Dv

;Compute new (u,v) for this cell (Gray-Scott reaction-diffusion)

  mov  ax,[es:si] ; .ax = v
  push ax

  mul  ax
  xchg ax,dx
  mul  word[si]   ; .bp = 3*u*v*v
  imul bp,dx,3

  mov  ah,10      ; F = random(0.039, 0.043)
  imul dx,[si],-1
  mul  dx
  sub  dx,bp      ; .dx = du = F*(1-u) - 3*u*v*v

  pop  ax
  push dx

  mul  cx
  sub  bp,dx      ; .bp = dv = 3*u*v*v - G*v
  pop  ax         ; .ax = du

  push ds
  push es

U pop  ds
  xchg ax,bp
  mov  bx,320     ; bx = {320,-320,2,-2} = {+y,-y,+x,-x}
  xadd [si],ax    ; .ax = v, v += dv
L mov  dx,[si+bx]
  shr  dx,2
  sub  ax,dx
  neg  bx
  js   L
  shr  bx,7
  jnz  L          ; .ax = -laplace(v) = v - v[{+y,-y,+x,-x}] / 4
  sar  ax,cl      ; .ax = -laplace(v) * Dv
  sub  [si],ax    ; v += laplace(v) * Dv
  shr  cl,6
  jc   U          ; do the same for u,du,Du

  pop  cx         ; cx = oldpixel....RULE

  lodsw
  shrd ax,cx,10   ; ax = __....RULEuuuuuu
  aad  32         ; ax = ........L#Uuuuuu
  mov  ah,al
  add  al,ch
  rcr  al,1       ; even pixels = averaged odd pixels
  mov  [fs:si],ax

  test si,si
  jnz  M

;Music

;  test di,7      ;#FASTER MUSIC
  test di,15
  jnz  V          ; di = mlkjihgfedcba000: is it time to play a note?

  mov  dx,331h    ; switch the MPU-401 to UART mode
  mov  al,3Fh
  out  dx,al
  dec  dx

  mov  al,0C0h
  out  dx,al
  xchg ax,cx      ; set instrument = AAA(rule): {5,4,...,0,9,8,...,0}
  aaa
  out  dx,al
  and  ax,3
  xchg ax,bp
  mov  al,90h     ; note on (no "note off" - use only percussive instruments)
  out  dx,al

  mov  ax,[bp+N]  ; load note vector (4 notes, each has 4 bits)

;  shld cx,di,16-1 ;#FASTER MUSIC
  shld cx,di,16-2 ; cx = Rmlk jihg fedc ba00

  ror  ax,cl      ; cycle notes
  aaa             ;="and al,0Fh" because nibbles of ax are always < 9

  imul cx,-12*16  ; cl = fedcab00 * octave (next note transposition = +3 notes)
  add  al,ch
  and  al,3Fh     ; mod 64 notes = 5 1/3 octaves: 3 transpositions [C, E, G#]
  add  al,24
  out  dx,al
  out  dx,al      ; loudness=note

V
;  mov  dl,0DAh    ; wait for vertical retrace end (70 fps cap)
;W in   al,dx
;  test al,8
;  jz   W

  dec  di         ; frame count

  in   al,60h
  dec  al         ; ESC test
  jnz  M
  ret

;Four sets of notes (with two shared notes)

N db (11-9)+( 6-6)*16                  ; F#7sus4 ;             C# E H F#
  db ( 4-3)+( 1+0)*16                  ; Em6     ;         G H C# E
  db (11-9)+( 7-6)*16                  ; Cmaj7   ;     C E G H
  db ( 4-3)+( 0+0)*16, (2+3)+ (7-6)*16 ; Cadd2   ; G D E C

;Diffusion parameters: G*256-32, -log(Dv), -log(Du)

G db 11*16 + 3*4 + 3  ; squares      (color 000: vi-pi)
  db  7*16 + 3*4 + 3  ; pulse maps   (color 010: cy-bl)
  db  5*16 + 1*4 + 2  ; shimmer      (color 100: br-gr)
  db 14*16 + 2*4 + 2  ; gliders      (color 110: br-gr)
  db  9*16 + 0*4 + 1  ; explosions   (color 001: pi-cy)
  db  9*16 + 3*4 + 3  ; islands      (color 011: bl-br)
  db  7*16 + 3*4 + 2  ; plasma       (color 101: gr-br)
  db 15*16 + 2*4 + 1  ; mitosis      (color 111: gr-vi)
  db  8*16 + 1*4 + 1  ; pool         (color 010: cy-bl)
  db  0*16 + 0*4 + 2  ; caramel      (color 100: br-gr)
  db 11*16 + 3*4 + 2  ; fingerprint  (color 110: br-gr)
  db  9*16 + 1*4 + 1  ; goo spirals  (color 000: vi-pi)
  db  2*16 + 0*4 + 3  ; noise fields (color 011: bl-br)
  db 12*16 + 2*4 + 1  ; worms        (color 101: gr-br)
  db  9*16 + 2*4 + 1  ; smooth pulse (color 111: gr-vi)
  db 15*16 + 1*4 + 0  ; polka dots   (color 001: pi-cy)
