comment +
 888888888888
        ,88'     8I          512 byte intro "i L0VE POUET"
      ,88"       8I          Code:    bitl/7dump (2024)
     ,88'        8I          mailto: aleks_gs@yahoo.com
  aaa888aa       8I
   ,8P     ,gggg,8I  gg      gg   ,ggg,,ggg,,ggg,   gg,gggg,
  ,88     dP"  "Y8I  I8      8I  ,8" "8P" "8P" "8,  I8P"  "Yb
  88'    i8'    ,8I  I8,    ,8I  I8   8I   8I   8I  I8'    ,8i
  88    ,d8,   ,d8b,,d8b,  ,d8b,,dP   8I   8I   Yb,,I8 _  ,d8'
  88    P"Y8888P"`Y88P'"Y88P"`Y88P'   8I   8I   `Y8PI8 YY88888P
                                                    I8
   GrEeTiNgS  & ReSpEct:                            I8
   baze, sensenstahl, TomCat/Abaddon, iONic, y0bi   I8
   wbcbz7,  p01,  pestis, Asato, rrrola,  Optimus   I8
   superogue, Kuemmel, HellMood, Manwe, LBi, JinX   I8
                                                    I8
   For compilation  use   Turbo  Assembler 2.02     I8
   tasm /m2 pouet.asm  tlink /t pouet.obj           I8

comment end! +

SCALE_FACTOR=115
DOTS_COUNT=15
TEXT_X=86
TEXT_Y=89 ; or 87 for DOSBOX Staging (facepalm!)

NUM_TEXT_STRING = 16
HEIGHT_TEXT = 320*(8*NUM_TEXT_STRING)
P_ = 2
F_ = 4

.model tiny
.data
X  DW 0
P  DW 31 ; For palette routine
F  DW 10

message DB "        *"          ,13,10
        DB "iL0VE P 0 U E T"    ,13,10
        DB " & P0UET  TEAM"     ,13,10
        DB " Y0U ARE C 00 L"    ,13,10
        DB "       ",176,42,176 ,13,10
        DB "    ANAL0GU E"      ,13,10
        DB "  G A R G A J"      ,13,10
        DB " P S E N 0 U G H"   ,13,10
        DB "  SENSENSTAH L"     ,13,10
        DB " HAV0C K E 0 P S"   ,13,10
        DB " & EVERY  0NE   "   ,13,10
        db "$"

.code
.486
org 0100h

start:

mov al, 13h
int 10h

add dh, al              ; cs + 1300h
mov fs, dx              ; segment for buffer
mov es, dx

pusha

;**********************************************************************
; SET PALETTE   r=cos(c/F)*P+P, g=cos(c/F+1)*P+P, b=cos(c/F+2)*P+P
;**********************************************************************
     lea bx, X                ; init BX as pointer to X (used throughout)
     fninit
     xor ax, ax
     mov dx, 3c8h
     out dx, al
     inc dx
@palette:
     fldz
     mov cl, 3                ;               0| |0
     @rgb:                    ;                €€€
        mov byte ptr [bx], ah ;               €˙€˙€
        fild word ptr [bx]    ;               ﬂﬂﬂﬂﬂ
        fidiv word ptr [bx+F_]; /F            ﬂ€€€ﬂ
        fadd st, st(1)        ; +0 (1,2)        €
        fcos                  ; COS         ‹‹‹‹€‹‹‹‹
        fimul word ptr [bx+P_]; *P          €  €€€  €
        fiadd word ptr [bx+P_]; +P       ﬂﬂﬂﬂ  €€€  €
        fistp word ptr [bx]   ;                €€€
        mov al, byte ptr [bx] ;              ‹€€€€€‹
        fld1                  ;              €ﬂ   ﬂ€
        faddp st(1), st       ;              €     €
        out dx, al            ;              €     €
     loop @rgb                ;            ‹€€     €€‹
     fstp st
     inc ah
jnz @palette

;**********************************************************************
; PALETTE AND TEXT INIT
;**********************************************************************
mov dx, offset message  ; print text to seg 0A000h
mov ah, 09
int 21h
int 21h   ;double text

push 0a000h
pop ds
xor di, di
xor si, si
mov cx, HEIGHT_TEXT
rep movsb               ; copy text to buffer
popa


add dh, al              ; also segs for buffers
mov es, dx
add dh, al
mov ds, dx

;**********************************************************************
; MAIN LOOP
;**********************************************************************
xor si,si
@mainloop:
inc si                  ; movement
push si
test si, 1
jnz @skip_render        ; animation FPS/2


;**********************************************************************
; RANDOM DOTS ON SCREEN CENTER
;**********************************************************************
mov cl, DOTS_COUNT
@random_dots:
       in ax, 40h
       xadd ds:[di], ax
       and ax, 63
       mov bx, dx
       mov dx, ax
       imul ax, ax, 320
       add bx, ax
       and ds:[bx+124+72*320], al
loop @random_dots

;**********************************************************************
; PRINT CHAR
;**********************************************************************
test si, 15
jnz @skip_char_draw

mov bx, si ; calc source offset for current string of text
shr bx, 8
shl bx, 3
and bx, 127
imul bx,bx, 320

shr si, 4
and si, 15
shl si, 3
mov di, si

add si, bx ; string of text
mov cl, 8
@loop_char_draw:
  mov dl, 8
  @readline:
      db 64h
      lodsb
      test al, al
      jz @skip

         xor ax, ax
         and ds:[di+(TEXT_X-2+320*(TEXT_Y+2))], ax
         and ds:[di+320+(TEXT_X-2+320*(TEXT_Y+2))], ax

         mov ax, 3f3fh
         mov ds:[di+(TEXT_X+320*TEXT_Y)], ax
         mov ds:[di+320+(TEXT_X+320*TEXT_Y)], ax
      @skip:
      inc di
      inc di
      dec dx
  jnz @readline
  add si, 320-8
  add di, 320-16+320
loop @loop_char_draw
@skip_char_draw:

;**********************************************************************
; SCALE AND BLUR
;**********************************************************************
xor di, di
mov bp, SCALE_FACTOR*100;
mov cl, 200
@y:
  mov dx, 160*128-SCALE_FACTOR*160
  mov si, 100*128
  sub si, bp
  shr si, 7
  imul si, si, 320
  mov ch, 80
      @x:
           mov bx, dx
           shr bx, 7
           mov eax, ds:[si+bx-1]
           add eax, ds:[si+bx+1]
           add eax, ds:[si+bx-320]
           add eax, ds:[si+bx+320]
           and eax, 0fcfcfcfch
           shr eax, 2
           stosd
           add dx, SCALE_FACTOR*4
      dec ch
      jnz @x
sub bp, SCALE_FACTOR
dec cl
jnz @y

push es                 ; swap addresses of buffers
push ds
pop es
pop ds

@skip_render:

     mov  dx, 3DAh      ; Wait for vertical retrace
@w1:
     in   al, dx
     test al, 8
     jnz  @w1
@w2:
     in   al, dx
     test al, 8
     jz   @w2


     push es            ; move buffer to screen
     push 0a000h
     pop es
     xor si, si
     xor di, di
     mov cx, 64000/4
     rep movsd
     pop es

in al, 60h              ; wait for ESC
dec al
pop si
jnz @mainloop

;**********************************************************************
; EXIT
;**********************************************************************
mov ax, 3               ; back to text
int 10h                 ; mode
ret
end start

