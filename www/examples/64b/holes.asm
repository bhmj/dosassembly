;;
;; play in dosbox with cycles = 240.000 
;;

[org 100h]

 les bp,[bx]
 mov fs,bp
 pushf
 pop ds
 
 mov al,0x13 + 0x80
 int 0x10

preFill:
 mov [di], ax
 inc ax  ; dec ax = 16.4 sec  /  inc ax = 14.6 sec
 cmpsw
 loop preFill

paintStart:
 add dx,[si-640]
 rcr dx,1
 dec dx
 add dx,[si+322]
 rcr dx,1
 mov [si],dx
 inc dh
 mov cl, dh
 imul bp, cx, 640
 salc
 xchg byte [fs:di], al
 mov [fs:di+bp], dh
 mov cl, 8
paintBlackLoop:
 add bp, 320
 mov byte [fs:di+bp], 0
 loop paintBlackLoop
 stosb
 lodsw
 dec dh
 jmp paintStart