;;
;; play with 20_000 cycles in dosbox
;;

org     100h

    mov  al, 13h              
    int  10h
    les  bp, [bx]             
    mov  ds, bp               

paintStart:
    add dx, [si+bx]
    dec dx
    rcr dx, 1
    xor bx, -640
    mov [si], dx
    lodsw
    imul al
    add ax, di
    shr ax, 11
    add al, 32
    stosb

    jmp paintStart
