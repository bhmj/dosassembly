;
;  play in Dosbox with cycles = 23.000
;    
    
    les si,[bx]
    mov al,0x13
    int 0x10
start1:
    mov dx, 0x330
    rep outsb
start: 
    mov ah,0xcc
    add ax, 0x66
    mul di
    xchg ax,dx
    sub ax,bx
    and al,ah
    stosb
    loop start
    inc bh
    dec cl
    jmp start1