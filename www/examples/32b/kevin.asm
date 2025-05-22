mov dx,0x330      ; MIDI port
rep outsb         ; send all the code as MIDI
mov cx,-0xa41     ; special offset for structure
X:add al,0x13     ; screen mode and offset into grayscale
int 0x10          ; switch mode & set pixel
movsx ax,ch       ; cos/256  ; thx gopher!
sub dx,ax         ; sin -= cos/256
movsx ax,dh       ; sin/256
add cx,ax         ; cos += sin/256
or ah,0x0c        ; set pixel (sometimes)
db 0xc1,18,0x91   ; MIDI: change instrument, play note
es ja X           ; MIDI: note value, volume value / repeat
