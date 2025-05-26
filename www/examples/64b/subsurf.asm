org 100h                       
start:	
	push	0xa000-70
	pop		ds
	mov		al,0x13
	int		0x10		
pixloop:	
iter:
	mov		ax,0xcccd
	mul		di
	mov		al,dh
	sub		al,100	
	imul	cl
	sub		ax,bx
	xchg	ax,dx
	imul	cl	
	mov		al,cl
	sbb		ax,bx
	and		al,ah
	xor     al,dh
	test	al,16+8
	loopz	iter
done:
	and		al,15
	add		al,16
	add		byte[di],al
	shr		byte[di],1
	inc 	di
	jnz 	next_frame
	dec		bx
	mov 	dx,0x330	;MIDI Control Port (331h)		
	mov 	al,0x9e
	out 	dx,al		;send: note on (channel 0)			
	mul		bl
	out 	dx,al		;send: key		
	mul		bl
	out 	dx,al		;send: velocity		
next_frame:
	mov		cl,-1
	jmp		pixloop