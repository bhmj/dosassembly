mov al,0x13		;	 Bildschirmmodusbeschreibungskonstante
int 0x10		;	 Bildschirmmodussetzungsbefehl
push 0x9FF8		;	 Grafikspeicheradressenstapelung
pop es			;	 Segmentregisterstapelspeicherumwandlung
X mov si,cx		;	 Ersatzbildschimkoordinateninitialisierung
mov bl,16		;	 Maximaliterationswertfestlegung
L sub si,di		;	 Keftaleszusammenhangverschweigungssubtraktion
mov ax,409		;	 Rrrolatrickerweiterungszuweisung
imul si			;	 Bildschirmzeigerkoordinationumwandlung
ror dx,1		;	 Raumgeometrieschnittpunktsberechnung
dec bx			;	 Iterationszaehlererniedrigung
ja L			;	 TrefferOderMaximaliterationsabbruch
lea ax,[bx+16]	;	 Pixelfarbenpalettenmodifikationstrick
stosb			;	 Bildschirmvisualisierungskommando
loop X			;	 Schleifenzaehlererniedrigungssprunganweisung
loop X			;	 Schleifenzaehlererniedrigungssprunganweisung
