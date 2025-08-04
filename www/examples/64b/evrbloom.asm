	push 0xa000		; getting screen address
	pop es			; in ES
	mov al,0x13		; switching graphics mode
	int 0x10		; to 320x200 in 256 coolors
	pop ds			; setting DS to 0, for timer access
S:	mov ax,0xcccd	; Rrolas trick, getting X and Y
	mul di			; in DL and DH
	mov cl,20		; set maximum number of iterations
L:	mov ax,dx		; get X and Y in AL and AH
	mul ah			; AH = X*X / 256
	shl ax,1		; AH = 2*X*X / 256	
	mov bl,dh		; BL = Y
	xchg bx,ax		; save 2*X*Y in BH, AL = Y
	mul al			; AH = Y*Y / 256
	xchg dx,ax		; DH = Y*Y / 256, AL = X
	mul al			; AH = X*X / 256
	push dx			; save DX
	add dx,ax		; testing overflow of X*X + Y*Y (radius > 256)
	mov al,cl		; saving iteration in AL for output
	pop dx			; restore DX
	jc X			; eXit loop if overflow
	sub dx,ax		; DH = (X*X - Y*Y) / 256
	sub dh,[0x46c]	; subtract timer value
	mov dl,bh		; DL = 2*X*Y / 256
	loop L			; continue until max iteration reched
	shld ax,di,14	; preparing background pattern from
	xor al,ah		; X and Y ( p = (x / 4) ^ (y / 4) )
	or al,248		; works if only using last three bits (7 colors)
X:	shl dx,1		; estimate fake lighting from fractal in CF
	adc al,28		; plant colors if fractal, black white if background
	stosb			; finally, plot the pixel to the screen
	jmp short S		; continue endlessly