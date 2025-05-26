;;
;; play with 30_000 cycles in dosbox
;;

org     100h

  mov  al, 13h
  int  10h
  lds  bp, [bx]

paintStart:
    push ds
    mov  ds, bp
    test si, 0x7F
    jnz skipMusic
    pusha
    mov dx, 0x378
    mov ax, [si]
    shr ax, 10
    out dx, al
    popa
  skipMusic:
    lodsw
    add bx, [si+638]
    rcr bx, 1
    add bx, [si-318]
    rcr bx, 1
    dec bx
    mov [si], bx
    pop ds
    add word [si], 0x1010
    shr byte [si], 1
    shr byte [si+1], 1
    push bx
    sub bx, ax
    inc byte [si+bx]
    pop bx
    jmp paintStart
