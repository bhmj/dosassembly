org 100h
	les bp,[bx]
	mov al,13h

	int 10h
	or  al,0D6h
	mov bl,10h
m:
	adc al,1
	mov ah,dh
	shr ah,1
	add dl,[si]
	add dh,dl
	sub dl,ah
	dec bx
	jnz m
	stosb
	mov ah,0CDh
	mul di
	db 0EBh
	db -27
