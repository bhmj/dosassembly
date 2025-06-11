.model small
.386
.code

assume  cs:_TEXT, ds:_TEXT

LEFT_FIELD      equ     60
BOBSIZE         equ     16
COLOR           equ     32

BOBS            equ     17

        org     100h
Start:

; Generate bobs --------------------------------------------
        mov     di,offset Coord
        mov     eax,00100030h
        mov     cx,BOBS
        rep     stosd

        mov     al,13h
        int     10h

; Create buffer --------------------------------------------
        mov     ax,cs
        add     ax,(300h)/16+1
        mov     es,ax
        ; Clear buffer
        xor     di,di
        mov     ch,07Dh         ; CX = 32000
        xor     ax,ax
        rep     stosw           ; CX==0

; Generate palette ------------------------------------------
        mov     dx,3C8h
        out     dx,al
        inc     dx
@@SetPal:
        mov     ax,cx
        shr     ax,1
        out     dx,al   ; R
        out     dx,al   ; G
        shr     ax,1
        out     dx,al   ; B
        inc     cl
        jnz     @@SetPal

; Main loop:
@@Continue:
; MovePoints ---------------------------------------------
        mov     cl,BOBS*2
        lea     si,Step
        lea     di,Coord
        lea     bx,Bounds
@@MP1:
        movsx   ax,[si]                 ; load step
        add     [di],ax                 ; coord[i] += step[i]
        mov     dx,[bx]                 ; load left/top bound
        inc     bx
        inc     bx
        cmp     word ptr [di],dx        ; if coord is out of bound..
        jl      @@MP2                   ; ..negate step
        mov     dx,[bx]                 ; load right/bottom bound
        cmp     word ptr [di],dx        ; if coord is out of bound..
        jle     @@MP3
@@MP2:
        neg     byte ptr [si]
@@MP3:
        dec     bx
        dec     bx
        inc     si
        inc     di
        inc     di
        loop    @@MP1

; Draw ----------------------------------------------------------
        lea     bx,Coord
        mov     cl,BOBS
@@DFor:
        push    cx
        mov     di,[bx]         ; Xi
        add     di,LEFT_FIELD
        mov     ax,[bx+2]       ; Yi
        mov     dx,320
        mul     dx
        add     di,ax

        mov     cl,BOBSIZE
@@D1:   push    cx
        mov     cl,BOBSIZE
@@D2:   mov     al,byte ptr es:[di]
        add     al,COLOR
        jnc     @@D3
        mov     al,0FFh
@@D3:   stosb
        loop    @@D2
        add     di,320-BOBSIZE
        pop     cx
        loop    @@D1

        pop     cx
        add     bx,4            ; !!!
        loop    @@DFor

        push    ds
        push    es

        push    es
        pop     ds
; Fire --------------------------------------------------------
        mov     si,320
        mov     di,si
        mov     cx,64000-320*2
@@F1:
        xor     bx,bx
        mov     bl,byte ptr [si-1]
        mov     ax,bx
        mov     bl,byte ptr [si+1]
        add     ax,bx
        mov     bl,byte ptr [si-320]
        add     ax,bx
        mov     bl,byte ptr [si+320]
        add     ax,bx
        shr     ax,2
        jz      @@F2
        dec     ax
@@F2:   stosb
        inc     si
        loop    @@F1

; CopyScreen ------------------------------------------------
        push    0A000h
        pop     es
        xor     si,si
        xor     di,di
        mov     ch,7Dh          ; CX = 32000
        rep     movsw

        pop     es
        pop     ds

; Check for ESC pressed
        mov     ah,01
        int     16h
        jz      @@Continue

        mov     ax,0003h
        int     10h
        int     16h

        ret

; End of main()

; Data ==============================================

Bounds  label
        dw      15
        dw      320-LEFT_FIELD*2-BOBSIZE-15
Step    label
        db      +2
        db      +6      ; 1
        db      +2
        db      +4      ; 2
        db      +3
        db      +5      ; 3
        db      +4
        db      -4      ; 4
        db      +5
        db      -2      ; 5
        db      +6
        db      -1      ; 6
        db      -1
        db      +7      ; 7
        db      -2
        db      +4      ; 8
        db      -3
        db      +5      ; 9
        db      -4
        db      +3      ; 10
        db      -5
        db      +3      ; 11
        db      -5
        db      -4      ; 12
        db      +2
        db      -6      ; 13
        db      +3
        db      +2      ; 14
        db      +2
        db      -4      ; 15
        db      +3
        db      -3      ; 16
        db      +7
        db      -2      ; 17
Coord   label

end     Start
