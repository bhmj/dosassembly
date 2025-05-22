; -----------------------------------------------------------------------------
; Blake 32 - a 32 byte intro by marquee design
; (c)2021 marquee design  
;
; Inspired by "Auguries of Innocence", a poem by William Blake
;
; To see a World in a Grain of Sand
; And a Heaven in a Wild Flower 
; Hold Infinity in the palm of your hand 
; And Eternity in an hour
;
; Greetings to: 
; sensenstahl, tomcat/abaddon, rrrola, digimind, p01, hellmood, frag, harekiet
; nuey, bruce, sjaak, sag, ile, deadline, fready and the rest at #demotivation
;
; check out our other stuff at https://marqueedesign.revival-studios.com
; -----------------------------------------------------------------------------
org 100h

mov al,13h			; 2
int 10h  			; 2
frameloop:
	les ax,[bx]		;  2 
	mov ah,0xcc		;  2 
	mul di			;  2 
	mov al,16		;  2
	fractalloop:
		ja snobby	; 2
		inc ax		; 1
		snobby:
		adc dl,[fs:0x46C] ; 5 (f&^k this shit!)
		sbb dh,dl       ; 2 
		ror dl,cl	; 2 
		adc dl,dh       ; 2 
	jno fractalloop		; 2
	stosb			; 1
jmp frameloop       		; 2
nop 				; bonus, because 32 bytes was too much free space for me.

; - enjoy! 
