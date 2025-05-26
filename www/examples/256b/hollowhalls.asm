; Hollow Halls - 256b intro by MX^Addict 2025 (mxadd@mxadd.org)
BITS 16
org 100h

;
; Defines
;
%define off_ax    -2
%define off_cx    -4
%define off_dx    -6
%define off_bx    -8
%define off_sp    -10
%define off_bp    -12
%define off_si    -14
%define off_di    -16

%define cst_19i    10
%define cst_42i    8
%define cst_8i     6
%define cst_4i     4
%define cst_200i   2
%define cst_2i     0
				   
%define PanOffs    24

;
; Entry point
;
start:

	; ax=0 bx=0 cx=255 si=100h (assumed)

	; Init gfx

	push 	0xa000
	pop  	es
	mov 	al, 0x13				; ax = 19
	int 	0x10

	; Push byte constants and store stack in si

	push	ax						; 1 byte (19)
	push	42						; 2 bytes
	push	8						; 2 bytes
	push	4						; 2 bytes
	push    (200-(PanOffs*2))		; 3 bytes
	push	2						; 2 bytes
	mov		si, sp

	; Palette

	salc							; ax = 0
.palette: 							; 42 shades of gray
	mov 	dx,0x3c9
	xchg	ax,cx
	out 	dx,al
	loop	.palette				; ax = 0xFF01, bx = 0, cx = 0, dx = 0x03C9 at end

	; Main loop
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.begin:

	inc     bp						; next frame
	mov		bx, bp
	and		bx, 1					; y position
	imul	di, bx, 320		        ; frame buffer offset
	add		di, 320 * (PanOffs-2)

	;
	; ax = ?
	; bx = YY
	; cx = 0
	; dx = ?
	; si = sp
	; di = 0
	; bp = frame counter

	; YLoop

.yloop:

	mov		cx, 320					; Counter (i)
	inc		bx
	add		di, cx
	pusha							; sp -= 16, [AX, CX, DX, BX, SP, BP, SI, DI]
	fild 	word [si+off_cx]		; Q (320)
	fldz	

	; XLoop

	; st0 - T			st1 - Q			st2 - ?			st3 - ?
	; st4 - ?			st5 - ?			st6 - ?			st7 - ?

	;
	; ax = ?
	; bx = YY
	; cx = 320
	; dx ?
	; si = sp
	; di = vga offset
	; bp = frame counter
	;

.xloop:
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	lea di, [si+cst_8i]				; 1 byte shorter [si+cst_8i] loads, +3b -5b

	; st0 - T			st1 - Q			st2 - ?			st3 - ?
	; st4 - ?			st5 - ?			st6 - ?			st7 - ?

	; float X = (((float(i)  / 200.0f) * Q) - T) + 8.0f
			
	fild 	word [si+off_cx]		; Counter (i) from stack
	fidiv	word [si+cst_200i]

	; st0 - XX/200		st1 - T			st2 - Q			st3 - ?
	; st4 - ?			st5 - ?			st6 - ?			st7 - ?

	fmul	st0, st2
	fsub	st0, st1
	fiadd   word [di] ; [si+cst_8i]

	; st0 - X			st1 - T			st2 - Q			st3 - ?
	; st4 - ?			st5 - ?			st6 - ?			st7 - ?

	; float Y = ((float(YY) / 200.0f) * Q) - (T / 2.0f)

	fild 	word [si+off_bx]		; YY from stack
	fidiv	word [si+cst_200i]

	; st0 - YY/200		st1 - X			st2 - T			st3 - Q
	; st4 - ?			st5 - ?			st6 - ?			st7 - ?

	fmul	st0, st3
	fld     st2
	fidiv   word [si+cst_2i]
	fsubp	st1, st0

	; st0 - Y			st1 - X			st2 - T			st3 - Q
	; st4 - ?			st5 - ?			st6 - ?			st7 - ?

	; float a = (my_fmod(X, 2.0f) + my_fmod(X, 2.0f)) - 2.0f
			
	fild	word [si+cst_2i]
	fld		st2
	fprem

	; st0 - X%2			st1 - 2.0		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	fadd	st0, st0
	fsubrp	st1, st0  

	; st0 - a			st1 - Y			st2 - X			st3 - T
	; st4 - Q			st5 - ?			st6 - ?			st7 - ?

	; float b = my_fmod(T+T+t), PI) - PI

	fldpi
	fld		st4
	fadd	st0, st0
	fild    word [si+off_bp]		; Add frame counter * 0.3...
	fidiv   word [di] ; [si+cst_8i]
	faddp
	fprem
			
	; st0 - (T+T+t)%PI  st1 - PI		st2 - a			st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	fsubrp	st1, st0

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; st0 - b			st1 - a			st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	fld1
	fcomip  st0, st3				; 1.0 ? Y --> Flags
	jb		.InnerA					; Y > 1.0

	; st0 - b			st1 - a			st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	fild	word [di] ; [si+cst_8i]
	fcomip  st0, st5				; 8.0 ? T --> Flags
	
	jb		.InnerA					; T > 8.0

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; st0 - b			st1 - a			st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	; if (Y < ((cosf(a*b)-2.0)) goto InnerA

	fld		st0
	fmul    st0, st2
	fcos
	fisub   word [si+cst_2i]

	; st0 - cos(a*b)-2  st1 - b			st2 - a			st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	fcomip  st0, st3				; Y ? st0 --> Flags
	ja		.InnerA					; Y < st0

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; st0 - b			st1 - a			st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	; if (((a * a) + (b * b)) < ((my_floor(Y * Y * 8.0f) + 2.0f) - (Y * Y)) / 19.0f) goto InnerA

	fmul	st0, st0				; b*b
	fxch    st1
	fmul	st0, st0				; a*a
	faddp   st1, st0

	; st0 - a*a+b*b		st1 - Y			st2 - X			st3 - T
	; st4 - Q			st5 - ?			st6 - ?			st7 - ?

	fld		st1
	fmul	st0, st0				; Y*Y
	fld     st0
	fimul   word [di] ; [si+cst_8i]

	; st0 - Y*Y*8		st1 - Y*Y		st2 - a*a+b*b	st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	frndint
	fiadd	word [si+cst_2i]

	; st0 - f(Y*Y*8)+2	st1 - Y*Y		st2 - a*a+b*b	st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	fsubrp	st1, st0    
	fidiv	word [si+cst_19i]
	fcomi   st0, st1				; ((f(Y*Y*8)+2)-Y*Y)/19 ? a*a+b*b --> Flags
	ja		.InnerA					; ((f(Y*Y*8)+2)-Y*Y)/19 > a*a+b*b
			
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	fldlg2							; 0.3...
	fmul	st0, st0				; 0.09...
	fld		st5
	fcomip  st0, st7				; T > Q
	ja		.TgQ1

	; st0 - TraceStep	st1 - Trash		st2 - Trash		st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	; Q+= h;

	faddp	st6, st0
			
	; T = Q;

	fld		st5						; Q
	fstp    st5						; T = Q, and pop

	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	jmp		.xclean
.TgQ1:

	; st0 - TraceStep	st1 - Trash		st2 - Trash		st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	; T+= h;

	faddp	st5, st0

	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	jmp		.xclean
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.InnerA:
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	fld		st4
	fcomip  st0, st6				; T > Q
	ja		.TgQ0

	; Q -= h;

	fldlg2							; 0.3...
	fmul	st0, st0				; 0.09...
	fsubp	st6, st0

	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	jmp		.xclean
.TgQ0:

	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	; Q = (X + Y - T) / 8.0f;

	fld		st3
	fadd    st0, st3				; X+Y
	fld     st5
	fsubp   st1, st0
	fidiv   word [di] ; [si+cst_8i]

	; st0 - nQ			st1 - Trash		st2 - Trash		st3 - Y
	; st4 - X			st5 - T			st6 - Q			st7 - ?

	fst		st6						; Q = (X + Y - T) / 8.0f;
	fst		st5						; T = Q

	fimul	word [si+cst_42i]
	fistp	word [si+off_ax]
	popa							; Pop as we need to update registers (ax will get updated with value from FPU)

	; Clamp all < 0

	test	ah, ah
	jz		.Gr1
	xor		ax, ax
.Gr1:

	; Clamp all > 41

	cmp		al, 41
	jle		.Gr0
	mov		al, 41
.Gr0:

	stosb							; Store final color

	; st0 - Trash		st1 - Trash		st2 - Y			st3 - X
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	loop	.xlcon					; continue X
	inc		bx						; next Y
	cmp     bx, word [si+cst_200i]	; check if end
	jl      .yloop					; next line
	jmp		.begin

.xlcon:

	pusha							; sp -= 16, [AX, CX, DX, BX, SP, BP, SI, DI]

.xclean:							; Cleanup code to pop 4 regs from stack, sadly we need this :/

	; st0 - Trash		st1 - Trash		st2 - Trash		st3 - Trash
	; st4 - T			st5 - Q			st6 - ?			st7 - ?

	fcompp							; pop 2 elements, to clear Trash
	fcompp							; pop 2 elements, to clear Trash

.xlend:
	jmp		.xloop

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; EOP
